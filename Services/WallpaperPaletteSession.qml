pragma Singleton

import QtQuick
import Quickshell
import qs.Services
import "../Common/functions/WallpaperSource.js" as Source
import "../Common/functions/ZenPalette.js" as Zen
import "../Common/functions/WallpaperPaletteScope.js" as Scope

Singleton {
    id: root
    property var scope: null
    property var draft: null
    property string originalSource: ""
    property string draftSource: ""
    property string capturedContext: ""
    property string error: ""
    property int token: 0
    property bool committing: false
    readonly property bool active: scope !== null
    readonly property bool desktopActive: active && scope.target === "desktop"
    signal invalidated(int sessionToken)

    function context() {
        const p = PersonalizationConfig;
        return JSON.stringify([p.wallpaperPath, p.wallpaperPathLight, p.wallpaperPathDark, p.monitorWallpapers,
                               p.perMonitorWallpaper, p.perModeWallpaper, p.overviewWallpaperPath,
                               p.overviewMonitorWallpapers, p.overviewPerMonitorWallpaper,
                               p.overviewUseDesktopWallpaper, p.desktopWallpaperBackend,
                               UiPreferences.darkMode, Quickshell.screens.map(s => s.name).sort()]);
    }
    function begin(target, output) {
        if (root.active) {
            const previous = root.token;
            root.cancel(previous);
            root.invalidated(previous);
        }
        if (target === "desktop" && PersonalizationConfig.desktopWallpaperBackend === "awww")
            return 0;
        if (target === "overview" && PersonalizationConfig.overviewUseDesktopWallpaper)
            return 0;
        if (output && !Quickshell.screens.some(s => s.name === output))
            return 0;
        const p = PersonalizationConfig;
        root.capturedContext = root.context();
        root.scope = {
            target: target,
            monitor: target === "overview" ? (p.overviewPerMonitorWallpaper ? output : "") : (
                                                 p.perMonitorWallpaper ? output : ""),
            field: target === "desktop" && p.perModeWallpaper ? (UiPreferences.darkMode ? "pathDark" : "pathLight") :
                                                                "path"
        };
        root.originalSource = target === "overview" ? WallpaperService.overviewWallpaperForScreen(output) :
                                                      WallpaperService.wallpaperForScreen(output);
        root.capturedContext = root.context();
        root.token += 1;
        root.error = "";
        var state = Source.decode(root.originalSource);
        if (!state) {
            state = Zen.fromHex(Source.primary(root.originalSource), Zen.initial()) || Zen.initial();
        }
        root.update(root.token, state);
        return root.token;
    }
    function validate() {
        if (!root.active)
            return false;
        if (root.committing || root.context() === root.capturedContext)
            return true;
        const oldToken = root.token;
        root.cancel(oldToken);
        root.invalidated(oldToken);
        return false;
    }
    function update(sessionToken, state) {
        if (sessionToken !== root.token || !root.validate())
            return false;
        const normalized = Source.normalizePalette(state);
        if (!normalized)
            return false;
        root.draft = normalized;
        root.draftSource = Source.encode(normalized);
        root.error = "";
        return true;
    }
    function previewForScreen(target, output) {
        return Scope.affects(root.scope, target, output, PersonalizationConfig, UiPreferences.darkMode)
                ? root.draftSource : "";
    }
    function commit(sessionToken) {
        if (sessionToken !== root.token || !root.validate())
            return false;
        const source = Source.encode(root.draft);
        if (!source)
            return false;
        if (source === root.originalSource) {
            root.cancel(sessionToken);
            return true;
        }
        root.committing = true;
        const desktop = root.desktopActive;
        const success = PersonalizationConfig.commitPalette(root.scope, source);
        root.committing = false;
        if (!success) {
            root.error = qsTr("Could not save the wallpaper. Try again.");
            return false;
        }
        root.capturedContext = root.context();
        if (desktop) {
            WallpaperService.currentWallpaper = source;
            ThemeService.generateFromColor(Source.primary(source));
        }
        // Let saved-source bindings adopt the already displayed palette first.
        Qt.callLater(() => root.cancel(sessionToken));
        return true;
    }
    function cancel(sessionToken) {
        if (sessionToken !== root.token)
            return;
        root.scope = null;
        root.draft = null;
        root.draftSource = "";
        root.capturedContext = "";
    }
    readonly property string liveContext: root.active ? root.context() : ""
    onLiveContextChanged: if (!root.committing)
                              root.validate()
}
