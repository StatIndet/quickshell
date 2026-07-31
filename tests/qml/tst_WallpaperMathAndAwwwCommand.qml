import QtQuick 2.15
import QtTest 1.3
import "../../Common/functions/AwwwCommand.js" as AwwwCommand
import "../../Common/functions/WallpaperMath.js" as WallpaperMath

TestCase {
    name: "WallpaperMathAndAwwwCommand"

    function transitionCommand(type, overrides) {
        const settings = {
            type: type,
            fps: 60,
            step: 90,
            durationMs: 1200,
            easingMode: "customBezier",
            bezierCurve: [0.22, 1, 0.36, 1, 1, 1],
            angle: 45,
            position: "center",
            wave: "20,20"
        };
        const extra = overrides || {};
        for (let key in extra)
            settings[key] = extra[key];
        return AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "eDP-1",
            "/tmp/a.png", "Fill", settings);
    }

    function verifyContains(command, argument) {
        verify(command.indexOf(argument) !== -1,
            "missing argument " + argument + " in "
                + JSON.stringify(command));
    }

    function verifyOmits(command, argument) {
        verify(command.indexOf(argument) === -1,
            "unexpected argument " + argument + " in "
                + JSON.stringify(command));
    }

    function test_fixedParallaxCanvasGeometry() {
        const geometry = WallpaperMath.parallaxCanvasGeometry(
            1920, 1080, 1.10, true);
        compare(Math.round(geometry.scaledWidth), 2112);
        compare(Math.round(geometry.scaledHeight), 1188);
        compare(Math.round(geometry.overflowX), 192);
        compare(Math.round(geometry.overflowY), 108);

        const inactive = WallpaperMath.parallaxCanvasGeometry(
            1920, 1080, 1.10, false);
        compare(inactive.scaledWidth, 1920);
        compare(inactive.scaledHeight, 1080);
        compare(inactive.overflowX, 0);
        compare(inactive.overflowY, 0);
    }

    function test_panoramaGeometryUsesNaturalHorizontalOverflow() {
        const geometry = WallpaperMath.panoramaGeometry(
            1920, 1080, 2048, 576, true);
        verify(geometry.active);
        compare(geometry.scale, 1.875);
        compare(geometry.canvasWidth, 3840);
        compare(geometry.canvasHeight, 1080);
        compare(geometry.overflowX, 1920);
        compare(geometry.overflowY, 0);
        compare(WallpaperMath.wallpaperPosition(
            geometry.overflowX, 0), 0);
        compare(WallpaperMath.wallpaperPosition(
            geometry.overflowX, 0.5), -960);
        compare(WallpaperMath.wallpaperPosition(
            geometry.overflowX, 1), -1920);
    }

    function test_panoramaFallsBackForNonWideImages() {
        const sameAspect = WallpaperMath.panoramaGeometry(
            1920, 1080, 1920, 1080, true);
        verify(!sameAspect.active);
        compare(sameAspect.canvasWidth, 1920);
        compare(sameAspect.canvasHeight, 1080);
        compare(sameAspect.overflowX, 0);
        compare(sameAspect.overflowY, 0);

        const portrait = WallpaperMath.panoramaGeometry(
            1920, 1080, 1080, 1920, true);
        verify(!portrait.active);
        compare(portrait.canvasWidth, 1920);
        compare(portrait.canvasHeight, 1080);
        compare(portrait.overflowX, 0);
        compare(portrait.overflowY, 0);
    }

    function test_panoramaCurrentAndNextUseIndependentGeometry() {
        const current = WallpaperMath.panoramaGeometry(
            1920, 1080, 2048, 576, true);
        const next = WallpaperMath.panoramaGeometry(
            1920, 1080, 3072, 576, true);
        compare(current.canvasWidth, 3840);
        compare(next.canvasWidth, 5760);
        compare(current.canvasHeight, 1080);
        compare(next.canvasHeight, 1080);
        compare(WallpaperMath.wallpaperPosition(
            current.overflowX, 0.4), -768);
        compare(WallpaperMath.wallpaperPosition(
            next.overflowX, 0.4), -1536);
    }

    function test_panoramaGeometryIsPerScreen() {
        const laptop = WallpaperMath.panoramaGeometry(
            1920, 1080, 2048, 576, true);
        const ultrawide = WallpaperMath.panoramaGeometry(
            3440, 1440, 2048, 576, true);
        compare(laptop.canvasWidth, 3840);
        compare(laptop.overflowX, 1920);
        compare(ultrawide.canvasWidth, 5120);
        compare(ultrawide.overflowX, 1680);
    }

    function test_parallaxCanvasIgnoresWallpaperAspectAndStatus() {
        const wallpaperStates = [
            { source: "wide.jpg", width: 3440, height: 1440,
                status: Image.Loading },
            { source: "wide.jpg", width: 3440, height: 1440,
                status: Image.Ready },
            { source: "portrait.jpg", width: 1080, height: 1920,
                status: Image.Loading },
            { source: "portrait.jpg", width: 1080, height: 1920,
                status: Image.Ready }
        ];
        const horizontalProgress = 0.4;
        const verticalProgress = 0.5;
        let expectedGeometry = "";
        let expectedX = 0;
        let expectedY = 0;

        for (let index = 0; index < wallpaperStates.length;
                index += 1) {
            const state = wallpaperStates[index];
            const supported = WallpaperMath.supportsParallaxCanvas(
                true, state.source, false);
            const geometry = WallpaperMath.parallaxCanvasGeometry(
                1920, 1080, 1.10, supported);
            const serialized = JSON.stringify(geometry);
            const x = WallpaperMath.wallpaperPosition(
                geometry.overflowX, horizontalProgress);
            const y = WallpaperMath.wallpaperPosition(
                geometry.overflowY, verticalProgress);
            if (index === 0) {
                expectedGeometry = serialized;
                expectedX = x;
                expectedY = y;
            } else {
                compare(serialized, expectedGeometry);
                compare(x, expectedX);
                compare(y, expectedY);
            }
        }

        verify(!WallpaperMath.supportsParallaxCanvas(
            false, "wide.jpg", false));
        verify(!WallpaperMath.supportsParallaxCanvas(
            true, "#112233", true));
        verify(!WallpaperMath.supportsParallaxCanvas(
            true, "", false));
    }

    function test_currentAndNextWallpaperShareParallaxCanvas() {
        const geometry = WallpaperMath.parallaxCanvasGeometry(
            1920, 1080, 1.10, true);
        const currentSource = {
            source: "current-16x9.jpg",
            canvasWidth: geometry.scaledWidth,
            canvasHeight: geometry.scaledHeight
        };
        const nextSource = {
            source: "next-ultrawide.jpg",
            canvasWidth: geometry.scaledWidth,
            canvasHeight: geometry.scaledHeight
        };
        compare(currentSource.canvasWidth, nextSource.canvasWidth);
        compare(currentSource.canvasHeight, nextSource.canvasHeight);
    }

    function test_fixedCanvasStillMovesWithParallaxDrivers() {
        const geometry = WallpaperMath.parallaxCanvasGeometry(
            1920, 1080, 1.10, true);
        const columns = [1, 2, 3, 4, 5, 6];
        const firstX = WallpaperMath.wallpaperPosition(
            geometry.overflowX,
            WallpaperMath.focusedColumnProgress(columns, 1, 6));
        const lastX = WallpaperMath.wallpaperPosition(
            geometry.overflowX,
            WallpaperMath.focusedColumnProgress(columns, 6, 6));
        compare(Math.round(firstX), 0);
        compare(Math.round(lastX), -192);

        const topY = WallpaperMath.wallpaperPosition(
            geometry.overflowY,
            WallpaperMath.workspaceProgress([
                { isActive: true },
                { isActive: false }
            ]));
        const bottomY = WallpaperMath.wallpaperPosition(
            geometry.overflowY,
            WallpaperMath.workspaceProgress([
                { isActive: false },
                { isActive: true }
            ]));
        compare(Math.round(topY), 0);
        compare(Math.round(bottomY), -108);
    }

    function test_tiledColumnProgress() {
        compare(WallpaperMath.tiledColumnProgress(0, 6), 0.5);
        compare(WallpaperMath.tiledColumnProgress(1, 6), 0);
        compare(WallpaperMath.tiledColumnProgress(2, 6), 0.2);
        compare(WallpaperMath.tiledColumnProgress(6, 6), 1);
        compare(WallpaperMath.tiledColumnProgress(12, 6), 1);
    }

    function test_focusedHorizontalColumnProgress() {
        const columns = [1, 2, 3, 4, 5, 6];
        compare(WallpaperMath.focusedColumnProgress(
            columns, 1, 6), 0);
        compare(WallpaperMath.focusedColumnProgress(
            columns, 3, 6), 0.4);
        compare(WallpaperMath.focusedColumnProgress(
            columns, 6, 6), 1);
        compare(WallpaperMath.focusedColumnProgress(
            [], 0, 6), 0.5);
        compare(WallpaperMath.focusedColumnProgress(
            [3], 3, 6), 0);
    }

    function test_horizontalColumnsIgnoreRowsAndFloatingWindows() {
        const windows = [
            { workspaceId: 1, isFloating: false,
                layoutColumn: 1, layoutRow: 1 },
            { workspaceId: 1, isFloating: false,
                layoutColumn: 3, layoutRow: 1 },
            { workspaceId: 1, isFloating: false,
                layoutColumn: 3, layoutRow: 2 },
            { workspaceId: 1, isFloating: false,
                layoutColumn: 6, layoutRow: 1 },
            { workspaceId: 1, isFloating: true,
                layoutColumn: 4, layoutRow: 1 }
        ];
        const columns = WallpaperMath.horizontalColumns(windows);
        compare(JSON.stringify(columns), JSON.stringify([1, 3, 6]));

        const progressA = WallpaperMath.focusedColumnProgress(
            columns, windows[1].layoutColumn, 6);
        const progressB = WallpaperMath.focusedColumnProgress(
            columns, windows[2].layoutColumn, 6);
        compare(progressA, progressB);

        const vertical = WallpaperMath.workspaceProgress([
            { isActive: true },
            { isActive: false }
        ]);
        compare(vertical, 0);
        compare(
            WallpaperMath.wallpaperPosition(100, vertical),
            WallpaperMath.wallpaperPosition(100, vertical));
    }

    function test_floatingFocusKeepsTiledMemory() {
        let memory = {};
        memory = WallpaperMath.rememberFocusedHorizontalColumn(
            memory, {
                workspaceId: 7,
                isFloating: false,
                layoutColumn: 4,
                layoutRow: 1
            });
        const afterTiled = memory;
        memory = WallpaperMath.rememberFocusedHorizontalColumn(
            memory, {
                workspaceId: 7,
                isFloating: true,
                layoutColumn: 9,
                layoutRow: 1
            });
        compare(memory, afterTiled);
        compare(memory["7"], 4);
        compare(WallpaperMath.focusedColumnProgress(
            [1, 2, 3, 4, 5, 6], memory["7"], 6), 0.6);
    }

    function test_closedColumnUsesNearestRemainingSlot() {
        compare(WallpaperMath.nearestHorizontalColumn(
            [1, 2, 3, 5], 4), 3);
        compare(WallpaperMath.focusedColumnProgress(
            [1, 2, 3, 5], 4, 6), 0.4);
        compare(WallpaperMath.nearestHorizontalColumn([], 4), 0);
    }

    function test_workspaceHorizontalMemoryIsIndependent() {
        let memory = {};
        memory = WallpaperMath.rememberFocusedHorizontalColumn(
            memory, {
                workspaceId: 11,
                isFloating: false,
                layoutColumn: 2
            });
        memory = WallpaperMath.rememberFocusedHorizontalColumn(
            memory, {
                workspaceId: 22,
                isFloating: false,
                layoutColumn: 5
            });
        compare(memory["11"], 2);
        compare(memory["22"], 5);

        const unchanged = WallpaperMath
            .rememberFocusedHorizontalColumn(memory, {
                workspaceId: 22,
                isFloating: true,
                layoutColumn: 8
            });
        compare(unchanged["11"], 2);
        compare(unchanged["22"], 5);
    }

    function test_workspaceProgressIsPerOutputList() {
        compare(WallpaperMath.workspaceProgress([
            { isActive: true }
        ]), 0.5);
        compare(WallpaperMath.workspaceProgress([
            { isActive: true },
            { isActive: false },
            { isActive: false }
        ]), 0);
        compare(WallpaperMath.workspaceProgress([
            { isActive: false },
            { isActive: false },
            { isActive: true }
        ]), 1);
    }

    function test_sidebarDirectionsAndCancellation() {
        const overflow = 200;
        const base = WallpaperMath.horizontalProgress(
            0.5, false, false, 0.1);
        const left = WallpaperMath.horizontalProgress(
            0.5, true, false, 0.1);
        const right = WallpaperMath.horizontalProgress(
            0.5, false, true, 0.1);
        const both = WallpaperMath.horizontalProgress(
            0.5, true, true, 0.1);

        verify(WallpaperMath.wallpaperPosition(overflow, left)
            > WallpaperMath.wallpaperPosition(overflow, base));
        verify(WallpaperMath.wallpaperPosition(overflow, right)
            < WallpaperMath.wallpaperPosition(overflow, base));
        compare(both, base);
    }

    function test_awwwNamespaceLifecycleCommands() {
        compare(JSON.stringify(AwwwCommand.daemon(
            "mock-daemon", "clavis-desktop")), JSON.stringify([
            "mock-daemon", "--layer", "bottom",
            "--namespace", "clavis-desktop", "--no-cache"
        ]));
        compare(JSON.stringify(AwwwCommand.query(
            "mock-awww", "clavis-desktop")), JSON.stringify([
            "mock-awww", "query", "-n", "clavis-desktop"
        ]));
        compare(JSON.stringify(AwwwCommand.stop(
            "mock-awww", "clavis-desktop")), JSON.stringify([
            "mock-awww", "kill", "-n", "clavis-desktop"
        ]));
    }

    function test_awwwImageArgumentsAreArraySafe() {
        const path = "/tmp/wallpaper with spaces;$(touch nope).png";
        const command = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1", path, "Fill", {
                type: "wipe",
                fps: 60,
                step: 90,
                durationMs: 1250,
                easingMode: "customBezier",
                bezierCurve: [0.1, 0.2, 0.3, 0.4, 1, 1],
                angle: 90,
                position: "center",
                wave: "20,20"
            });

        compare(command[0], "mock-awww");
        compare(command[1], "img");
        compare(command[command.length - 1], path);
        compare(command[command.indexOf("-n") + 1],
            "clavis-desktop");
        compare(command[command.indexOf("-o") + 1], "DP-1");
        compare(command[command.indexOf("--transition-angle") + 1],
            "90");
        compare(command[command.indexOf("--transition-duration") + 1],
            "1.250");
        compare(command[command.indexOf("--transition-step") + 1],
            "90");
        compare(command[command.indexOf("--transition-bezier") + 1],
            "0.1,0.2,0.3,0.4");
        verify(command.indexOf("portal") === -1);
    }

    function test_awwwAnyResolvesOneBatchPosition() {
        const source = {
            type: "any",
            position: "center",
            durationMs: 1200
        };
        const resolved = AwwwCommand.resolvedTransitionOptions(
            source, 0.125, 0.875);
        compare(resolved.type, "grow");
        compare(resolved.position, "0.125000,0.875000");
        compare(source.type, "any");
        compare(source.position, "center");

        const first = transitionCommand("any", resolved);
        const second = transitionCommand("any", resolved);
        compare(first[first.indexOf("--transition-type") + 1], "grow");
        compare(second[second.indexOf("--transition-type") + 1], "grow");
        compare(
            first[first.indexOf("--transition-pos") + 1],
            second[second.indexOf("--transition-pos") + 1]);
    }

    function test_awwwApplyRequestKeyOnlyTracksFinalState() {
        const first = AwwwCommand.applyRequestKey([{
            output: "eDP-1",
            source: "/tmp/a.png",
            fillMode: "Fill",
            revision: 1,
            settingsRevision: 3,
            transition: {
                fps: 60,
                position: "0.1,0.2"
            }
        }]);
        const sameFinalState = AwwwCommand.applyRequestKey([{
            output: "eDP-1",
            source: "/tmp/a.png",
            fillMode: "Fill",
            revision: 99,
            settingsRevision: 100,
            transition: {
                fps: 240,
                position: "0.8,0.9"
            }
        }]);
        compare(first, sameFinalState);
        compare(first, JSON.stringify([{
            output: "eDP-1",
            source: "/tmp/a.png",
            fillMode: "Fill"
        }]));

        const changedWallpaper = AwwwCommand.applyRequestKey([{
            output: "eDP-1",
            source: "/tmp/b.png",
            fillMode: "Fill"
        }]);
        verify(changedWallpaper !== first);
    }

    function test_awwwPureColorUsesClear() {
        const command = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "HDMI-A-1",
            "#aabbccdd", "Fill", {});
        compare(JSON.stringify(command), JSON.stringify([
            "mock-awww", "clear", "-n", "clavis-desktop",
            "-o", "HDMI-A-1", "aabbccdd"
        ]));
    }

    function test_awwwBezierUsesFourControls() {
        const command = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "fade",
                fps: 60,
                durationMs: 1000,
                easingMode: "customBezier",
                bezierCurve: [0.43, 1.19, 1, 0.4, 1, 1]
            });
        compare(
            command[command.indexOf("--transition-bezier") + 1],
            "0.43,1.19,1,0.4");

        const clamped = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "fade",
                easingMode: "customBezier",
                bezierCurve: [-1, 99, 2, -99, 1, 1]
            });
        compare(
            clamped[clamped.indexOf("--transition-bezier") + 1],
            "0,4,1,-4");
    }

    function test_awwwPresetBezierMappings() {
        const expected = {
            linear: "0,0,1,1",
            quad: "0.455,0.03,0.515,0.955",
            cubic: "0.645,0.045,0.355,1",
            quart: "0.77,0,0.175,1",
            quint: "0.86,0,0.07,1",
            sine: "0.445,0.05,0.55,0.95",
            expo: "1,0,0,1",
            circ: "0.785,0.135,0.15,0.86"
        };
        for (let mode in expected) {
            const command = transitionCommand("grow", {
                easingMode: mode
            });
            compare(command[
                command.indexOf("--transition-bezier") + 1],
                expected[mode]);
        }
    }

    function test_awwwCustomAndFallbackBezierMappings() {
        const customCurve = [0.22, 1, 0.36, 1, 1, 1];
        const customBefore = JSON.stringify(customCurve);
        const custom = transitionCommand("fade", {
            easingMode: "customBezier",
            bezierCurve: customCurve
        });
        compare(custom[
            custom.indexOf("--transition-bezier") + 1],
            "0.22,1,0.36,1");

        const linear = transitionCommand("fade", {
            easingMode: "linear",
            bezierCurve: customCurve
        });
        compare(linear[
            linear.indexOf("--transition-bezier") + 1],
            "0,0,1,1");
        compare(JSON.stringify(customCurve), customBefore);

        const restored = transitionCommand("fade", {
            easingMode: "customBezier",
            bezierCurve: customCurve
        });
        compare(restored[
            restored.indexOf("--transition-bezier") + 1],
            "0.22,1,0.36,1");

        const unknown = transitionCommand("fade", {
            easingMode: "unknown",
            bezierCurve: customCurve
        });
        compare(unknown[
            unknown.indexOf("--transition-bezier") + 1],
            "0.43,1.19,1,0.4");

        const invalid = transitionCommand("fade", {
            easingMode: "customBezier",
            bezierCurve: [0.2, NaN, 0.8, 1]
        });
        compare(invalid[
            invalid.indexOf("--transition-bezier") + 1],
            "0.43,1.19,1,0.4");
    }

    function test_awwwNextCommandUsesCurrentEasingMode() {
        const quad = transitionCommand("left", {
            easingMode: "quad"
        });
        const cubic = transitionCommand("left", {
            easingMode: "cubic"
        });
        compare(quad[
            quad.indexOf("--transition-bezier") + 1],
            "0.455,0.03,0.515,0.955");
        compare(cubic[
            cubic.indexOf("--transition-bezier") + 1],
            "0.645,0.045,0.355,1");
    }

    function test_awwwTransitionCapabilities() {
        verify(!AwwwCommand.supportsDuration("none"));
        verify(!AwwwCommand.supportsDuration("simple"));
        verify(AwwwCommand.supportsDuration("fade"));
        verify(AwwwCommand.supportsDuration("grow"));
        verify(!AwwwCommand.supportsBezier("none"));
        verify(!AwwwCommand.supportsBezier("simple"));
        verify(AwwwCommand.supportsBezier("wipe"));
        verify(AwwwCommand.supportsBezier("random"));
        verify(!AwwwCommand.supportsStep("none"));
        verify(AwwwCommand.supportsStep("simple"));
        verify(AwwwCommand.supportsStep("outer"));
    }

    function test_awwwNoneArguments() {
        const command = transitionCommand("none");
        verifyOmits(command, "--transition-fps");
        verifyOmits(command, "--transition-step");
        verifyOmits(command, "--transition-duration");
        verifyOmits(command, "--transition-bezier");
    }

    function test_awwwSimpleArguments() {
        const command = transitionCommand("simple");
        verifyContains(command, "--transition-fps");
        verifyContains(command, "--transition-step");
        verifyOmits(command, "--transition-duration");
        verifyOmits(command, "--transition-bezier");
    }

    function test_awwwFadeArguments() {
        const command = transitionCommand("fade");
        verifyContains(command, "--transition-fps");
        verifyContains(command, "--transition-step");
        verifyContains(command, "--transition-duration");
        verifyContains(command, "--transition-bezier");
    }

    function test_awwwGrowArguments() {
        const command = transitionCommand("grow", {
            position: "bottom-right"
        });
        verifyContains(command, "--transition-step");
        verifyContains(command, "--transition-duration");
        verifyContains(command, "--transition-bezier");
        verifyContains(command, "--transition-pos");
        compare(command[command.indexOf("--transition-pos") + 1],
            "bottom-right");
    }

    function test_awwwWipeArguments() {
        const command = transitionCommand("wipe");
        verifyContains(command, "--transition-step");
        verifyContains(command, "--transition-duration");
        verifyContains(command, "--transition-bezier");
        verifyContains(command, "--transition-angle");
    }

    function test_awwwWaveArgumentsAndClamps() {
        const wave = transitionCommand("wave", {
            fps: 999,
            step: 999,
            durationMs: 999999,
            angle: -20,
            wave: "30,10"
        });
        compare(wave[wave.indexOf("--transition-fps") + 1], "240");
        compare(wave[wave.indexOf("--transition-step") + 1], "255");
        compare(
            wave[wave.indexOf("--transition-duration") + 1],
            "60.000");
        verifyContains(wave, "--transition-bezier");
        compare(
            wave[wave.indexOf("--transition-angle") + 1], "0");
        compare(
            wave[wave.indexOf("--transition-wave") + 1], "30,10");
    }

    function test_awwwOuterAndRandomArguments() {
        const types = [
            "fade", "left", "right", "top", "bottom",
            "wipe", "wave", "grow", "center", "any",
            "outer", "random"
        ];
        for (let index = 0; index < types.length; index += 1) {
            const command = transitionCommand(types[index]);
            verifyContains(command, "--transition-step");
            verifyContains(command, "--transition-duration");
            verifyContains(command, "--transition-bezier");
        }
        verifyContains(transitionCommand("outer"),
            "--transition-pos");
    }

    function test_awwwRejectsDmsOnlyTransitionNames() {
        const command = AwwwCommand.apply(
            "mock-awww", "clavis-desktop", "DP-1",
            "/tmp/a.png", "Fill", {
                type: "portal",
                fps: 60,
                durationMs: 1000
            });
        compare(
            command[command.indexOf("--transition-type") + 1],
            "fade");
        verify(command.indexOf("portal") === -1);
    }
}
