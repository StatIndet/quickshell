import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    readonly property bool busy: pendingCount > 0
    property int requestId: 0
    property int pendingCount: 0
    property var pendingScreens: ({
    })
    property var frames: ({
    })

    signal captureRequested(int requestId)
    signal captureCancelled(int requestId)
    signal completed(int requestId)

    function screenKey(screen) {
        return screen && screen.name ? String(screen.name) : "";
    }

    function isPending(screenName) {
        return pendingScreens[screenName] === true;
    }

    function capture() {
        if (busy)
            return 0;

        requestId += 1;
        frames = {
        };
        pendingScreens = {
        };
        pendingCount = 0;
        for (const screen of Quickshell.screens) {
            const key = screenKey(screen);
            if (key === "" || pendingScreens[key])
                continue;

            pendingScreens[key] = true;
            pendingCount += 1;
        }
        const currentRequest = requestId;
        if (pendingCount === 0) {
            Qt.callLater(() => {
                return root.completed(currentRequest);
            });
            return currentRequest;
        }
        deadline.restart();
        captureRequested(currentRequest);
        return currentRequest;
    }

    function finishScreen(screenName, captureRequestId, result) {
        if (!busy || captureRequestId !== requestId || !isPending(screenName))
            return ;

        delete pendingScreens[screenName];
        pendingCount -= 1;
        if (result && result.url)
            frames[screenName] = {
            "url": result.url,
            "result": result
        };
        else
            console.warn("Pre-lock capture failed for output " + screenName);
        if (pendingCount === 0)
            finishRequest(captureRequestId);

    }

    function finishRequest(captureRequestId) {
        if (captureRequestId !== requestId)
            return ;

        deadline.stop();
        pendingCount = 0;
        pendingScreens = {
        };
        captureCancelled(captureRequestId);
        completed(captureRequestId);
    }

    function cancel() {
        if (!busy)
            return ;

        const cancelledRequest = requestId;
        pendingCount = 0;
        pendingScreens = {
        };
        deadline.stop();
        captureCancelled(cancelledRequest);
    }

    function snapshot(screen) {
        const key = screenKey(screen);
        return key !== "" ? (frames[key] || null) : null;
    }

    function clear() {
        if (!busy)
            frames = {
        };

    }

    Timer {
        id: deadline

        interval: 300
        repeat: false
        onTriggered: {
            const expiredRequest = root.requestId;
            console.warn("Pre-lock capture deadline reached; locking with available output frames");
            root.finishRequest(expiredRequest);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: captureHost

            required property var modelData
            readonly property string screenName: root.screenKey(modelData)
            property int activeRequestId: 0
            property bool doneForRequest: true
            property bool grabInProgress: false

            function captureSize() {
                const source = captureView.sourceSize;
                return Qt.size(Math.max(1, source.width || 1), Math.max(1, source.height || 1));
            }

            function startCapture(captureRequestId) {
                if (!root.isPending(screenName))
                    return ;

                activeRequestId = captureRequestId;
                doneForRequest = false;
                grabInProgress = false;
                captureView.captureSource = modelData;
            }

            function grabSnapshot() {
                if (doneForRequest || grabInProgress || !captureView.hasContent)
                    return ;

                const callbackRequestId = activeRequestId;
                grabInProgress = true;
                const accepted = captureView.grabToImage((result) => {
                    if (callbackRequestId !== activeRequestId)
                        return ;

                    grabInProgress = false;
                    doneForRequest = true;
                    captureView.captureSource = null;
                    root.finishScreen(screenName, callbackRequestId, result);
                }, captureSize());
                if (!accepted) {
                    grabInProgress = false;
                    doneForRequest = true;
                    captureView.captureSource = null;
                    root.finishScreen(screenName, callbackRequestId, null);
                }
            }

            screen: modelData
            visible: true
            color: "transparent"
            implicitWidth: 1
            implicitHeight: 1
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "clavis-lock-prelock-capture"
            Component.onDestruction: {
                if (!doneForRequest)
                    root.finishScreen(screenName, activeRequestId, null);

            }

            Connections {
                function onCaptureRequested(captureRequestId) {
                    captureHost.startCapture(captureRequestId);
                }

                function onCaptureCancelled(captureRequestId) {
                    if (captureHost.activeRequestId !== captureRequestId)
                        return ;

                    captureHost.activeRequestId = 0;
                    captureHost.doneForRequest = true;
                    captureHost.grabInProgress = false;
                    captureView.captureSource = null;
                }

                target: root
            }

            ScreencopyView {
                id: captureView

                readonly property bool sourceReady: sourceSize.width > 0 && sourceSize.height > 0

                width: Math.max(1, sourceReady ? sourceSize.width : 1)
                height: Math.max(1, sourceReady ? sourceSize.height : 1)
                captureSource: null
                live: false
                paintCursor: false
                visible: !captureHost.doneForRequest
                onHasContentChanged: {
                    if (hasContent)
                        captureHost.grabSnapshot();

                }
                onStopped: {
                    if (!captureHost.doneForRequest && !captureHost.grabInProgress) {
                        captureHost.doneForRequest = true;
                        captureView.captureSource = null;
                        root.finishScreen(captureHost.screenName, captureHost.activeRequestId, null);
                    }
                }
            }

            mask: Region {
            }

        }

    }

}
