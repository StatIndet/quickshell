import QtQuick
import QtTest
import "../../Common/functions/WallpaperSource.js" as Source
import "../../Common/functions/ZenPalette.js" as Zen
import "../../Common/functions/WallpaperPaletteScope.js" as Scope

TestCase {
    name: "WallpaperSource"
    function test_roundTripAllPresets() {
        compare(Zen.presets.length, 41);
        for (let i = 0; i < Zen.presets.length; ++i) {
            const state = Zen.preset(i, Zen.initial());
            const encoded = Source.encode(state);
            compare(Source.kind(encoded), "palette");
            compare(JSON.stringify(Source.decode(encoded)), JSON.stringify(state));
            compare(Source.primary(encoded), Zen.primary(state));
            verify(!Source.supported(encoded, "awww"));
        }
    }
    function test_rejectInvalidState() {
        for (const pair of [["version", 2], ["count", 0], ["count", 4], ["count", 1.5], ["x", NaN], ["opacity",
                                                                                                     0], ["grain",
                                                                                                          1], ["algorithm",
                                                                                                               "triadic"],
                            ["type", "unknown"], ["lightness", null]]) {
            const state = Zen.initial();
            state[pair[0]] = pair[1];
            compare(Source.encode(state), "");
        }
        for (const source of ["clavis-palette:v2:{}", "clavis-palette:v1:%zz", "clavis-palette:v1:%7B%7D",
                              "#bad", "https://host/image.png"])
            compare(Source.kind(source), "invalid");
    }
    function test_legacyPaletteMode() {
        const state = Zen.initial();
        const canonical = Source.encode(state);
        for (const mode of ["light", "dark"]) {
            const legacy = Zen.copy(state);
            legacy.mode = mode;
            const encoded = Source.prefix + encodeURIComponent(JSON.stringify(legacy));
            compare(Source.encode(Source.decode(encoded)), canonical);
            compare(Source.primary(encoded), Source.primary(canonical));
        }
    }
    function test_legacySources() {
        compare(Source.kind("/wallpapers/a.png"), "image");
        compare(Source.localPath("file:///wallpapers/a%20b.png"), "/wallpapers/a b.png");
        compare(Source.kind("#80abcdef"), "solid");
        compare(Source.primary("#80abcdef"), "#abcdef");
        verify(!Source.supported("#abcdef", "awww"));
    }
    function test_harmoniesAndBoundary() {
        compare(Zen.algorithms(1).join(","), "floating");
        compare(Zen.algorithms(2).join(","), "complementary,singleAnalogous");
        compare(Zen.algorithms(3).join(","), "splitComplementary,analogous,triadic");
        let state = Zen.resize(Zen.initial(), 3);
        for (const algorithm of Zen.algorithms(3)) {
            state.algorithm = algorithm;
            state = Zen.move(state, 20, -30, 2);
            const points = Zen.positions(state);
            compare(points.length, 3);
            for (const point of points) {
                verify(point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1);
                verify(Number.isFinite(point.x) && Number.isFinite(point.y));
            }
            for (const rgb of Zen.colors(state))
                for (const c of rgb)
                    verify(c >= 0 && c <= 255);
        }
        compare(Zen.resize(state, 1).algorithm, "floating");
    }
    function test_precisionColorInverse() {
        for (const hex of ["#ff0000", "#123456", "#ffffff", "#000000", "#808080"]) {
            const state = Zen.fromHex(hex, Zen.initial());
            compare(Zen.primary(state), hex);
            verify(Source.encode(state) !== "");
        }
    }
    function test_colorPositionSemantics() {
        const state = Zen.initial();
        state.lightness = 50;
        compare(Zen.hex(Zen.colorAt({
                                        x: 191 / 380,
                                        y: 191 / 380
                                    }, state)), "#ff0000");
        compare(Zen.hex(Zen.colorAt({
                                        x: 396.2 / 380,
                                        y: 191 / 380
                                    }, state)), "#808080");
        state.type = "position";
        compare(Zen.hex(Zen.colorAt({
                                        x: 191 / 380,
                                        y: 191 / 380
                                    }, state)), "#000000");
        state.type = "explicit-black-white";
        compare(Zen.hex(Zen.colorAt({
                                        x: 396.2 / 380,
                                        y: 191 / 380
                                    }, state)), "#ffffff");
    }
    function test_previewScope() {
        const config = {
            perMonitorWallpaper: true,
            monitorWallpapers: {
                "DP-1": "/a.png"
            },
            perModeWallpaper: true,
            wallpaperPathDark: "/dark.png",
            wallpaperPathLight: "",
            overviewUseDesktopWallpaper: false,
            overviewWallpaperPath: "",
            overviewPerMonitorWallpaper: true,
            overviewMonitorWallpapers: {
                "DP-2": "/overview.png"
            }
        };
        const global = {
            target: "desktop",
            monitor: "",
            field: "path"
        };
        verify(!Scope.affects(global, "desktop", "DP-1", config, false));
        verify(Scope.affects(global, "desktop", "DP-2", config, false));
        verify(!Scope.affects(global, "desktop", "DP-2", config, true));
        verify(!Scope.affects(global, "overview", "DP-2", config, false));
        verify(Scope.affects(global, "overview", "DP-3", config, false));
        const mode = {
            target: "desktop",
            monitor: "",
            field: "pathDark"
        };
        verify(Scope.affects(mode, "desktop", "DP-2", config, true));
        verify(!Scope.affects(mode, "desktop", "DP-1", config, true));
        const monitor = {
            target: "desktop",
            monitor: "DP-1",
            field: "pathDark"
        };
        verify(Scope.affects(monitor, "desktop", "DP-1", config, true));
        verify(!Scope.affects(monitor, "desktop", "DP-2", config, true));
        const overview = {
            target: "overview",
            monitor: "",
            field: "path"
        };
        verify(!Scope.affects(overview, "desktop", "DP-3", config, false));
        verify(Scope.affects(overview, "overview", "DP-3", config, false));
        verify(!Scope.affects(overview, "overview", "DP-2", config, false));
        config.overviewUseDesktopWallpaper = true;
        verify(Scope.affects(global, "overview", "DP-2", config, false));
        verify(!Scope.affects(overview, "overview", "DP-3", config, false));
    }
}
