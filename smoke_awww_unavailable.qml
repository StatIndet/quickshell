//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Services

ShellRoot {
    id: root

    Component.onCompleted: {
        WallpaperService.primaryInstance = true;
        AwwwWallpaperService.primaryInstance = true;
    }

    property bool requested: false
    property var savedConfig: ({})

    function finish(passed, message) {
        if (savedConfig.wallpaper !== undefined) {
            PersonalizationConfig.loadFromObject(savedConfig);
            PersonalizationConfig.loading = false;
        }
        console.log(passed
            ? "AWWW_UNAVAILABLE_SMOKE_PASS"
            : "AWWW_UNAVAILABLE_SMOKE_FAIL", message || "");
        Qt.callLater(Qt.quit);
    }

    Timer {
        interval: 25
        repeat: true
        running: true

        onTriggered: {
            if (!PersonalizationConfig.storeReady)
                return;

            if (!root.requested) {
                root.savedConfig = JSON.parse(JSON.stringify(
                    PersonalizationConfig.toJson()));
                PersonalizationConfig.loading = true;
                PersonalizationConfig.desktopWallpaperBackend =
                    "awww";
                root.requested = true;
                return;
            }

            if (!AwwwWallpaperService.probeComplete)
                return;

            const passed = !AwwwWallpaperService.available
                && PersonalizationConfig.desktopWallpaperBackend
                    === "quickshell"
                && AwwwWallpaperService.effectiveBackend
                    === "quickshell"
                && AwwwWallpaperService.quickshellContentVisible
                && !AwwwWallpaperService.daemonRunning;
            stop();
            root.finish(passed,
                passed ? "" : AwwwWallpaperService.state);
        }
    }

    Timer {
        interval: 5000
        running: true
        onTriggered:
            root.finish(false, "timeout")
    }
}
