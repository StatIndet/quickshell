import QtQuick 2.15
import QtTest 1.3
import "../../Modules/SystemCards/SystemCardState.js" as CardState

TestCase {
    function test_legacyMissingStateDefaultsEveryCardToSidebar() {
        const state = CardState.normalize({
        });
        compare(state.version, 3);
        compare(Object.keys(state.cards).length, 11);
        compare(CardState.activeSidebarIds(state).length, 11);
        compare(CardState.activeDesktopIds(state).length, 0);
        compare(state.cards.cpu.enabled, true);
        compare(state.cards.cpu.container, "sidebar");
        compare(state.cards.cpu.desktop.placementSpace, "screen");
    }

    function test_containerTransferCreatesScreenPlacement() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "cpu", "desktop", "DP-2", 0.25, 0.4, "screen");
        compare(CardState.activeSidebarIds(state).indexOf("cpu"), -1);
        compare(CardState.activeDesktopIds(state).indexOf("cpu") >= 0, true);
        compare(state.cards.cpu.screenName, "DP-2");
        compare(state.cards.cpu.desktop.placementSpace, "screen");
        compare(state.cards.cpu.desktop.screen.xNorm, 0.25);
        compare(state.cards.cpu.desktop.screen.yNorm, 0.4);
        state = CardState.setContainer(state, "cpu", "sidebar", "");
        compare(CardState.activeDesktopIds(state).indexOf("cpu"), -1);
        compare(CardState.activeSidebarIds(state).indexOf("cpu") >= 0, true);
    }

    function test_disabledCardKeepsBothCoordinateSpaces() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "weather", "desktop", "DP-1", 0.8, 0.2, "screen");
        state = CardState.setDesktopWallpaperPosition(state, "weather", 0.13, 0.77);
        state = CardState.setEnabled(state, "weather", false);
        compare(state.cards.weather.enabled, false);
        compare(state.cards.weather.container, "desktop");
        compare(state.cards.weather.screenName, "DP-1");
        compare(state.cards.weather.desktop.placementSpace, "screen");
        compare(state.cards.weather.desktop.screen.xNorm, 0.8);
        compare(state.cards.weather.desktop.wallpaper.xNorm, 0.13);
        compare(state.cards.weather.desktop.wallpaper.yNorm, 0.77);
        compare(CardState.activeDesktopIds(state).indexOf("weather"), -1);
        state = CardState.setEnabled(state, "weather", true);
        compare(CardState.activeDesktopIds(state).indexOf("weather") >= 0, true);
    }

    function test_legacyWallpaperCoordinatesAreNotMisreadAsScreen() {
        const state = CardState.normalize({
            "version": 2,
            "globalDesktopLayoutMode": "leastBusy",
            "cards": {
                "cpu": {
                    "container": "desktop",
                    "screenName": "DP-1",
                    "desktop": {
                        "xNorm": 0.21,
                        "yNorm": 0.34
                    }
                }
            }
        });
        compare(state.version, 3);
        compare(state.cards.cpu.desktop.placementSpace, "wallpaper");
        compare(state.cards.cpu.desktop.wallpaper.xNorm, 0.21);
        compare(state.cards.cpu.desktop.wallpaper.yNorm, 0.34);
        compare(state.cards.cpu.desktop.screen.xNorm, 0.5);
        compare(state.cards.cpu.desktop.screen.yNorm, 0.5);
    }

    function test_legacyPerCardModesAreIgnored() {
        const state = CardState.normalize({
            "version": 2,
            "globalDesktopLayoutMode": "leastBusy",
            "cards": {
                "cpu": {
                    "container": "desktop",
                    "screenName": "DP-1",
                    "desktop": {
                        "xNorm": 0.21,
                        "yNorm": 0.34,
                        "mode": "free"
                    }
                },
                "gpu": {
                    "container": "desktop",
                    "screenName": "DP-1",
                    "desktop": {
                        "xNorm": 0.61,
                        "yNorm": 0.72,
                        "mode": "mostBusy"
                    }
                }
            }
        });
        compare(state.globalDesktopLayoutMode, "leastBusy");
        verify(!Object.prototype.hasOwnProperty.call(state.cards.cpu.desktop, "mode"));
        verify(!Object.prototype.hasOwnProperty.call(state.cards.gpu.desktop, "mode"));
    }

    function test_missingOutputUsesDeterministicFallback() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "cpu", "desktop", "DP-9", 0.2, 0.3, "screen");
        compare(CardState.resolvedScreenName(state, "cpu", ["DP-2", "DP-1"]), "DP-1");
        compare(CardState.resolvedScreenName(state, "cpu", []), "DP-9");
    }

    function test_screenAndWallpaperCoordinatesRemainIndependent() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "calendar", "desktop", "DP-2", 0.1, 0.9, "screen");
        state = CardState.setDesktopWallpaperPosition(state, "calendar", 0.7, 0.2);
        state = CardState.setPlacementSpace(state, "calendar", "wallpaper");
        compare(state.cards.calendar.desktop.screen.xNorm, 0.1);
        compare(state.cards.calendar.desktop.screen.yNorm, 0.9);
        compare(state.cards.calendar.desktop.wallpaper.xNorm, 0.7);
        compare(state.cards.calendar.desktop.wallpaper.yNorm, 0.2);
        compare(state.cards.calendar.desktop.placementSpace, "wallpaper");
    }

    function test_serializedStateRoundTripsNestedCoordinates() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "calendar", "desktop", "DP-2", 0.1, 0.9, "screen");
        state = CardState.setEnabled(state, "battery", false);
        const encoded = JSON.stringify(CardState.serialize(state));
        const restored = CardState.normalize(JSON.parse(encoded));
        compare(restored.version, 3);
        compare(restored.cards.calendar.container, "desktop");
        compare(restored.cards.calendar.desktop.placementSpace, "screen");
        compare(restored.cards.calendar.desktop.screen.xNorm, 0.1);
        verify(!Object.prototype.hasOwnProperty.call(restored.cards.calendar.desktop, "xNorm"));
        compare(restored.cards.battery.enabled, false);
    }

    function test_globalModeDoesNotMutateCoordinates() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "cpu", "desktop", "DP-1", 0.25, 0.4, "screen");
        state = CardState.setDesktopWallpaperPosition(state, "cpu", 0.75, 0.1);
        const before = JSON.stringify(state.cards.cpu.desktop);
        state = CardState.setGlobalMode(state, "mostBusy");
        compare(state.globalDesktopLayoutMode, "mostBusy");
        compare(JSON.stringify(state.cards.cpu.desktop), before);
    }

    function test_screenAnchorModesAreValidGlobalModes() {
        const modes = ["screenTopLeft", "screenTopRight", "screenBottomLeft", "screenBottomRight", "screenCenter"];
        modes.forEach(function(mode) {
            verify(CardState.validDesktopLayoutMode(mode));
            verify(CardState.isScreenLayoutMode(mode));
            compare(CardState.isWallpaperLayoutMode(mode), false);
        });
        verify(CardState.isWallpaperLayoutMode("leastBusy"));
        verify(CardState.isWallpaperLayoutMode("mostBusy"));
        verify(CardState.isFreeMode("free"));
    }

    function test_autoToFreeMigrationKeepsTheCapturedScreenPoint() {
        let state = CardState.normalize({
            "globalDesktopLayoutMode": "leastBusy"
        });
        state = CardState.setContainer(state, "cpu", "desktop", "DP-1", 0.2, 0.3, "screen");
        state = CardState.setDesktopWallpaperPosition(state, "cpu", 0.8, 0.6);
        state = CardState.setPlacementSpace(state, "cpu", "wallpaper");
        // The Canvas captures the current screen point before this state
        // operation in the real mode switch. The state API then changes only
        // the controlling space and screen coordinates.
        state = CardState.setDesktopScreenPosition(state, "cpu", 0.2, 0.3);
        compare(state.cards.cpu.desktop.placementSpace, "screen");
        compare(state.cards.cpu.desktop.screen.xNorm, 0.2);
        compare(state.cards.cpu.desktop.screen.yNorm, 0.3);
        compare(state.cards.cpu.desktop.wallpaper.xNorm, 0.8);
        compare(state.cards.cpu.desktop.wallpaper.yNorm, 0.6);
    }

    function test_batchScreenPositionsUsesOneScreenPlacementOperation() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "cpu", "desktop", "DP-1", 0.1, 0.1, "screen");
        state = CardState.setContainer(state, "gpu", "desktop", "DP-1", 0.2, 0.2, "wallpaper");
        state = CardState.setDesktopScreenPositions(state, [{
            "id": "cpu",
            "xNorm": 0.7,
            "yNorm": 0.8
        }, {
            "id": "gpu",
            "xNorm": 0.3,
            "yNorm": 0.4
        }]);
        compare(state.cards.cpu.desktop.placementSpace, "screen");
        compare(state.cards.gpu.desktop.placementSpace, "screen");
        compare(state.cards.cpu.desktop.screen.xNorm, 0.7);
        compare(state.cards.gpu.desktop.screen.yNorm, 0.4);
    }

    function test_freeToAutomaticMigrationKeepsWallpaperTargetSeparate() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "gpu", "desktop", "DP-1", 0.42, 0.28, "screen");
        state = CardState.setDesktopWallpaperPosition(state, "gpu", 0.12, 0.74);
        state = CardState.setGlobalMode(state, "mostBusy");
        compare(state.cards.gpu.desktop.placementSpace, "screen");
        compare(state.cards.gpu.desktop.screen.xNorm, 0.42);
        compare(state.cards.gpu.desktop.wallpaper.xNorm, 0.12);
        compare(state.cards.gpu.desktop.wallpaper.yNorm, 0.74);
    }

    function test_monitorOwnershipFollowsDesktopCardsNotViewport() {
        let state = CardState.normalize({
        });
        state = CardState.setContainer(state, "cpu", "desktop", "DP-1", 0.2, 0.3, "screen");
        verify(CardState.requiresMonitor(state, "cpu"));
        state = CardState.setContainer(state, "storage", "desktop", "DP-1", 0.2, 0.3, "screen");
        verify(CardState.requiresMonitor(state, "storage"));
        state = CardState.setContainer(state, "battery", "desktop", "DP-1", 0.2, 0.3, "screen");
        verify(!CardState.requiresMonitor(state, "battery"));
        verify(!CardState.requiresMonitor(state, "time"));
        state = CardState.setEnabled(state, "cpu", false);
        verify(!CardState.requiresMonitor(state, "cpu"));
        state = CardState.setEnabled(state, "cpu", true);
        state = CardState.setContainer(state, "cpu", "sidebar", "");
        verify(!CardState.requiresMonitor(state, "cpu"));
    }

    name: "SystemCardState"
}
