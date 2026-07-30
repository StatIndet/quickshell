//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Modules.Wallpaper
import qs.Services

ShellRoot {
    id: root

    property int cycleCount: 0
    property string phase: "initial"
    property var savedConfig: ({})
    readonly property bool expectApplyFailure:
        Quickshell.env("CLAVIS_AWWW_MOCK_FAIL_APPLY") === "1"

    WallpaperBackground {}

    Component.onCompleted: {
        WallpaperService.primaryInstance = true;
        AwwwWallpaperService.primaryInstance = true;
    }

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function selectBackend(backend) {
        PersonalizationConfig.desktopWallpaperBackend = backend;
    }

    function finish(passed, message) {
        if (savedConfig.wallpaper !== undefined) {
            PersonalizationConfig.loadFromObject(savedConfig);
            PersonalizationConfig.loading = false;
        }
        console.log(passed
            ? "AWWW_SERVICE_SMOKE_PASS"
            : "AWWW_SERVICE_SMOKE_FAIL", message || "");
        Qt.callLater(Qt.quit);
    }

    Timer {
        id: finalStabilityTimer

        interval: 20000
        repeat: false
        onTriggered: {
            try {
                root.verify(
                    PersonalizationConfig.desktopWallpaperBackend
                        === "quickshell",
                    "backend reverted to awww after 20 seconds");
                root.verify(
                    AwwwWallpaperService.requestedBackend
                        === "quickshell",
                    "runtime request reverted after 20 seconds");
                root.verify(
                    AwwwWallpaperService.effectiveBackend
                        === "quickshell",
                    "effective backend reverted after 20 seconds");
                root.verify(
                    AwwwWallpaperService.quickshellContentVisible,
                    "resident Quickshell content disappeared");
                root.finish(true, "10 cycles and 20-second guard passed");
            } catch (error) {
                root.finish(false, error);
            }
        }
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
                    root.savedConfig = JSON.parse(JSON.stringify(
                        PersonalizationConfig.toJson()));
                    PersonalizationConfig.loading = true;
                    PersonalizationConfig
                        .awwwDesktopTransitionType = "grow";
                    PersonalizationConfig.awwwTransitionFps = 65;
                    PersonalizationConfig.awwwTransitionStep = 137;
                    PersonalizationConfig.transitionDurationMs = 1234;
                    PersonalizationConfig.transitionEasingMode =
                        "cubic";
                    PersonalizationConfig.transitionBezierCurve =
                        [0.22, 1, 0.36, 1, 1, 1];
                    root.selectBackend("awww");
                    root.phase = "waiting-awww";
                    return;
                }

                if (root.phase === "waiting-awww"
                        && root.expectApplyFailure
                        && AwwwWallpaperService.effectiveBackend
                            === "quickshell"
                        && AwwwWallpaperService.state === "error") {
                    root.verify(
                        PersonalizationConfig.desktopWallpaperBackend
                            === "awww",
                        "apply failure rewrote the user selection");
                    root.verify(
                        AwwwWallpaperService.quickshellContentVisible,
                        "apply failure hid the fallback wallpaper");
                    stop();
                    root.finish(true, "expected apply failure");
                    return;
                }

                if (root.phase === "waiting-awww"
                        && !root.expectApplyFailure
                        && AwwwWallpaperService.effectiveBackend
                            === "awww"
                        && AwwwWallpaperService.state === "ready") {
                    root.verify(
                        AwwwWallpaperService.daemonRunning,
                        "mock daemon is not running");
                    root.verify(
                        !AwwwWallpaperService.quickshellContentVisible,
                        "Quickshell content stayed visible after apply");

                    root.selectBackend("quickshell");
                    root.verify(
                        AwwwWallpaperService.quickshellContentVisible,
                        "Quickshell content was not restored immediately");
                    root.phase = "waiting-quickshell";
                    return;
                }

                if (root.phase === "waiting-quickshell"
                        && AwwwWallpaperService.effectiveBackend
                            === "quickshell"
                        && AwwwWallpaperService.state === "ready"
                        && !AwwwWallpaperService.daemonRunning) {
                    root.verify(
                        PersonalizationConfig.desktopWallpaperBackend
                            === "quickshell",
                        "service rewrote the Quickshell selection");
                    root.verify(
                        AwwwWallpaperService.quickshellContentVisible,
                        "resident Quickshell content is hidden");
                    root.verify(
                        AwwwWallpaperService.lastError === "",
                        "normal daemon shutdown was reported as an error");

                    root.cycleCount += 1;
                    if (root.cycleCount < 10) {
                        root.selectBackend("awww");
                        root.phase = "waiting-awww";
                    } else {
                        root.phase = "stability-guard";
                        stop();
                        finalStabilityTimer.start();
                    }
                }
            } catch (error) {
                stop();
                finalStabilityTimer.stop();
                root.finish(false, error);
            }
        }
    }

    Timer {
        interval: 40000
        repeat: false
        running: true
        onTriggered: {
            root.finish(false,
                "timeout phase=" + root.phase
                    + " cycles=" + root.cycleCount
                    + " requested="
                    + AwwwWallpaperService.requestedBackend
                    + " effective="
                    + AwwwWallpaperService.effectiveBackend
                    + " state=" + AwwwWallpaperService.state
                    + " daemon="
                    + AwwwWallpaperService.daemonRunning
                    + " error="
                    + AwwwWallpaperService.lastError);
        }
    }
}
