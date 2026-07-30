pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string configOverride:
        Quickshell.env("CLAVIS_PERSONALIZATION_CONFIG") || ""
    readonly property string filePath: root.configOverride !== ""
        ? root.configOverride
        : Paths.homeDir + "/.cache/quickshell/personalization.json"
    readonly property string configDir: {
        const separator = root.filePath.lastIndexOf("/");
        return separator > 0
            ? root.filePath.slice(0, separator)
            : Paths.homeDir + "/.cache/quickshell";
    }

    readonly property var fillModes: [
        ({ "value": "Stretch", "label": qsTr("拉伸") }),
        ({ "value": "Fit", "label": qsTr("适合") }),
        ({ "value": "Fill", "label": qsTr("填充") }),
        ({ "value": "Tile", "label": qsTr("平铺") }),
        ({ "value": "TileVertically", "label": qsTr("垂直平铺") }),
        ({ "value": "TileHorizontally", "label": qsTr("水平平铺") }),
        ({ "value": "Pad", "label": qsTr("覆盖") })
    ]
    readonly property var desktopFillModes: root.fillModes.concat([
        ({ "value": "panorama", "label": qsTr("全景") })
    ])

    readonly property var transitionTypes: [
        ({ "value": "random", "label": qsTr("随机") }),
        ({ "value": "none", "label": qsTr("无") }),
        ({ "value": "fade", "label": qsTr("淡入淡出") }),
        ({ "value": "wipe", "label": qsTr("擦除") }),
        ({ "value": "disc", "label": qsTr("圆盘") }),
        ({ "value": "stripes", "label": qsTr("条纹") }),
        ({ "value": "iris bloom", "label": qsTr("光圈绽放") }),
        ({ "value": "pixelate", "label": qsTr("像素化") }),
        ({ "value": "portal", "label": qsTr("门户") })
    ]

    readonly property var awwwTransitionTypes: [
        ({ "value": "none", "label": qsTr("无") }),
        ({ "value": "simple", "label": qsTr("简单") }),
        ({ "value": "fade", "label": qsTr("淡入淡出") }),
        ({ "value": "left", "label": qsTr("从左侧") }),
        ({ "value": "right", "label": qsTr("从右侧") }),
        ({ "value": "top", "label": qsTr("从顶部") }),
        ({ "value": "bottom", "label": qsTr("从底部") }),
        ({ "value": "wipe", "label": qsTr("擦除") }),
        ({ "value": "wave", "label": qsTr("波浪") }),
        ({ "value": "grow", "label": qsTr("扩散") }),
        ({ "value": "center", "label": qsTr("中心扩散") }),
        ({ "value": "any", "label": qsTr("随机位置扩散") }),
        ({ "value": "outer", "label": qsTr("向内收缩") }),
        ({ "value": "random", "label": qsTr("随机") })
    ]

    readonly property var transitionEasingModes: [
        ({ "value": "linear", "label": qsTr("线性") }),
        ({ "value": "quad", "label": qsTr("二次方") }),
        ({ "value": "cubic", "label": qsTr("三次方") }),
        ({ "value": "quart", "label": qsTr("四次方") }),
        ({ "value": "quint", "label": qsTr("五次方") }),
        ({ "value": "sine", "label": qsTr("正弦") }),
        ({ "value": "expo", "label": qsTr("指数") }),
        ({ "value": "circ", "label": qsTr("圆形") }),
        ({ "value": "customBezier", "label": qsTr("自定义贝塞尔") })
    ]

    readonly property var baseTransitions: ["fade", "wipe", "disc", "stripes", "iris bloom", "pixelate", "portal"]

    readonly property var matugenSchemes: [
        ({ "value": "scheme-tonal-spot", "label": qsTr("音色斑点") }),
        ({ "value": "scheme-vibrant", "label": qsTr("鲜艳") }),
        ({ "value": "scheme-content", "label": qsTr("内容") }),
        ({ "value": "scheme-expressive", "label": qsTr("具有表现力的") }),
        ({ "value": "scheme-fidelity", "label": qsTr("保真") }),
        ({ "value": "scheme-fruit-salad", "label": qsTr("水果沙拉") }),
        ({ "value": "scheme-monochrome", "label": qsTr("单色") }),
        ({ "value": "scheme-neutral", "label": qsTr("中性") }),
        ({ "value": "scheme-rainbow", "label": qsTr("彩虹") })
    ]
    readonly property var matugenTemplateIds: [
        "btop",
        "cava",
        "kitty",
        "fcitx5",
        "niri",
        "yazi",
        "zsh_prompt"
    ]

    readonly property var keystoneStyles: [
        ({ "value": "bangs", "label": qsTr("刘海") }),
        ({ "value": "pill", "label": qsTr("药丸") })
    ]
    readonly property var powerMenuStyles: [
        ({ "value": "grid", "label": qsTr("四宫格") }),
        ({ "value": "row", "label": qsTr("横向六项") })
    ]
    readonly property var clockStyles: [
        ({ "value": "staggered", "label": qsTr("错落滚动") }),
        ({ "value": "simple", "label": qsTr("简洁数字") })
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
    property string desktopWallpaperBackend: "quickshell"

    property bool autoCycleEnabled: false
    property string autoCycleMode: "interval"
    property int autoCycleInterval: 300
    property string autoCycleTime: "06:00"

    property string wallpaperTransitionType: "fade"
    property var includedTransitions: root.baseTransitions
    property int transitionDurationMs: 1000
    property string transitionEasingMode: "customBezier"
    property var transitionBezierCurve: [0.43, 1.19, 1.0, 0.4, 1.0, 1.0]

    property string awwwDesktopTransitionType: "fade"
    property int awwwTransitionFps: 60
    property int awwwTransitionStep: 90
    property real awwwTransitionAngle: 45
    property string awwwTransitionPosition: "center"
    property string awwwTransitionWave: "20,20"

    property bool overviewEnabled: true
    property bool overviewUseDesktopWallpaper: true
    property string overviewWallpaperPath: ""
    property string overviewWallpaperFillMode: "Fill"
    property bool overviewPerMonitorWallpaper: false
    property var overviewMonitorWallpapers: ({})
    property var overviewMonitorFillModes: ({})
    property string overviewTransitionType: "fade"
    property real overviewBlurRadius: 0
    property real overviewDim: 0
    property real overviewSaturation: 1
    property real overviewContrast: 1

    property bool parallaxVerticalEnabled: false
    property bool parallaxFollowWorkspaces: true
    property bool parallaxFollowSidebars: false
    property bool parallaxFollowTiledColumns: false
    property real parallaxPreferredScale: 1.10
    property int parallaxTiledColumnSpan: 6

    property string matugenScheme: "scheme-tonal-spot"
    property var matugenTemplates: ({
        "btop": true,
        "cava": true,
        "kitty": true,
        "fcitx5": true,
        "niri": true,
        "yazi": true,
        "zsh_prompt": true
    })
    property string themeMode: "dark"
    property string themeModePolicy: "dark"
    property string cursorTheme: ""
    property int cursorSize: 24
    property bool cursorHideWhenTyping: false
    property int cursorHideAfterInactiveMs: 0
    property string iconTheme: ""
    property string keystoneStyle: "bangs"
    property string powerMenuStyle: "grid"
    property string clockStyle: "staggered"

    property real shellBackgroundOpacity: 1.0
    property bool shellBlurEnabled: false
    property bool shellBlurXray: true

    property bool pomodoroSoundEnabled: false

    property bool keepSidebarsLoaded: true

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

    function normalizedAwwwTransition(value) {
        return normalizedOption(root.awwwTransitionTypes, value, "fade");
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
        const fallback =
            [0.43, 1.19, 1.0, 0.4, 1.0, 1.0];
        if (!Array.isArray(raw) || raw.length < 4)
            return fallback.slice();

        const source = raw.length === 4 ? [raw[0], raw[1], raw[2], raw[3], 1, 1] : raw;
        const result = [];
        for (let i = 0; i < 6; i += 1) {
            const value = Number(source[i]);
            result.push(isFinite(value) ? value : fallback[i]);
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

    function normalizedStringMap(raw) {
        const result = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw))
            return result;

        for (let key in raw)
            result[String(key)] = String(raw[key] || "");
        return result;
    }

    function normalizedMatugenTemplates(raw) {
        const source = raw && typeof raw === "object"
            && !Array.isArray(raw) ? raw : {};
        const result = {};
        for (let i = 0; i < root.matugenTemplateIds.length; i += 1) {
            const id = root.matugenTemplateIds[i];
            result[id] = source[id] === undefined ? true : !!source[id];
        }
        return result;
    }

    function normalizedFillModeMap(raw, options) {
        const result = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw))
            return result;

        const validOptions = options || root.desktopFillModes;
        for (let key in raw)
            result[String(key)] = normalizedOption(
                validOptions, raw[key], "Fill");
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

    function setDesktopWallpaperBackend(value) {
        setValue("desktopWallpaperBackend",
            value === "awww" ? "awww" : "quickshell");
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
        setValue("wallpaperFillMode", normalizedOption(
            root.desktopFillModes, value, "Fill"));
    }

    function setMonitorWallpaperFillMode(screenName, value) {
        if (!screenName)
            return;
        const next = cloneMap(root.monitorWallpaperFillModes);
        next[screenName] = normalizedOption(
            root.desktopFillModes, value, "Fill");
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
        if (value === null || value === undefined || value === "")
            return fallback;
        const numberValue = Number(value);
        return !isFinite(numberValue)
            ? fallback
            : Math.max(0, Math.min(5000,
                Math.round(numberValue)));
    }

    function normalizedBoundedInt(value, fallback, minValue, maxValue) {
        if (value === null || value === undefined || value === "")
            return fallback;
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

    function normalizedBoundedReal(value, fallback, minValue, maxValue) {
        if (value === null || value === undefined || value === "")
            return fallback;
        const numberValue = Number(value);
        if (!isFinite(numberValue))
            return fallback;
        return Math.max(minValue, Math.min(maxValue, numberValue));
    }

    function normalizedAwwwPosition(value) {
        const position = String(value || "").trim();
        const aliases = [
            "center", "top", "left", "right", "bottom",
            "top-left", "top-right", "bottom-left", "bottom-right"
        ];
        if (aliases.indexOf(position) !== -1)
            return position;
        if (/^-?\d+(\.\d+)?,-?\d+(\.\d+)?$/.test(position))
            return position;
        return "center";
    }

    function normalizedAwwwWave(value) {
        const match = String(value || "").trim()
            .match(/^(\d+(\.\d+)?),(\d+(\.\d+)?)$/);
        if (!match)
            return "20,20";
        const width = normalizedBoundedReal(match[1], 20, 1, 1000);
        const height = normalizedBoundedReal(match[3], 20, 1, 1000);
        return width + "," + height;
    }

    function setAwwwDesktopTransitionType(value) {
        setValue("awwwDesktopTransitionType",
            normalizedAwwwTransition(value));
    }

    function setAwwwTransitionFps(value) {
        setValue("awwwTransitionFps",
            normalizedBoundedInt(value, 60, 10, 240));
    }

    function setAwwwTransitionStep(value) {
        setValue("awwwTransitionStep",
            normalizedBoundedInt(value, 90, 0, 255));
    }

    function setAwwwTransitionAngle(value) {
        setValue("awwwTransitionAngle",
            normalizedBoundedReal(value, 45, 0, 360));
    }

    function setAwwwTransitionPosition(value) {
        setValue("awwwTransitionPosition",
            normalizedAwwwPosition(value));
    }

    function setAwwwTransitionWave(value) {
        setValue("awwwTransitionWave", normalizedAwwwWave(value));
    }

    function setOverviewEnabled(value) {
        setValue("overviewEnabled", !!value);
    }

    function setOverviewUseDesktopWallpaper(value) {
        setValue("overviewUseDesktopWallpaper", !!value);
    }

    function setOverviewWallpaperPath(value) {
        setValue("overviewWallpaperPath", value || "");
    }

    function setOverviewWallpaperFillMode(value) {
        setValue("overviewWallpaperFillMode",
            normalizedOption(root.fillModes, value, "Fill"));
    }

    function setOverviewPerMonitorWallpaper(value) {
        setValue("overviewPerMonitorWallpaper", !!value);
    }

    function setOverviewMonitorWallpaper(screenName, value) {
        if (!screenName)
            return;
        const next = cloneMap(root.overviewMonitorWallpapers);
        next[screenName] = value || "";
        root.overviewMonitorWallpapers = next;
        root.save();
    }

    function overviewMonitorWallpaper(screenName) {
        if (!screenName || !root.overviewMonitorWallpapers)
            return "";
        return root.overviewMonitorWallpapers[screenName] || "";
    }

    function setOverviewMonitorFillMode(screenName, value) {
        if (!screenName)
            return;
        const next = cloneMap(root.overviewMonitorFillModes);
        next[screenName] =
            normalizedOption(root.fillModes, value, "Fill");
        root.overviewMonitorFillModes = next;
        root.save();
    }

    function overviewMonitorFillMode(screenName) {
        if (!screenName || !root.overviewMonitorFillModes)
            return root.overviewWallpaperFillMode;
        return root.overviewMonitorFillModes[screenName]
            || root.overviewWallpaperFillMode;
    }

    function setOverviewTransitionType(value) {
        setValue("overviewTransitionType", normalizedTransition(value));
    }

    function setOverviewBlurRadius(value) {
        setValue("overviewBlurRadius",
            normalizedBoundedReal(value, 0, 0, 100));
    }

    function setOverviewDim(value) {
        setValue("overviewDim",
            normalizedBoundedReal(value, 0, 0, 1));
    }

    function setOverviewSaturation(value) {
        setValue("overviewSaturation",
            normalizedBoundedReal(value, 1, 0, 2));
    }

    function setOverviewContrast(value) {
        setValue("overviewContrast",
            normalizedBoundedReal(value, 1, 0.5, 2));
    }

    function setParallaxVerticalEnabled(value) {
        setValue("parallaxVerticalEnabled", !!value);
    }

    function setParallaxFollowWorkspaces(value) {
        setValue("parallaxFollowWorkspaces", !!value);
    }

    function setParallaxFollowSidebars(value) {
        setValue("parallaxFollowSidebars", !!value);
    }

    function setParallaxFollowTiledColumns(value) {
        setValue("parallaxFollowTiledColumns", !!value);
    }

    function setParallaxPreferredScale(value) {
        setValue("parallaxPreferredScale",
            normalizedBoundedReal(value, 1.10, 1, 1.35));
    }

    function setParallaxTiledColumnSpan(value) {
        setValue("parallaxTiledColumnSpan",
            normalizedBoundedInt(value, 6, 2, 12));
    }

    function setMatugenScheme(value) {
        setValue("matugenScheme", normalizedOption(root.matugenSchemes, value, "scheme-tonal-spot"));
    }

    function isMatugenTemplateEnabled(id) {
        if (root.matugenTemplateIds.indexOf(id) === -1)
            return false;
        return root.matugenTemplates[id] !== false;
    }

    function setMatugenTemplateEnabled(id, enabled) {
        if (root.matugenTemplateIds.indexOf(id) === -1)
            return false;

        const nextEnabled = !!enabled;
        if (root.isMatugenTemplateEnabled(id) === nextEnabled)
            return false;

        const next = root.cloneMap(root.matugenTemplates);
        next[id] = nextEnabled;
        root.matugenTemplates = next;
        root.save();
        return true;
    }

    function setThemeMode(value) {
        const mode = value === "light" ? "light" : "dark";
        root.themeModePolicy = mode;
        root.themeMode = mode;
        root.save();
    }

    function setThemeModePolicy(value) {
        const policy = value === "sunrise-sunset"
            ? "sunrise-sunset"
            : (value === "light" ? "light" : "dark");
        if (root.themeModePolicy === policy)
            return;
        root.themeModePolicy = policy;
        if (policy !== "sunrise-sunset")
            root.themeMode = policy;
        root.save();
    }

    function setEffectiveThemeMode(value) {
        const mode = value === "light" ? "light" : "dark";
        if (root.themeMode === mode)
            return false;
        root.themeMode = mode;
        return true;
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

    function setPowerMenuStyle(value) {
        setValue("powerMenuStyle", normalizedOption(
            root.powerMenuStyles, value, "grid"));
    }

    function setClockStyle(value) {
        setValue("clockStyle", normalizedOption(
            root.clockStyles, value, "staggered"));
    }

    function setShellBackgroundOpacity(value) {
        setValue("shellBackgroundOpacity",
            normalizedBoundedReal(value, 1.0, 0.0, 1.0));
    }

    function setShellBlurEnabled(value) {
        setValue("shellBlurEnabled", !!value);
    }

    function setShellBlurXray(value) {
        setValue("shellBlurXray", !!value);
    }

    function setPomodoroSoundEnabled(value) {
        setValue("pomodoroSoundEnabled", !!value);
    }

    function setKeepSidebarsLoaded(value) {
        setValue("keepSidebarsLoaded", !!value);
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
                "desktopBackend": root.desktopWallpaperBackend,
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
                },
                "awww": {
                    "transitionType": root.awwwDesktopTransitionType,
                    "transitionFps": root.awwwTransitionFps,
                    "transitionStep": root.awwwTransitionStep,
                    "transitionAngle": root.awwwTransitionAngle,
                    "transitionPosition": root.awwwTransitionPosition,
                    "transitionWave": root.awwwTransitionWave
                },
                "overview": {
                    "enabled": root.overviewEnabled,
                    "useDesktopWallpaper":
                        root.overviewUseDesktopWallpaper,
                    "path": root.overviewWallpaperPath,
                    "fillMode": root.overviewWallpaperFillMode,
                    "perMonitor": root.overviewPerMonitorWallpaper,
                    "monitorWallpapers":
                        root.overviewMonitorWallpapers,
                    "monitorFillModes":
                        root.overviewMonitorFillModes,
                    "transitionType": root.overviewTransitionType,
                    "blurRadius": root.overviewBlurRadius,
                    "dim": root.overviewDim,
                    "saturation": root.overviewSaturation,
                    "contrast": root.overviewContrast
                },
                "parallax": {
                    "verticalEnabled": root.parallaxVerticalEnabled,
                    "followWorkspaces":
                        root.parallaxFollowWorkspaces,
                    "followSidebars": root.parallaxFollowSidebars,
                    "followTiledColumns":
                        root.parallaxFollowTiledColumns,
                    "preferredScale": root.parallaxPreferredScale,
                    "tiledColumnSpan":
                        root.parallaxTiledColumnSpan
                }
            },
            "theme": {
                "matugenScheme": root.matugenScheme,
                "matugenTemplates":
                    root.cloneMap(root.matugenTemplates),
                "mode": root.themeModePolicy,
                "cursorTheme": root.cursorTheme,
                "cursorSize": root.cursorSize,
                "cursorHideWhenTyping": root.cursorHideWhenTyping,
                "cursorHideAfterInactiveMs": root.cursorHideAfterInactiveMs,
                "iconTheme": root.iconTheme,
                "powerMenuStyle": root.powerMenuStyle
            },
            "effects": {
                "shellBackgroundOpacity":
                    root.shellBackgroundOpacity,
                "shellBlurEnabled": root.shellBlurEnabled,
                "shellBlurXray": root.shellBlurXray
            },
            "keystone": {
                "style": root.keystoneStyle,
                "clockStyle": root.clockStyle
            },
            "sounds": {
                "pomodoro": root.pomodoroSoundEnabled
            },
            "sidebar": {
                "keepLoaded": root.keepSidebarsLoaded
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
        const effects = parsed.effects || {};
        const keystone = parsed.keystone || {};
        const sounds = parsed.sounds || {};
        const sidebar = parsed.sidebar || {};
        const interactions = parsed.interactions || {};
        const scrolling = interactions.scrolling || {};
        const transition = wallpaper.transition || {};
        const awww = wallpaper.awww || {};
        const overview = wallpaper.overview || {};
        const parallax = wallpaper.parallax || {};
        const autoCycle = wallpaper.autoCycle || {};

        root.wallpaperFolder = wallpaper.folder || Paths.homeDir + "/.config/wallpaper";
        root.wallpaperPath = wallpaper.path === Paths.currentWallpaper ? "" : (wallpaper.path || "");
        root.wallpaperPathLight = wallpaper.pathLight || "";
        root.wallpaperPathDark = wallpaper.pathDark || "";
        root.perModeWallpaper = !!wallpaper.perMode;
        root.perMonitorWallpaper = !!wallpaper.perMonitor;
        root.monitorWallpapers =
            normalizedStringMap(wallpaper.monitorWallpapers);
        root.monitorWallpaperFillModes =
            normalizedFillModeMap(wallpaper.monitorFillModes);
        root.recentWallpaperColors = normalizedRecentColors(wallpaper.recentColors);
        root.wallpaperFillMode = normalizedOption(
            root.desktopFillModes, wallpaper.fillMode, "Fill");
        root.desktopWallpaperBackend =
            wallpaper.desktopBackend === "awww"
                ? "awww" : "quickshell";
        root.autoCycleEnabled = !!autoCycle.enabled;
        root.autoCycleMode = autoCycle.mode === "time" ? "time" : "interval";
        root.autoCycleInterval = Math.max(5, Math.round(Number(autoCycle.interval) || 300));
        root.autoCycleTime = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(autoCycle.time || "") ? autoCycle.time : "06:00";
        root.wallpaperTransitionType = normalizedTransition(transition.type || "fade");
        root.includedTransitions = normalizedIncluded(transition.included);
        root.transitionDurationMs = normalizedDurationMs(transition.durationMs, 1000);
        root.transitionEasingMode = normalizedEasingMode(transition.easingMode || "customBezier");
        root.transitionBezierCurve = normalizedBezier(transition.bezierCurve);

        root.awwwDesktopTransitionType =
            normalizedAwwwTransition(awww.transitionType || "fade");
        root.awwwTransitionFps =
            normalizedBoundedInt(awww.transitionFps, 60, 10, 240);
        root.awwwTransitionStep =
            normalizedBoundedInt(awww.transitionStep, 90, 0, 255);
        root.awwwTransitionAngle =
            normalizedBoundedReal(awww.transitionAngle, 45, 0, 360);
        root.awwwTransitionPosition =
            normalizedAwwwPosition(awww.transitionPosition);
        root.awwwTransitionWave =
            normalizedAwwwWave(awww.transitionWave);

        root.overviewEnabled = overview.enabled === undefined
            ? true : !!overview.enabled;
        root.overviewUseDesktopWallpaper =
            overview.useDesktopWallpaper === undefined
                ? true : !!overview.useDesktopWallpaper;
        root.overviewWallpaperPath = String(overview.path || "");
        root.overviewWallpaperFillMode =
            normalizedOption(root.fillModes, overview.fillMode, "Fill");
        root.overviewPerMonitorWallpaper = !!overview.perMonitor;
        root.overviewMonitorWallpapers =
            normalizedStringMap(overview.monitorWallpapers);
        root.overviewMonitorFillModes =
            normalizedFillModeMap(
                overview.monitorFillModes, root.fillModes);
        root.overviewTransitionType =
            normalizedTransition(overview.transitionType || "fade");
        root.overviewBlurRadius =
            normalizedBoundedReal(overview.blurRadius, 0, 0, 100);
        root.overviewDim =
            normalizedBoundedReal(overview.dim, 0, 0, 1);
        root.overviewSaturation =
            normalizedBoundedReal(overview.saturation, 1, 0, 2);
        root.overviewContrast =
            normalizedBoundedReal(overview.contrast, 1, 0.5, 2);

        root.parallaxVerticalEnabled = !!parallax.verticalEnabled;
        root.parallaxFollowWorkspaces =
            parallax.followWorkspaces === undefined
                ? true : !!parallax.followWorkspaces;
        root.parallaxFollowSidebars = !!parallax.followSidebars;
        root.parallaxFollowTiledColumns =
            !!parallax.followTiledColumns;
        root.parallaxPreferredScale =
            normalizedBoundedReal(parallax.preferredScale,
                1.10, 1, 1.35);
        root.parallaxTiledColumnSpan =
            normalizedBoundedInt(parallax.tiledColumnSpan,
                6, 2, 12);

        root.matugenScheme = normalizedOption(root.matugenSchemes, theme.matugenScheme, "scheme-tonal-spot");
        root.matugenTemplates =
            normalizedMatugenTemplates(theme.matugenTemplates);
        root.themeModePolicy = theme.mode === "sunrise-sunset"
            ? "sunrise-sunset"
            : (theme.mode === "light" ? "light" : "dark");
        root.themeMode = root.themeModePolicy === "light" ? "light" : "dark";
        root.cursorTheme = theme.cursorTheme || "";
        root.cursorSize = Math.max(12, Math.min(128, Math.round(Number(theme.cursorSize) || 24)));
        root.cursorHideWhenTyping = !!theme.cursorHideWhenTyping;
        root.cursorHideAfterInactiveMs = Math.max(0, Math.min(5000, Math.round(Number(theme.cursorHideAfterInactiveMs) || 0)));
        root.iconTheme = theme.iconTheme || "";
        root.powerMenuStyle = normalizedOption(
            root.powerMenuStyles, theme.powerMenuStyle, "grid");
        root.shellBackgroundOpacity = normalizedBoundedReal(
            effects.shellBackgroundOpacity, 1.0, 0.0, 1.0);
        root.shellBlurEnabled =
            typeof effects.shellBlurEnabled === "boolean"
                ? effects.shellBlurEnabled : false;
        root.shellBlurXray =
            typeof effects.shellBlurXray === "boolean"
                ? effects.shellBlurXray : true;
        root.keystoneStyle = normalizedOption(root.keystoneStyles, keystone.style, "bangs");
        root.clockStyle = normalizedOption(
            root.clockStyles, keystone.clockStyle, "staggered");
        root.pomodoroSoundEnabled = !!sounds.pomodoro;
        root.keepSidebarsLoaded = sidebar.keepLoaded === undefined
            ? true : !!sidebar.keepLoaded;
        root.scrollSmoothEnabled = scrolling.smoothEnabled === undefined ? true : !!scrolling.smoothEnabled;
        root.scrollMouseFactor = normalizedBoundedInt(scrolling.mouseFactor, 50, 10, 240);
        root.scrollTouchpadFactor = normalizedBoundedInt(scrolling.touchpadFactor, 100, 10, 300);
        root.scrollMouseDeltaThreshold = normalizedBoundedInt(scrolling.mouseDeltaThreshold, 120, 60, 240);
    }

    function needsWallpaperMigration(parsed) {
        const wallpaper = parsed && parsed.wallpaper;
        if (!wallpaper || typeof wallpaper !== "object")
            return true;
        return wallpaper.desktopBackend === undefined
            || wallpaper.awww === undefined
            || wallpaper.overview === undefined
            || wallpaper.parallax === undefined;
    }

    function needsEffectsMigration(parsed) {
        const effects = parsed && parsed.effects;
        if (!effects || typeof effects !== "object"
                || Array.isArray(effects))
            return true;
        return effects.shellBackgroundOpacity === undefined
            || effects.shellBlurEnabled === undefined
            || effects.shellBlurXray === undefined;
    }

    function needsThemeMigration(parsed) {
        const theme = parsed && parsed.theme;
        return !theme || typeof theme !== "object"
            || Array.isArray(theme)
            || theme.powerMenuStyle === undefined
            || theme.matugenTemplates === undefined;
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
            let parsed = {};
            root.loading = true;
            try {
                parsed = JSON.parse(configFile.text().trim() || "{}");
                shouldRepair = root.needsWallpaperMigration(parsed)
                    || root.needsEffectsMigration(parsed)
                    || root.needsThemeMigration(parsed);
                root.loadFromObject(parsed);
                shouldRepair = shouldRepair
                    || JSON.stringify(parsed.wallpaper || {})
                        !== JSON.stringify(
                            root.toJson().wallpaper)
                    || JSON.stringify(parsed.effects || {})
                        !== JSON.stringify(
                            root.toJson().effects)
                    || JSON.stringify(parsed.theme || {})
                        !== JSON.stringify(root.toJson().theme);
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
