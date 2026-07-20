pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string configDir: Paths.homeDir + "/.cache/quickshell"
    readonly property string filePath: configDir + "/personalization.json"

    readonly property var fillModes: [
        ({ "value": "Stretch", "label": "拉伸" }),
        ({ "value": "Fit", "label": "适合" }),
        ({ "value": "Fill", "label": "填充" }),
        ({ "value": "Tile", "label": "平铺" }),
        ({ "value": "TileVertically", "label": "垂直平铺" }),
        ({ "value": "TileHorizontally", "label": "水平平铺" }),
        ({ "value": "Pad", "label": "覆盖" })
    ]

    readonly property var transitionTypes: [
        ({ "value": "random", "label": "随机" }),
        ({ "value": "none", "label": "无" }),
        ({ "value": "fade", "label": "淡入淡出" }),
        ({ "value": "wipe", "label": "擦除" }),
        ({ "value": "disc", "label": "圆盘" }),
        ({ "value": "stripes", "label": "条纹" }),
        ({ "value": "iris bloom", "label": "光圈绽放" }),
        ({ "value": "pixelate", "label": "像素化" }),
        ({ "value": "portal", "label": "门户" })
    ]

    readonly property var transitionEasingModes: [
        ({ "value": "linear", "label": "线性" }),
        ({ "value": "quad", "label": "二次方" }),
        ({ "value": "cubic", "label": "三次方" }),
        ({ "value": "quart", "label": "四次方" }),
        ({ "value": "quint", "label": "五次方" }),
        ({ "value": "sine", "label": "正弦" }),
        ({ "value": "expo", "label": "指数" }),
        ({ "value": "circ", "label": "圆形" }),
        ({ "value": "customBezier", "label": "自定义贝塞尔" })
    ]

    readonly property var baseTransitions: ["fade", "wipe", "disc", "stripes", "iris bloom", "pixelate", "portal"]

    readonly property var matugenSchemes: [
        ({ "value": "scheme-tonal-spot", "label": "音色斑点" }),
        ({ "value": "scheme-vibrant", "label": "鲜艳" }),
        ({ "value": "scheme-content", "label": "内容" }),
        ({ "value": "scheme-expressive", "label": "具有表现力的" }),
        ({ "value": "scheme-fidelity", "label": "保真" }),
        ({ "value": "scheme-fruit-salad", "label": "水果沙拉" }),
        ({ "value": "scheme-monochrome", "label": "单色" }),
        ({ "value": "scheme-neutral", "label": "中性" }),
        ({ "value": "scheme-rainbow", "label": "彩虹" })
    ]

    readonly property var keystoneStyles: [
        ({ "value": "bangs", "label": "刘海" }),
        ({ "value": "pill", "label": "药丸" })
    ]

    property bool storeReady: false
    property bool loading: false

    property string wallpaperFolder: Paths.homeDir + "/.config/wallpaper"
    property string wallpaperPath: ""
    property string wallpaperPathLight: ""
    property string wallpaperPathDark: ""
    property bool perModeWallpaper: false
    property bool perMonitorWallpaper: false
    property var monitorWallpapers: ({})
    property var monitorWallpaperFillModes: ({})
    property var recentWallpaperColors: []
    property string wallpaperFillMode: "Fill"

    property bool autoCycleEnabled: false
    property string autoCycleMode: "interval"
    property int autoCycleInterval: 300
    property string autoCycleTime: "06:00"

    property string wallpaperTransitionType: "fade"
    property var includedTransitions: root.baseTransitions
    property int transitionDurationMs: 1000
    property string transitionEasingMode: "customBezier"
    property var transitionBezierCurve: [0.43, 1.19, 1.0, 0.4, 1.0, 1.0]

    property string matugenScheme: "scheme-tonal-spot"
    property string themeMode: "dark"
    property string cursorTheme: ""
    property int cursorSize: 24
    property bool cursorHideWhenTyping: false
    property int cursorHideAfterInactiveMs: 0
    property string iconTheme: ""
    property string keystoneStyle: "bangs"

    property bool scrollSmoothEnabled: true
    property int scrollMouseFactor: 50
    property int scrollTouchpadFactor: 100
    property int scrollMouseDeltaThreshold: 120

    function optionExists(options, value) {
        for (let i = 0; i < options.length; i += 1) {
            if (options[i].value === value)
                return true;
        }
        return false;
    }

    function normalizedOption(options, value, fallback) {
        return optionExists(options, value) ? value : fallback;
    }

    function normalizedTransition(value) {
        return normalizedOption(root.transitionTypes, value, "fade");
    }

    function normalizedEasingMode(value) {
        return normalizedOption(root.transitionEasingModes, value, "customBezier");
    }

    function normalizedIncluded(raw) {
        if (!Array.isArray(raw))
            return root.baseTransitions.slice();

        const result = [];
        for (let i = 0; i < raw.length; i += 1) {
            const value = raw[i];
            if (root.baseTransitions.indexOf(value) !== -1 && result.indexOf(value) === -1)
                result.push(value);
        }
        return result.length > 0 ? result : root.baseTransitions.slice();
    }

    function normalizedBezier(raw) {
        if (!Array.isArray(raw) || raw.length < 4)
            return [0.43, 1.19, 1.0, 0.4, 1.0, 1.0];

        const source = raw.length === 4 ? [raw[0], raw[1], raw[2], raw[3], 1, 1] : raw;
        const result = [];
        for (let i = 0; i < 6; i += 1) {
            const value = Number(source[i]);
            result.push(isNaN(value) ? (i === 5 ? 1 : 0) : value);
        }
        return result;
    }

    function cloneMap(map) {
        const result = {};
        if (!map)
            return result;

        for (let key in map)
            result[key] = map[key];
        return result;
    }

    function normalizedRecentColors(raw) {
        if (!Array.isArray(raw))
            return [];

        const result = [];
        for (let i = 0; i < raw.length && result.length < 5; i += 1) {
            const value = String(raw[i] || "").trim().toLowerCase();
            if (/^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(value) && result.indexOf(value) === -1)
                result.push(value);
        }
        return result;
    }

    function setValue(propertyName, value) {
        if (root[propertyName] === value)
            return;
        root[propertyName] = value;
        root.save();
    }

    function setWallpaperFolder(value) {
        setValue("wallpaperFolder", value || Paths.homeDir + "/.config/wallpaper");
    }

    function setWallpaperPath(value) {
        setValue("wallpaperPath", value || "");
    }

    function setWallpaperPathForMode(mode, value) {
        if (mode === "light")
            setValue("wallpaperPathLight", value || "");
        else
            setValue("wallpaperPathDark", value || "");
    }

    function setPerModeWallpaper(value) {
        setValue("perModeWallpaper", !!value);
    }

    function setPerMonitorWallpaper(value) {
        setValue("perMonitorWallpaper", !!value);
    }

    function setMonitorWallpaper(screenName, value) {
        if (!screenName)
            return;
        const next = cloneMap(root.monitorWallpapers);
        next[screenName] = value || "";
        root.monitorWallpapers = next;
        root.save();
    }

    function monitorWallpaper(screenName) {
        if (!screenName || !root.monitorWallpapers)
            return "";
        return root.monitorWallpapers[screenName] || "";
    }

    function setWallpaperFillMode(value) {
        setValue("wallpaperFillMode", normalizedOption(root.fillModes, value, "Fill"));
    }

    function setMonitorWallpaperFillMode(screenName, value) {
        if (!screenName)
            return;
        const next = cloneMap(root.monitorWallpaperFillModes);
        next[screenName] = normalizedOption(root.fillModes, value, "Fill");
        root.monitorWallpaperFillModes = next;
        root.save();
    }

    function monitorFillMode(screenName) {
        if (!screenName || !root.monitorWallpaperFillModes)
            return root.wallpaperFillMode;
        return root.monitorWallpaperFillModes[screenName] || root.wallpaperFillMode;
    }

    function addRecentWallpaperColor(color) {
        const value = String(color || "").trim().toLowerCase();
        if (!/^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(value))
            return;

        const next = [value];
        const source = normalizedRecentColors(root.recentWallpaperColors);
        for (let i = 0; i < source.length && next.length < 5; i += 1) {
            if (source[i] !== value)
                next.push(source[i]);
        }

        root.recentWallpaperColors = next;
        root.save();
    }

    function setAutoCycleEnabled(value) {
        setValue("autoCycleEnabled", !!value);
    }

    function setAutoCycleMode(value) {
        setValue("autoCycleMode", value === "time" ? "time" : "interval");
    }

    function setAutoCycleInterval(value) {
        setValue("autoCycleInterval", Math.max(5, Math.round(Number(value) || 300)));
    }

    function setAutoCycleTime(value) {
        const next = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(value) ? value : "06:00";
        setValue("autoCycleTime", next);
    }

    function setWallpaperTransitionType(value) {
        setValue("wallpaperTransitionType", normalizedTransition(value));
    }

    function setIncludedTransitions(values) {
        root.includedTransitions = normalizedIncluded(values);
        root.save();
    }

    function setTransitionIncluded(value, enabled) {
        if (root.baseTransitions.indexOf(value) === -1)
            return;

        const next = root.includedTransitions.slice();
        const index = next.indexOf(value);
        if (enabled && index === -1)
            next.push(value);
        if (!enabled && index !== -1)
            next.splice(index, 1);
        root.setIncludedTransitions(next);
    }

    function normalizedDurationMs(value, fallback) {
        const numberValue = Number(value);
        return isNaN(numberValue) ? fallback : Math.max(0, Math.round(numberValue));
    }

    function normalizedBoundedInt(value, fallback, minValue, maxValue) {
        const numberValue = Number(value);
        if (isNaN(numberValue))
            return fallback;
        return Math.max(minValue, Math.min(maxValue, Math.round(numberValue)));
    }

    function setTransitionDurationMs(value) {
        setValue("transitionDurationMs", normalizedDurationMs(value, 0));
    }

    function setTransitionEasingMode(value) {
        setValue("transitionEasingMode", normalizedEasingMode(value));
    }

    function setTransitionBezierCurve(value) {
        root.transitionBezierCurve = normalizedBezier(value);
        root.save();
    }

    function setTransitionBezierControlPoints(x1, y1, x2, y2) {
        root.setTransitionBezierCurve([x1, y1, x2, y2, 1, 1]);
    }

    function setMatugenScheme(value) {
        setValue("matugenScheme", normalizedOption(root.matugenSchemes, value, "scheme-tonal-spot"));
    }

    function setThemeMode(value) {
        setValue("themeMode", value === "light" ? "light" : "dark");
    }

    function setCursorTheme(value) {
        setValue("cursorTheme", value || "");
    }

    function setCursorSize(value) {
        const numberValue = Math.round(Number(value) || 24);
        setValue("cursorSize", Math.max(12, Math.min(128, numberValue)));
    }

    function setCursorHideWhenTyping(value) {
        setValue("cursorHideWhenTyping", !!value);
    }

    function setCursorHideAfterInactiveMs(value) {
        const numberValue = Math.round(Number(value) || 0);
        setValue("cursorHideAfterInactiveMs", Math.max(0, Math.min(5000, numberValue)));
    }

    function setIconTheme(value) {
        setValue("iconTheme", value || "");
    }

    function setKeystoneStyle(value) {
        setValue("keystoneStyle", normalizedOption(root.keystoneStyles, value, "bangs"));
    }

    function setScrollSmoothEnabled(value) {
        setValue("scrollSmoothEnabled", !!value);
    }

    function setScrollMouseFactor(value) {
        setValue("scrollMouseFactor", normalizedBoundedInt(value, 50, 10, 240));
    }

    function setScrollTouchpadFactor(value) {
        setValue("scrollTouchpadFactor", normalizedBoundedInt(value, 100, 10, 300));
    }

    function setScrollMouseDeltaThreshold(value) {
        setValue("scrollMouseDeltaThreshold", normalizedBoundedInt(value, 120, 60, 240));
    }

    function toJson() {
        return {
            "wallpaper": {
                "folder": root.wallpaperFolder,
                "path": root.wallpaperPath,
                "pathLight": root.wallpaperPathLight,
                "pathDark": root.wallpaperPathDark,
                "perMode": root.perModeWallpaper,
                "perMonitor": root.perMonitorWallpaper,
                "monitorWallpapers": root.monitorWallpapers,
                "monitorFillModes": root.monitorWallpaperFillModes,
                "recentColors": root.recentWallpaperColors,
                "fillMode": root.wallpaperFillMode,
                "autoCycle": {
                    "enabled": root.autoCycleEnabled,
                    "mode": root.autoCycleMode,
                    "interval": root.autoCycleInterval,
                    "time": root.autoCycleTime
                },
                "transition": {
                    "type": root.wallpaperTransitionType,
                    "included": root.includedTransitions,
                    "durationMs": root.transitionDurationMs,
                    "easingMode": root.transitionEasingMode,
                    "bezierCurve": root.transitionBezierCurve
                }
            },
            "theme": {
                "matugenScheme": root.matugenScheme,
                "mode": root.themeMode,
                "cursorTheme": root.cursorTheme,
                "cursorSize": root.cursorSize,
                "cursorHideWhenTyping": root.cursorHideWhenTyping,
                "cursorHideAfterInactiveMs": root.cursorHideAfterInactiveMs,
                "iconTheme": root.iconTheme
            },
            "keystone": {
                "style": root.keystoneStyle
            },
            "interactions": {
                "scrolling": {
                    "smoothEnabled": root.scrollSmoothEnabled,
                    "mouseFactor": root.scrollMouseFactor,
                    "touchpadFactor": root.scrollTouchpadFactor,
                    "mouseDeltaThreshold": root.scrollMouseDeltaThreshold
                }
            }
        };
    }

    function loadFromObject(parsed) {
        const wallpaper = parsed.wallpaper || {};
        const theme = parsed.theme || {};
        const keystone = parsed.keystone || {};
        const interactions = parsed.interactions || {};
        const scrolling = interactions.scrolling || {};
        const transition = wallpaper.transition || {};
        const autoCycle = wallpaper.autoCycle || {};

        root.wallpaperFolder = wallpaper.folder || Paths.homeDir + "/.config/wallpaper";
        root.wallpaperPath = wallpaper.path === Paths.currentWallpaper ? "" : (wallpaper.path || "");
        root.wallpaperPathLight = wallpaper.pathLight || "";
        root.wallpaperPathDark = wallpaper.pathDark || "";
        root.perModeWallpaper = !!wallpaper.perMode;
        root.perMonitorWallpaper = !!wallpaper.perMonitor;
        root.monitorWallpapers = cloneMap(wallpaper.monitorWallpapers);
        root.monitorWallpaperFillModes = cloneMap(wallpaper.monitorFillModes);
        root.recentWallpaperColors = normalizedRecentColors(wallpaper.recentColors);
        root.wallpaperFillMode = normalizedOption(root.fillModes, wallpaper.fillMode, "Fill");
        root.autoCycleEnabled = !!autoCycle.enabled;
        root.autoCycleMode = autoCycle.mode === "time" ? "time" : "interval";
        root.autoCycleInterval = Math.max(5, Math.round(Number(autoCycle.interval) || 300));
        root.autoCycleTime = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(autoCycle.time || "") ? autoCycle.time : "06:00";
        root.wallpaperTransitionType = normalizedTransition(transition.type || "fade");
        root.includedTransitions = normalizedIncluded(transition.included);
        root.transitionDurationMs = normalizedDurationMs(transition.durationMs, 1000);
        root.transitionEasingMode = normalizedEasingMode(transition.easingMode || "customBezier");
        root.transitionBezierCurve = normalizedBezier(transition.bezierCurve);

        root.matugenScheme = normalizedOption(root.matugenSchemes, theme.matugenScheme, "scheme-tonal-spot");
        root.themeMode = theme.mode === "light" ? "light" : "dark";
        root.cursorTheme = theme.cursorTheme || "";
        root.cursorSize = Math.max(12, Math.min(128, Math.round(Number(theme.cursorSize) || 24)));
        root.cursorHideWhenTyping = !!theme.cursorHideWhenTyping;
        root.cursorHideAfterInactiveMs = Math.max(0, Math.min(5000, Math.round(Number(theme.cursorHideAfterInactiveMs) || 0)));
        root.iconTheme = theme.iconTheme || "";
        root.keystoneStyle = normalizedOption(root.keystoneStyles, keystone.style, "bangs");
        root.scrollSmoothEnabled = scrolling.smoothEnabled === undefined ? true : !!scrolling.smoothEnabled;
        root.scrollMouseFactor = normalizedBoundedInt(scrolling.mouseFactor, 50, 10, 240);
        root.scrollTouchpadFactor = normalizedBoundedInt(scrolling.touchpadFactor, 100, 10, 300);
        root.scrollMouseDeltaThreshold = normalizedBoundedInt(scrolling.mouseDeltaThreshold, 120, 60, 240);
    }

    function save() {
        if (!root.storeReady || root.loading)
            return;
        configFile.setText(JSON.stringify(root.toJson(), null, 2));
    }

    Process {
        id: ensureStoreDir
        command: ["mkdir", "-p", root.configDir]
        running: true
        onExited: {
            root.storeReady = true;
            configFile.reload();
        }
    }

    Timer {
        id: configReloadDebounce

        interval: 50
        repeat: false
        onTriggered: configFile.reload()
    }

    FileView {
        id: configFile
        path: root.filePath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true

        onFileChanged: configReloadDebounce.restart()

        onLoaded: {
            let shouldRepair = false;
            root.loading = true;
            try {
                root.loadFromObject(JSON.parse(configFile.text().trim() || "{}"));
            } catch (error) {
                console.log("PersonalizationConfig failed to load:", error);
                shouldRepair = true;
            } finally {
                root.loading = false;
            }

            if (shouldRepair)
                root.save();
        }

        onLoadFailed: root.save()
    }
}
