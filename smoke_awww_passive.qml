//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Services

ShellRoot {
    id: root

    property bool configured: false

    function finish(passed, message) {
        console.log(
            passed
                ? "AWWW_PASSIVE_SMOKE_PASS"
                : "AWWW_PASSIVE_SMOKE_FAIL",
            message || ""
        );
        Qt.callLater(Qt.quit);
    }

    Timer {
        interval: 25
        repeat: true
        running: true

        onTriggered: {
            if (!PersonalizationConfig.storeReady)
                return;

            if (!root.configured) {
                PersonalizationConfig.desktopWallpaperBackend = "awww";
                root.configured = true;
                return;
            }

            if (!AwwwWallpaperService.probeComplete)
                return;

            const passed =
                !AwwwWallpaperService.primaryInstance
                && AwwwWallpaperService.requestedBackend === "awww"
                && AwwwWallpaperService.effectiveBackend === "quickshell"
                && AwwwWallpaperService.state === "passive"
                && !AwwwWallpaperService.daemonRunning;
            stop();
            root.finish(
                passed,
                passed ? "" : (
                    "state=" + AwwwWallpaperService.state
                    + " daemon="
                        + AwwwWallpaperService.daemonRunning
                )
            );
        }
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: root.finish(false, "timeout")
    }
}
