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
    signal releaseFrames

    function screenKey(screen) {
        return screen && screen.name ? String(screen.name) : "";
    }

    function isPending(screenName) {
        return pendingScreens[screenName] === true;
    }

    function capture() {
        if (busy)
            return 0;

        releaseFrames();
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
        releaseFrames();
    }

    function snapshot(screen) {
        const key = screenKey(screen);
        return key !== "" ? (frames[key] || null) : null;
    }

    function clear() {
        if (!busy) {
            frames = {};
            releaseFrames();
        }
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
            property int queuedRequestId: 0
            property bool published: false
            property string snapshotUrl: ""
            property double startedAt: 0

            function startRequest(captureRequestId) {
                if (captureRequestId !== root.requestId || !root.isPending(screenName))
                    return;
                activeRequestId = captureRequestId;
                published = false;
                startedAt = Date.now();
                captureProcess.command = ["bash", Paths.captureScriptsDir + "/lock_snapshot.sh", screenName];
                captureProcess.running = true;
            }

            function release(keepQueued) {
                if (!keepQueued)
                    queuedRequestId = 0;
                snapshotUrl = "";
                if (captureProcess.running)
                    captureProcess.write("release\n");
            }

            function publish() {
                if (published || snapshotUrl === "" || preload.status === Image.Loading)
                    return;
                if (activeRequestId !== root.requestId || !root.isPending(screenName)) {
                    release(true);
                    return;
                }
                published = true;
                if (preload.status === Image.Ready) {
                    console.debug("Lock snapshot ready for " + screenName + " in " + (Date.now() - startedAt)
                                  + " ms");
                    root.finishScreen(screenName, activeRequestId, {
                                          url: snapshotUrl
                                      });
                } else {
                    release();
                    root.finishScreen(screenName, activeRequestId, null);
                }
            }

            Connections {
                target: root
                function onReleaseFrames() {
                    worker.release();
                }
                function onCaptureRequested(captureRequestId) {
                    if (!root.isPending(worker.screenName))
                        return;
                    if (captureProcess.running) {
                        worker.queuedRequestId = captureRequestId;
                        return;
                    }
                    worker.startRequest(captureRequestId);
                }
            }

            // Hold the decoded pixmap before requesting WlSessionLock. The lock
            // Images use the same local URL and cache settings, not data: URLs.
            Image {
                id: preload
                source: worker.snapshotUrl
                asynchronous: false
                cache: true
                visible: false
                onStatusChanged: Qt.callLater(worker.publish)
            }

            Process {
                id: captureProcess
                stdinEnabled: true
                onExited: {
                    if (!worker.published)
                        root.finishScreen(worker.screenName, worker.activeRequestId, null);
                    const next = worker.queuedRequestId;
                    worker.queuedRequestId = 0;
                    if (next === root.requestId && root.isPending(worker.screenName))
                        Qt.callLater(() => worker.startRequest(next));
                }
                stdout: SplitParser {
                    onRead: data => {
                        if (worker.published || worker.activeRequestId !== root.requestId || !root.isPending(
                                    worker.screenName)) {
                            worker.release(true);
                            return;
                        }
                        if (!data.startsWith("/") || !data.endsWith("/frame.bmp")) {
                            worker.release();
                            root.finishScreen(worker.screenName, worker.activeRequestId, null);
                            return;
                        }
                        worker.snapshotUrl = Paths.fileUrl(data);
                        Qt.callLater(worker.publish);
                    }
                }
                stderr: StdioCollector {}
            }

            Component.onDestruction: {
                root.finishScreen(screenName, activeRequestId, null);
            }
        }
    }
}
