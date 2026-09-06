import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Scope {
    id: root

    readonly property bool busy: pendingCount > 0
    property int requestId: 0
    property int pendingCount: 0
    property var pendingScreens: ({})
    property var frames: ({})

    signal captureRequested(int requestId)
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
        frames = {};
        pendingScreens = {};
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
            return;

        delete pendingScreens[screenName];
        pendingCount -= 1;
        if (result && result.url) {
            const nextFrames = Object.assign({}, frames);
            nextFrames[screenName] = result;
            frames = nextFrames;
        } else {
            console.warn("Pre-lock capture failed for output " + screenName + "; using lock wallpaper");
        }
        if (pendingCount === 0)
            finishRequest(captureRequestId);
    }

    function finishRequest(captureRequestId) {
        if (captureRequestId !== requestId)
            return;

        deadline.stop();
        pendingCount = 0;
        pendingScreens = {};
        // Never complete inside captureRequested: the caller must first receive
        // the new request id, even when every output fails synchronously.
        Qt.callLater(() => root.completed(captureRequestId));
    }

    function cancel() {
        if (!busy)
            return;

        pendingCount = 0;
        pendingScreens = {};
        deadline.stop();
    }

    function snapshot(screen) {
        const key = screenKey(screen);
        return key !== "" ? (frames[key] || null) : null;
    }

    function clear() {
        if (!busy)
            frames = {};
    }

    Timer {
        id: deadline

        interval: 1800
        repeat: false
        onTriggered: {
            const expiredRequest = root.requestId;
            console.warn("Pre-lock capture deadline reached; locking with available output frames");
            root.finishRequest(expiredRequest);
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: worker
            required property var modelData
            readonly property string screenName: root.screenKey(modelData)
            property int activeRequestId: 0

            Connections {
                target: root
                function onCaptureRequested(captureRequestId) {
                    if (!root.isPending(worker.screenName))
                        return;
                    if (captureProcess.running) {
                        root.finishScreen(worker.screenName, captureRequestId, null);
                        return;
                    }
                    worker.activeRequestId = captureRequestId;
                    captureProcess.command = ["bash", Paths.captureScriptsDir + "/lock_snapshot.sh",
                                              worker.screenName];
                    captureProcess.running = true;
                }
            }

            Process {
                id: captureProcess
                onExited: (exitCode, exitStatus) => {
                    const encoded = captureOutput.text.trim();
                    const valid = exitCode === 0 && exitStatus === 0 && encoded.startsWith("iVBORw0KGgo");
                    root.finishScreen(worker.screenName, worker.activeRequestId, valid ? {
                                                                                             url: "data:image/png;base64,"
                                                                                                  + encoded
                                                                                         } : null);
                }
                stdout: StdioCollector {
                    id: captureOutput
                }
                stderr: StdioCollector {}
            }

            Component.onDestruction: {
                root.finishScreen(screenName, activeRequestId, null);
            }
        }
    }
}
