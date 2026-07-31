//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.Wallpaper
import qs.Services

ShellRoot {
    id: root

    property string phase: "initial"
    property int phaseTicks: 0
    property int outputCount: 0
    readonly property string testSourceDir:
        Quickshell.env("CLAVIS_AWWW_TEST_SOURCE_DIR") || "/tmp"

    WallpaperBackground {}

    function fail(message) {
        console.error("AWWW_DEDUP_SMOKE_FAIL", message);
        Qt.callLater(Qt.quit);
    }

    function setTarget(path) {
        PersonalizationConfig.wallpaperPath = path;
    }

    function testTarget(name) {
        return root.testSourceDir
            + "/clavis-awww-dedup-" + name + ".png";
    }

    Component.onCompleted: {
        WallpaperService.primaryInstance = true;
        AwwwWallpaperService.primaryInstance = true;
    }

    Timer {
        interval: 25
        repeat: true
        running: true

        onTriggered: {
            try {
                if (!PersonalizationConfig.storeReady
                        || !AwwwWallpaperService.probeComplete)
                    return;

                if (root.phase === "initial") {
                    ++root.phaseTicks;
                    if (root.phaseTicks < 20
                            || PersonalizationConfig.loading)
                        return;
                    PersonalizationConfig.loading = true;
                    PersonalizationConfig.perModeWallpaper = false;
                    PersonalizationConfig.perMonitorWallpaper = false;
                    PersonalizationConfig.wallpaperFillMode = "Fill";
                    PersonalizationConfig.awwwDesktopTransitionType =
                        "any";
                    PersonalizationConfig.awwwTransitionFps = 60;
                    PersonalizationConfig.awwwTransitionStep = 90;
                    PersonalizationConfig.transitionDurationMs = 1200;
                    root.setTarget(root.testTarget("initial"));
                    PersonalizationConfig.desktopWallpaperBackend =
                        "awww";
                    root.outputCount = Quickshell.screens.length;
                    root.phase = "waiting-initial";
                    return;
                }

                if (root.phase === "waiting-initial"
                        && AwwwWallpaperService.state === "ready"
                        && AwwwWallpaperService.effectiveBackend
                            === "awww"
                        && AwwwWallpaperService.lastAppliedKey
                            .indexOf("dedup-initial") !== -1) {
                    PersonalizationConfig.awwwTransitionFps = 77;
                    PersonalizationConfig.awwwTransitionStep = 111;
                    PersonalizationConfig.transitionDurationMs = 1666;
                    PersonalizationConfig.transitionEasingMode =
                        "sine";
                    PersonalizationConfig.awwwTransitionAngle = 123;
                    PersonalizationConfig.awwwTransitionWave =
                        "30,10";
                    WallpaperService.refreshSettingsFromConfig();
                    WallpaperService.refreshFromConfig();
                    WallpaperService.refreshFromConfig();
                    root.phaseTicks = 0;
                    root.phase = "settings-stability";
                    return;
                }

                if (root.phase === "settings-stability") {
                    ++root.phaseTicks;
                    if (root.phaseTicks < 12)
                        return;
                    root.setTarget(root.testTarget("b"));
                    root.phaseTicks = 0;
                    root.phase = "rapid-targets";
                    return;
                }

                if (root.phase === "rapid-targets") {
                    ++root.phaseTicks;
                    if (root.phaseTicks < 2)
                        return;
                    root.setTarget(root.testTarget("c"));
                    root.setTarget(root.testTarget("d"));
                    root.phase = "waiting-final";
                    return;
                }

                if (root.phase === "waiting-final"
                        && AwwwWallpaperService.state === "ready"
                        && AwwwWallpaperService.lastAppliedKey
                            .indexOf("dedup-d") !== -1) {
                    stop();
                    console.log(
                        "AWWW_DEDUP_SMOKE_PASS outputs="
                            + root.outputCount);
                    Qt.callLater(Qt.quit);
                }
            } catch (error) {
                stop();
                root.fail(error);
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        onTriggered: root.fail(
            "timeout phase=" + root.phase
                + " state=" + AwwwWallpaperService.state
                + " requested="
                + AwwwWallpaperService.requestedBackend
                + " effective="
                + AwwwWallpaperService.effectiveBackend
                + " daemon="
                + AwwwWallpaperService.daemonRunning
                + " attempted="
                + AwwwWallpaperService.daemonStartAttempted
                + " active=" + AwwwWallpaperService.activeApplyKey
                + " pending=" + AwwwWallpaperService.pendingApplyKey
                + " last=" + AwwwWallpaperService.lastAppliedKey)
    }
}
