pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string configOverride: Quickshell.env("CLAVIS_PERSONALIZATION_CONFIG") || ""
    readonly property string filePath: root.configOverride !== "" ? root.configOverride : Paths.configHome + "/config.json"
    readonly property string configDir: {
        const separator = root.filePath.lastIndexOf("/");
        return separator > 0 ? root.filePath.slice(0, separator) : Paths.configHome;
    }
    readonly property var fillModes: [({
        "value": "Stretch",
        "label": qsTr("拉伸")
    }), ({
        "value": "Fit",
        "label": qsTr("适合")
    }), ({
        "value": "Fill",
        "label": qsTr("填充")
    }), ({
        "value": "Tile",
        "label": qsTr("平铺")
    }), ({
        "value": "TileVertically",
        "label": qsTr("垂直平铺")
    }), ({
        "value": "TileHorizontally",
        "label": qsTr("水平平铺")
    }), ({
        "value": "Pad",
        "label": qsTr("覆盖")
    })]
    readonly property var desktopFillModes: root.fillModes.concat([({
        "value": "panorama",
        "label": qsTr("全景")
    })])
    readonly property var transitionTypes: [({
        "value": "random",
        "label": qsTr("随机")
    }), ({
        "value": "none",
        "label": qsTr("无")
    }), ({
        "value": "fade",
        "label": qsTr("淡入淡出")
    }), ({
        "value": "wipe",
        "label": qsTr("擦除")
    }), ({
        "value": "disc",
        "label": qsTr("圆盘")
    }), ({
        "value": "stripes",
        "label": qsTr("条纹")
    }), ({
        "value": "iris bloom",
        "label": qsTr("光圈绽放")
    }), ({
        "value": "pixelate",
        "label": qsTr("像素化")
    }), ({
        "value": "portal",
        "label": qsTr("门户")
    })]
    readonly property var awwwTransitionTypes: [({
        "value": "none",
        "label": qsTr("无")
    }), ({
        "value": "simple",
        "label": qsTr("简单")
    }), ({
        "value": "fade",
        "label": qsTr("淡入淡出")
    }), ({
        "value": "left",
        "label": qsTr("从左侧")
    }), ({
        "value": "right",
        "label": qsTr("从右侧")
    }), ({
        "value": "top",
        "label": qsTr("从顶部")
    }), ({
        "value": "bottom",
        "label": qsTr("从底部")
    }), ({
        "value": "wipe",
        "label": qsTr("擦除")
    }), ({
        "value": "wave",
        "label": qsTr("波浪")
    }), ({
        "value": "grow",
        "label": qsTr("扩散")
    }), ({
        "value": "center",
        "label": qsTr("中心扩散")
    }), ({
        "value": "any",
        "label": qsTr("随机位置扩散")
    }), ({
        "value": "outer",
        "label": qsTr("向内收缩")
    }), ({
        "value": "random",
        "label": qsTr("随机")
    })]
    readonly property var transitionEasingModes: [({
        "value": "linear",
        "label": qsTr("线性")
    }), ({
        "value": "quad",
        "label": qsTr("二次方")
    }), ({
        "value": "cubic",
        "label": qsTr("三次方")
    }), ({
        "value": "quart",
        "label": qsTr("四次方")
    }), ({
        "value": "quint",
        "label": qsTr("五次方")
    }), ({
        "value": "sine",
        "label": qsTr("正弦")
    }), ({
        "value": "expo",
        "label": qsTr("指数")
    }), ({
        "value": "circ",
        "label": qsTr("圆形")
    }), ({
        "value": "customBezier",
        "label": qsTr("自定义贝塞尔")
    })]
    readonly property var baseTransitions: ["fade", "wipe", "disc", "stripes", "iris bloom", "pixelate", "portal"]
    readonly property var matugenSchemes: [({
        "value": "scheme-tonal-spot",
        "label": qsTr("音色斑点")
    }), ({
        "value": "scheme-vibrant",
        "label": qsTr("鲜艳")
    }), ({
        "value": "scheme-content",
        "label": qsTr("内容")
    }), ({
        "value": "scheme-expressive",
        "label": qsTr("具有表现力的")
    }), ({
        "value": "scheme-fidelity",
        "label": qsTr("保真")
    }), ({
        "value": "scheme-fruit-salad",
        "label": qsTr("水果沙拉")
    }), ({
        "value": "scheme-monochrome",
        "label": qsTr("单色")
    }), ({
        "value": "scheme-neutral",
        "label": qsTr("中性")
    }), ({
        "value": "scheme-rainbow",
        "label": qsTr("彩虹")
    })]
    readonly property var matugenTemplateIds: ["btop", "cava", "kitty", "yazi"]
    readonly property var keystoneStyles: [({
        "value": "bangs",
        "label": qsTr("刘海")
    }), ({
        "value": "pill",
        "label": qsTr("药丸")
    })]
    readonly property var edgePositions: [({
        "value": "top",
        "label": qsTr("顶部"),
        "icon": "arrow_upward"
    }), ({
        "value": "left",
        "label": qsTr("左侧"),
        "icon": "arrow_back"
    }), ({
        "value": "bottom",
        "label": qsTr("底部"),
        "icon": "arrow_downward"
    }), ({
        "value": "right",
        "label": qsTr("右侧"),
        "icon": "arrow_forward"
    })]
    property bool storeReady: false
    property bool loading: false
    property bool loaded: false
    readonly property bool ready: root.storeReady && root.loaded && !root.loading
    property string wallpaperFolder: Paths.dataHome + "/wallpapers"
    property string wallpaperPath: ""
    property string wallpaperPathLight: ""
    property string wallpaperPathDark: ""
    property bool perModeWallpaper: false
    property bool perMonitorWallpaper: false
    property var monitorWallpapers: ({
    })
    property var monitorWallpaperFillModes: ({
    })
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
    property var transitionBezierCurve: [0.43, 1.19, 1, 0.4, 1, 1]
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
    property var overviewMonitorWallpapers: ({
    })
    property var overviewMonitorFillModes: ({
    })
    property string overviewTransitionType: "fade"
    property real overviewBlurRadius: 0
    property real overviewDim: 0
    property real overviewSaturation: 1
    property real overviewContrast: 1
    property bool parallaxVerticalEnabled: false
    property bool parallaxFollowWorkspaces: true
    property bool parallaxFollowSidebars: false
    property bool parallaxFollowTiledColumns: false
    property real parallaxPreferredScale: 1.1
    property int parallaxTiledColumnSpan: 6
    property string matugenScheme: "scheme-tonal-spot"
    property var matugenTemplates: ({
        "btop": true,
        "cava": true,
        "kitty": true,
        "yazi": true
    })
    property string themeMode: "dark"
    property string cursorTheme: ""
    property int cursorSize: 24
    property bool cursorHideWhenTyping: false
    property int cursorHideAfterInactiveMs: 0
    property string iconTheme: ""
    property string keystoneStyle: "bangs"
    property string barPosition: "top"
    readonly property var barComponentIds: ["workspaces", "information", "activeWindow", "tray", "systemMonitor", "quickSettings"]
    readonly property var defaultBarLeadingComponents: ["workspaces", "information", "activeWindow"]
    readonly property var defaultBarTrailingComponents: ["tray", "systemMonitor", "quickSettings"]
    readonly property var barComponentOptions: [({
        "value": "workspaces",
        "label": qsTr("工作区")
    }), ({
        "value": "information",
        "label": qsTr("信息中心")
    }), ({
        "value": "activeWindow",
        "label": qsTr("聚焦窗口")
    }), ({
        "value": "tray",
        "label": qsTr("托盘")
    }), ({
        "value": "systemMonitor",
        "label": qsTr("系统监控")
    }), ({
        "value": "quickSettings",
        "label": qsTr("快捷设置")
    })]
    readonly property var quickSettingsComponentIds: ["network", "bluetooth", "brightness", "volume", "microphone", "battery", "settings", "power"]
    readonly property var defaultQuickSettingsComponents: root.quickSettingsComponentIds.slice()
    readonly property var quickSettingsComponentOptions: [({
        "value": "network",
        "label": qsTr("网络")
    }), ({
        "value": "bluetooth",
        "label": qsTr("蓝牙")
    }), ({
        "value": "brightness",
        "label": qsTr("亮度")
    }), ({
        "value": "volume",
        "label": qsTr("音量")
    }), ({
        "value": "microphone",
        "label": qsTr("麦克风")
    }), ({
        "value": "battery",
        "label": qsTr("电池")
    }), ({
        "value": "settings",
        "label": qsTr("设置")
    }), ({
        "value": "power",
        "label": qsTr("电源")
    })]
    property var barLeadingComponents: root.defaultBarLeadingComponents.slice()
    property var barTrailingComponents: root.defaultBarTrailingComponents.slice()
    property var quickSettingsComponents: root.defaultQuickSettingsComponents.slice()
    property string keystonePosition: "top"
    property bool keystoneHideDate: false
    readonly property var horizontalClockAxisDefaults: ({
        "wght": 900,
        "wdth": 85,
        "opsz": 18,
        "GRAD": 0,
        "ROND": 25,
        "slnt": 0
    })
    readonly property var horizontalClockAxisMinimums: ({
        "wght": 1,
        "wdth": 25,
        "opsz": 6,
        "GRAD": 0,
        "ROND": 0,
        "slnt": -10
    })
    readonly property var horizontalClockAxisMaximums: ({
        "wght": 1000,
        "wdth": 151,
        "opsz": 144,
        "GRAD": 100,
        "ROND": 100,
        "slnt": 0
    })
    readonly property var horizontalClockDigitDefaults: ({
        "h0": ({
            "x": 0,
            "y": -2,
            "rotation": -3,
            "colorRole": "inversePrimary",
            "customColor": ""
        }),
        "h1": ({
            "x": 0,
            "y": 1,
            "rotation": 3,
            "colorRole": "primary",
            "customColor": ""
        }),
        "m0": ({
            "x": 0,
            "y": -1,
            "rotation": -2,
            "colorRole": "inversePrimary",
            "customColor": ""
        }),
        "m1": ({
            "x": 0,
            "y": 1,
            "rotation": 2,
            "colorRole": "primary",
            "customColor": ""
        }),
        "ap": ({
            "x": 1,
            "y": -2,
            "rotation": -2,
            "colorRole": "inversePrimary",
            "customColor": ""
        }),
        "periodM": ({
            "x": 1,
            "y": 1,
            "rotation": 2,
            "colorRole": "primary",
            "customColor": ""
        })
    })
    property int horizontalClockFontSize: 22
    property var horizontalClockAxes: ({
        "wght": 900,
        "wdth": 85,
        "opsz": 18,
        "GRAD": 0,
        "ROND": 25,
        "slnt": 0
    })
    property var horizontalClockDigits: ({
        "h0": ({
            "x": 0,
            "y": -2,
            "rotation": -3,
            "colorRole": "inversePrimary",
            "customColor": ""
        }),
        "h1": ({
            "x": 0,
            "y": 1,
            "rotation": 3,
            "colorRole": "primary",
            "customColor": ""
        }),
        "m0": ({
            "x": 0,
            "y": -1,
            "rotation": -2,
            "colorRole": "inversePrimary",
            "customColor": ""
        }),
        "m1": ({
            "x": 0,
            "y": 1,
            "rotation": 2,
            "colorRole": "primary",
            "customColor": ""
        }),
        "ap": ({
            "x": 1,
            "y": -2,
            "rotation": -2,
            "colorRole": "inversePrimary",
            "customColor": ""
        }),
        "periodM": ({
            "x": 1,
            "y": 1,
            "rotation": 2,
            "colorRole": "primary",
            "customColor": ""
        })
    })
    readonly property string uiFontFamily: Fonts.configuredUi || Fonts.defaultUi
    readonly property string monoFontFamily: Fonts.configuredMono || Fonts.defaultMono
    readonly property string numericFontFamily: Fonts.configuredNumeric || Fonts.defaultNumeric
    readonly property string expressiveFontFamily: Fonts.configuredExpressive || Fonts.bundledFamilyName
    property real shellBackgroundOpacity: 1
    property bool shellBlurEnabled: false
    property bool shellBlurXray: true
    property bool keepSidebarsLoaded: true

    signal settingsLoaded()

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

    function normalizedEdgePosition(value) {
        return normalizedOption(root.edgePositions, value, "top");
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
        const fallback = [0.43, 1.19, 1, 0.4, 1, 1];
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
        const result = {
        };
        if (!map)
            return result;

        for (let key in map) result[key] = map[key]
        return result;
    }

    function normalizedStringMap(raw) {
        const result = {
        };
        if (!raw || typeof raw !== "object" || Array.isArray(raw))
            return result;

        for (let key in raw) result[String(key)] = String(raw[key] || "")
        return result;
    }

    function normalizedCursorTheme(value) {
        if (typeof value !== "string")
            return "";

        const result = value.trim();
        if (result.length > 256 || /[\u0000-\u001f\u007f]/.test(result))
            return "";

        return result;
    }

    function normalizedMatugenTemplates(raw) {
        const source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {
        };
        const result = {
        };
        for (let i = 0; i < root.matugenTemplateIds.length; i += 1) {
            const id = root.matugenTemplateIds[i];
            result[id] = source[id] === undefined ? true : !!source[id];
        }
        return result;
    }

    function normalizedFillModeMap(raw, options) {
        const result = {
        };
        if (!raw || typeof raw !== "object" || Array.isArray(raw))
            return result;

        const validOptions = options || root.desktopFillModes;
        for (let key in raw) result[String(key)] = normalizedOption(validOptions, raw[key], "Fill")
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
            return ;

        root[propertyName] = value;
        root.save();
    }

    function setWallpaperFolder(value) {
        setValue("wallpaperFolder", value || Paths.dataHome + "/wallpapers");
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
        setValue("desktopWallpaperBackend", value === "awww" ? "awww" : "quickshell");
    }

    function setMonitorWallpaper(screenName, value) {
        if (!screenName)
            return ;

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
        setValue("wallpaperFillMode", normalizedOption(root.desktopFillModes, value, "Fill"));
    }

    function setMonitorWallpaperFillMode(screenName, value) {
        if (!screenName)
            return ;

        const next = cloneMap(root.monitorWallpaperFillModes);
        next[screenName] = normalizedOption(root.desktopFillModes, value, "Fill");
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
            return ;

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
            return ;

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
        return !isFinite(numberValue) ? fallback : Math.max(0, Math.min(5000, Math.round(numberValue)));
    }

    function normalizedBoundedInt(value, fallback, minValue, maxValue) {
        if (value === null || value === undefined || value === "")
            return fallback;

        const numberValue = Number(value);
        if (!isFinite(numberValue))
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

    function normalizedHorizontalClockAxes(raw) {
        const source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {
        };
        const result = {
        };
        const names = ["wght", "wdth", "opsz", "GRAD", "ROND", "slnt"];
        for (let i = 0; i < names.length; i += 1) {
            const name = names[i];
            result[name] = root.normalizedBoundedReal(source[name], root.horizontalClockAxisDefaults[name], root.horizontalClockAxisMinimums[name], root.horizontalClockAxisMaximums[name]);
        }
        return result;
    }

    function normalizedHorizontalClockDigits(raw) {
        const source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {
        };
        const result = {
        };
        const ids = ["h0", "h1", "m0", "m1", "ap", "periodM"];
        const colorRoles = ["primary", "inversePrimary", "custom"];
        for (let i = 0; i < ids.length; i += 1) {
            const id = ids[i];
            const fallback = root.horizontalClockDigitDefaults[id];
            const candidate = source[id] && typeof source[id] === "object" && !Array.isArray(source[id]) ? source[id] : {
            };
            const candidateColor = String(candidate.customColor || "").trim().toLowerCase();
            const hasCustomColor = /^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(candidateColor);
            let colorRole = colorRoles.indexOf(candidate.colorRole) !== -1 ? candidate.colorRole : fallback.colorRole;
            if (colorRole === "custom" && !hasCustomColor)
                colorRole = fallback.colorRole;

            result[id] = {
                "x": root.normalizedBoundedInt(candidate.x, fallback.x, -8, 8),
                "y": root.normalizedBoundedInt(candidate.y, fallback.y, -6, 6),
                "rotation": root.normalizedBoundedInt(candidate.rotation, fallback.rotation, -12, 12),
                "colorRole": colorRole,
                "customColor": hasCustomColor ? candidateColor : ""
            };
        }
        return result;
    }

    function horizontalClockDigit(id) {
        const defaults = root.horizontalClockDigitDefaults[id];
        const configured = root.horizontalClockDigits[id];
        return configured || defaults;
    }

    function horizontalClockDigitColor(id) {
        const digit = root.horizontalClockDigit(id);
        if (digit.colorRole === "custom" && /^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(String(digit.customColor || "")))
            return digit.customColor;

        return digit.colorRole === "inversePrimary" ? Appearance.colors.colInversePrimary : Appearance.colors.colPrimary;
    }

    function normalizedAwwwPosition(value) {
        const position = String(value || "").trim();
        const aliases = ["center", "top", "left", "right", "bottom", "top-left", "top-right", "bottom-left", "bottom-right"];
        if (aliases.indexOf(position) !== -1)
            return position;

        if (/^-?\d+(\.\d+)?,-?\d+(\.\d+)?$/.test(position))
            return position;

        return "center";
    }

    function normalizedAwwwWave(value) {
        const match = String(value || "").trim().match(/^(\d+(\.\d+)?),(\d+(\.\d+)?)$/);
        if (!match)
            return "20,20";

        const width = normalizedBoundedReal(match[1], 20, 1, 1000);
        const height = normalizedBoundedReal(match[3], 20, 1, 1000);
        return width + "," + height;
    }

    function setAwwwDesktopTransitionType(value) {
        setValue("awwwDesktopTransitionType", normalizedAwwwTransition(value));
    }

    function setAwwwTransitionFps(value) {
        setValue("awwwTransitionFps", normalizedBoundedInt(value, 60, 10, 240));
    }

    function setAwwwTransitionStep(value) {
        setValue("awwwTransitionStep", normalizedBoundedInt(value, 90, 0, 255));
    }

    function setAwwwTransitionAngle(value) {
        setValue("awwwTransitionAngle", normalizedBoundedReal(value, 45, 0, 360));
    }

    function setAwwwTransitionPosition(value) {
        setValue("awwwTransitionPosition", normalizedAwwwPosition(value));
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
        setValue("overviewWallpaperFillMode", normalizedOption(root.fillModes, value, "Fill"));
    }

    function setOverviewPerMonitorWallpaper(value) {
        setValue("overviewPerMonitorWallpaper", !!value);
    }

    function setOverviewMonitorWallpaper(screenName, value) {
        if (!screenName)
            return ;

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
            return ;

        const next = cloneMap(root.overviewMonitorFillModes);
        next[screenName] = normalizedOption(root.fillModes, value, "Fill");
        root.overviewMonitorFillModes = next;
        root.save();
    }

    function overviewMonitorFillMode(screenName) {
        if (!screenName || !root.overviewMonitorFillModes)
            return root.overviewWallpaperFillMode;

        return root.overviewMonitorFillModes[screenName] || root.overviewWallpaperFillMode;
    }

    function setOverviewTransitionType(value) {
        setValue("overviewTransitionType", normalizedTransition(value));
    }

    function setOverviewBlurRadius(value) {
        setValue("overviewBlurRadius", normalizedBoundedReal(value, 0, 0, 100));
    }

    function setOverviewDim(value) {
        setValue("overviewDim", normalizedBoundedReal(value, 0, 0, 1));
    }

    function setOverviewSaturation(value) {
        setValue("overviewSaturation", normalizedBoundedReal(value, 1, 0, 2));
    }

    function setOverviewContrast(value) {
        setValue("overviewContrast", normalizedBoundedReal(value, 1, 0.5, 2));
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
        setValue("parallaxPreferredScale", normalizedBoundedReal(value, 1.1, 1, 1.35));
    }

    function setParallaxTiledColumnSpan(value) {
        setValue("parallaxTiledColumnSpan", normalizedBoundedInt(value, 6, 2, 12));
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
        setValue("themeMode", value === "light" ? "light" : "dark");
    }

    function setCursorTheme(value) {
        setValue("cursorTheme", root.normalizedCursorTheme(value));
    }

    function setCursorSize(value) {
        setValue("cursorSize", root.normalizedBoundedInt(value, 24, 12, 128));
    }

    function setCursorHideWhenTyping(value) {
        setValue("cursorHideWhenTyping", typeof value === "boolean" ? value : false);
    }

    function setCursorHideAfterInactiveMs(value) {
        setValue("cursorHideAfterInactiveMs", root.normalizedBoundedInt(value, 0, 0, 5000));
    }

    function setIconTheme(value) {
        setValue("iconTheme", value || "");
    }

    function setKeystoneStyle(value) {
        setValue("keystoneStyle", normalizedOption(root.keystoneStyles, value, "bangs"));
    }

    function setFontFamily(role, family) {
        const allowedRoles = ["ui", "mono", "numeric", "expressive"];
        if (allowedRoles.indexOf(role) === -1)
            return false;

        const value = String(family || "").trim();
        if (value === "")
            return false;

        if (!FontService.containsFamily(value))
            return false;

        if (!Fonts.setConfiguredFamily(role, value))
            return false;

        root.save();
        return true;
    }

    function resetFontFamilies() {
        Fonts.resetConfiguredFamilies();
        root.save();
    }

    function setShellBackgroundOpacity(value) {
        setValue("shellBackgroundOpacity", normalizedBoundedReal(value, 1, 0, 1));
    }

    function setShellBlurEnabled(value) {
        setValue("shellBlurEnabled", !!value);
    }

    function setShellBlurXray(value) {
        setValue("shellBlurXray", !!value);
    }

    function setKeepSidebarsLoaded(value) {
        setValue("keepSidebarsLoaded", !!value);
    }

    function setBarPosition(value) {
        setValue("barPosition", normalizedEdgePosition(value));
    }

    function normalizedBarComponents(raw, excluded) {
        const source = Array.isArray(raw) ? raw : [];
        const blocked = excluded || [];
        const result = [];
        for (let index = 0; index < source.length; index += 1) {
            const componentId = String(source[index] || "");
            if (root.barComponentIds.indexOf(componentId) === -1 || blocked.indexOf(componentId) !== -1 || result.indexOf(componentId) !== -1)
                continue;

            result.push(componentId);
        }
        return result;
    }

    function normalizedBarLayout(leading, trailing, useDefaults) {
        const normalizedLeading = root.normalizedBarComponents(useDefaults ? root.defaultBarLeadingComponents : leading, []);
        const normalizedTrailing = root.normalizedBarComponents(useDefaults ? root.defaultBarTrailingComponents : trailing, normalizedLeading);
        return {
            "leading": normalizedLeading,
            "trailing": normalizedTrailing
        };
    }

    function barZoneComponents(zone) {
        return zone === "leading" ? root.barLeadingComponents : zone === "trailing" ? root.barTrailingComponents : [];
    }

    function moveBarComponent(componentId, targetZone, targetIndex) {
        const id = String(componentId || "");
        if (root.barComponentIds.indexOf(id) === -1 || (targetZone !== "leading" && targetZone !== "trailing"))
            return false;

        const leading = root.normalizedBarComponents(root.barLeadingComponents, []).filter((value) => {
            return value !== id;
        });
        const trailing = root.normalizedBarComponents(root.barTrailingComponents, leading).filter((value) => {
            return value !== id;
        });
        const target = targetZone === "leading" ? leading : trailing;
        const numericIndex = Number(targetIndex);
        const insertionIndex = isFinite(numericIndex) ? Math.max(0, Math.min(target.length, Math.round(numericIndex))) : target.length;
        target.splice(insertionIndex, 0, id);
        root.barLeadingComponents = leading;
        root.barTrailingComponents = trailing;
        root.save();
        return true;
    }

    function removeBarComponent(componentId) {
        const id = String(componentId || "");
        if (root.barComponentIds.indexOf(id) === -1)
            return false;

        const leading = root.barLeadingComponents.filter((value) => {
            return value !== id;
        });
        const trailing = root.barTrailingComponents.filter((value) => {
            return value !== id;
        });
        if (leading.length === root.barLeadingComponents.length && trailing.length === root.barTrailingComponents.length)
            return false;

        root.barLeadingComponents = root.normalizedBarComponents(leading, []);
        root.barTrailingComponents = root.normalizedBarComponents(trailing, root.barLeadingComponents);
        root.save();
        return true;
    }

    function toggleBarComponent(componentId, zone) {
        if (zone !== "leading" && zone !== "trailing")
            return false;

        if (root.barZoneComponents(zone).indexOf(componentId) !== -1)
            return root.removeBarComponent(componentId);

        return root.moveBarComponent(componentId, zone, root.barZoneComponents(zone).length);
    }

    function resetBarComponents() {
        root.barLeadingComponents = root.defaultBarLeadingComponents.slice();
        root.barTrailingComponents = root.defaultBarTrailingComponents.slice();
        root.save();
    }

    function normalizedQuickSettingsComponents(raw) {
        const source = Array.isArray(raw) ? raw : root.defaultQuickSettingsComponents;
        const result = [];
        for (let index = 0; index < source.length; index += 1) {
            const componentId = String(source[index] || "");
            if (root.quickSettingsComponentIds.indexOf(componentId) === -1 || result.indexOf(componentId) !== -1)
                continue;

            result.push(componentId);
        }
        return result;
    }

    function moveQuickSettingsComponent(componentId, targetIndex) {
        const id = String(componentId || "");
        if (root.quickSettingsComponentIds.indexOf(id) === -1)
            return false;

        const components = root.normalizedQuickSettingsComponents(root.quickSettingsComponents).filter((value) => {
            return value !== id;
        });
        const numericIndex = Number(targetIndex);
        const insertionIndex = isFinite(numericIndex) ? Math.max(0, Math.min(components.length, Math.round(numericIndex))) : components.length;
        components.splice(insertionIndex, 0, id);
        root.quickSettingsComponents = components;
        root.save();
        return true;
    }

    function removeQuickSettingsComponent(componentId) {
        const id = String(componentId || "");
        const components = root.quickSettingsComponents.filter((value) => {
            return value !== id;
        });
        if (components.length === root.quickSettingsComponents.length)
            return false;

        root.quickSettingsComponents = root.normalizedQuickSettingsComponents(components);
        root.save();
        return true;
    }

    function toggleQuickSettingsComponent(componentId) {
        const id = String(componentId || "");
        if (root.quickSettingsComponents.indexOf(id) !== -1)
            return root.removeQuickSettingsComponent(id);

        return root.moveQuickSettingsComponent(id, root.quickSettingsComponents.length);
    }

    function resetQuickSettingsComponents() {
        root.quickSettingsComponents = root.defaultQuickSettingsComponents.slice();
        root.save();
    }

    function setKeystonePosition(value) {
        setValue("keystonePosition", normalizedEdgePosition(value));
    }

    function setKeystoneHideDate(value) {
        setValue("keystoneHideDate", !!value);
    }

    function resetHorizontalClock(persist) {
        root.keystoneHideDate = false;
        root.horizontalClockFontSize = 22;
        root.horizontalClockAxes = root.normalizedHorizontalClockAxes(root.horizontalClockAxisDefaults);
        root.horizontalClockDigits = root.normalizedHorizontalClockDigits(root.horizontalClockDigitDefaults);
        if (persist !== false)
            root.save();

    }

    function setHorizontalClockFontSize(value, persist) {
        const next = root.normalizedBoundedInt(value, 22, 16, 28);
        if (root.horizontalClockFontSize === next) {
            if (persist !== false)
                root.save();

            return ;
        }
        root.horizontalClockFontSize = next;
        if (persist !== false)
            root.save();

    }

    function setHorizontalClockAxis(axis, value, persist) {
        const name = String(axis || "");
        if (root.horizontalClockAxisDefaults[name] === undefined)
            return ;

        const next = root.normalizedBoundedReal(value, root.horizontalClockAxisDefaults[name], root.horizontalClockAxisMinimums[name], root.horizontalClockAxisMaximums[name]);
        const current = root.horizontalClockAxes[name];
        if (current === next) {
            if (persist !== false)
                root.save();

            return ;
        }
        const axes = root.cloneMap(root.horizontalClockAxes);
        axes[name] = next;
        root.horizontalClockAxes = root.normalizedHorizontalClockAxes(axes);
        if (persist !== false)
            root.save();

    }

    function setHorizontalClockDigitValue(id, field, value, persist) {
        const name = String(id || "");
        const propertyName = String(field || "");
        const fallback = root.horizontalClockDigitDefaults[name];
        if (!fallback || ["x", "y", "rotation"].indexOf(propertyName) === -1)
            return ;

        const limits = propertyName === "x" ? [-8, 8] : propertyName === "y" ? [-6, 6] : [-12, 12];
        const current = root.horizontalClockDigit(name);
        const next = root.normalizedBoundedInt(value, fallback[propertyName], limits[0], limits[1]);
        if (current[propertyName] === next) {
            if (persist !== false)
                root.save();

            return ;
        }
        const digits = root.normalizedHorizontalClockDigits(root.horizontalClockDigits);
        digits[name][propertyName] = next;
        root.horizontalClockDigits = digits;
        if (persist !== false)
            root.save();

    }

    function setHorizontalClockDigitColor(id, role, customColor, persist) {
        const name = String(id || "");
        const fallback = root.horizontalClockDigitDefaults[name];
        if (!fallback)
            return ;

        const candidateRole = String(role || "");
        const normalizedColor = String(customColor || "").trim().toLowerCase();
        const customValid = /^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(normalizedColor);
        const validRole = ["primary", "inversePrimary"].indexOf(candidateRole) !== -1;
        const nextRole = validRole || (candidateRole === "custom" && customValid) ? candidateRole : fallback.colorRole;
        const digits = root.normalizedHorizontalClockDigits(root.horizontalClockDigits);
        digits[name].colorRole = nextRole;
        digits[name].customColor = customValid ? normalizedColor : "";
        root.horizontalClockDigits = digits;
        if (persist !== false)
            root.save();

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
                    "useDesktopWallpaper": root.overviewUseDesktopWallpaper,
                    "path": root.overviewWallpaperPath,
                    "fillMode": root.overviewWallpaperFillMode,
                    "perMonitor": root.overviewPerMonitorWallpaper,
                    "monitorWallpapers": root.overviewMonitorWallpapers,
                    "monitorFillModes": root.overviewMonitorFillModes,
                    "transitionType": root.overviewTransitionType,
                    "blurRadius": root.overviewBlurRadius,
                    "dim": root.overviewDim,
                    "saturation": root.overviewSaturation,
                    "contrast": root.overviewContrast
                },
                "parallax": {
                    "verticalEnabled": root.parallaxVerticalEnabled,
                    "followWorkspaces": root.parallaxFollowWorkspaces,
                    "followSidebars": root.parallaxFollowSidebars,
                    "followTiledColumns": root.parallaxFollowTiledColumns,
                    "preferredScale": root.parallaxPreferredScale,
                    "tiledColumnSpan": root.parallaxTiledColumnSpan
                }
            },
            "theme": {
                "matugenScheme": root.matugenScheme,
                "matugenTemplates": root.cloneMap(root.matugenTemplates),
                "mode": root.themeMode,
                "cursorTheme": root.cursorTheme,
                "cursorSize": root.cursorSize,
                "cursorHideWhenTyping": root.cursorHideWhenTyping,
                "cursorHideAfterInactiveMs": root.cursorHideAfterInactiveMs,
                "iconTheme": root.iconTheme,
                "fonts": {
                    "ui": root.uiFontFamily,
                    "mono": root.monoFontFamily,
                    "numeric": root.numericFontFamily,
                    "expressive": root.expressiveFontFamily
                }
            },
            "effects": {
                "shellBackgroundOpacity": root.shellBackgroundOpacity,
                "shellBlurEnabled": root.shellBlurEnabled,
                "shellBlurXray": root.shellBlurXray
            },
            "keystone": {
                "style": root.keystoneStyle,
                "position": root.keystonePosition,
                "hideDate": root.keystoneHideDate,
                "horizontalClock": {
                    "fontSize": root.horizontalClockFontSize,
                    "axes": root.cloneMap(root.horizontalClockAxes),
                    "digits": root.horizontalClockDigits
                }
            },
            "bar": {
                "position": root.barPosition,
                "barLeadingComponents": root.barLeadingComponents.slice(),
                "barTrailingComponents": root.barTrailingComponents.slice(),
                "quickSettingsComponents": root.quickSettingsComponents.slice()
            },
            "sidebar": {
                "keepLoaded": root.keepSidebarsLoaded
            }
        };
    }

    function loadFromObject(parsed) {
        const wallpaper = parsed.wallpaper || {
        };
        const theme = parsed.theme || {
        };
        const effects = parsed.effects || {
        };
        const keystone = parsed.keystone || {
        };
        const bar = parsed.bar || {
        };
        const sidebar = parsed.sidebar || {
        };
        const transition = wallpaper.transition || {
        };
        const awww = wallpaper.awww || {
        };
        const overview = wallpaper.overview || {
        };
        const parallax = wallpaper.parallax || {
        };
        const autoCycle = wallpaper.autoCycle || {
        };
        const fonts = theme.fonts || {
        };
        const horizontalClock = keystone.horizontalClock || {
        };
        root.wallpaperFolder = wallpaper.folder || Paths.dataHome + "/wallpapers";
        root.wallpaperPath = wallpaper.path === Paths.currentWallpaper ? "" : (wallpaper.path || "");
        root.wallpaperPathLight = wallpaper.pathLight || "";
        root.wallpaperPathDark = wallpaper.pathDark || "";
        root.perModeWallpaper = !!wallpaper.perMode;
        root.perMonitorWallpaper = !!wallpaper.perMonitor;
        root.monitorWallpapers = normalizedStringMap(wallpaper.monitorWallpapers);
        root.monitorWallpaperFillModes = normalizedFillModeMap(wallpaper.monitorFillModes);
        root.recentWallpaperColors = normalizedRecentColors(wallpaper.recentColors);
        root.wallpaperFillMode = normalizedOption(root.desktopFillModes, wallpaper.fillMode, "Fill");
        root.desktopWallpaperBackend = wallpaper.desktopBackend === "awww" ? "awww" : "quickshell";
        root.autoCycleEnabled = !!autoCycle.enabled;
        root.autoCycleMode = autoCycle.mode === "time" ? "time" : "interval";
        root.autoCycleInterval = Math.max(5, Math.round(Number(autoCycle.interval) || 300));
        root.autoCycleTime = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(autoCycle.time || "") ? autoCycle.time : "06:00";
        root.wallpaperTransitionType = normalizedTransition(transition.type || "fade");
        root.includedTransitions = normalizedIncluded(transition.included);
        root.transitionDurationMs = normalizedDurationMs(transition.durationMs, 1000);
        root.transitionEasingMode = normalizedEasingMode(transition.easingMode || "customBezier");
        root.transitionBezierCurve = normalizedBezier(transition.bezierCurve);
        root.awwwDesktopTransitionType = normalizedAwwwTransition(awww.transitionType || "fade");
        root.awwwTransitionFps = normalizedBoundedInt(awww.transitionFps, 60, 10, 240);
        root.awwwTransitionStep = normalizedBoundedInt(awww.transitionStep, 90, 0, 255);
        root.awwwTransitionAngle = normalizedBoundedReal(awww.transitionAngle, 45, 0, 360);
        root.awwwTransitionPosition = normalizedAwwwPosition(awww.transitionPosition);
        root.awwwTransitionWave = normalizedAwwwWave(awww.transitionWave);
        root.overviewEnabled = overview.enabled === undefined ? true : !!overview.enabled;
        root.overviewUseDesktopWallpaper = overview.useDesktopWallpaper === undefined ? true : !!overview.useDesktopWallpaper;
        root.overviewWallpaperPath = String(overview.path || "");
        root.overviewWallpaperFillMode = normalizedOption(root.fillModes, overview.fillMode, "Fill");
        root.overviewPerMonitorWallpaper = !!overview.perMonitor;
        root.overviewMonitorWallpapers = normalizedStringMap(overview.monitorWallpapers);
        root.overviewMonitorFillModes = normalizedFillModeMap(overview.monitorFillModes, root.fillModes);
        root.overviewTransitionType = normalizedTransition(overview.transitionType || "fade");
        root.overviewBlurRadius = normalizedBoundedReal(overview.blurRadius, 0, 0, 100);
        root.overviewDim = normalizedBoundedReal(overview.dim, 0, 0, 1);
        root.overviewSaturation = normalizedBoundedReal(overview.saturation, 1, 0, 2);
        root.overviewContrast = normalizedBoundedReal(overview.contrast, 1, 0.5, 2);
        root.parallaxVerticalEnabled = !!parallax.verticalEnabled;
        root.parallaxFollowWorkspaces = parallax.followWorkspaces === undefined ? true : !!parallax.followWorkspaces;
        root.parallaxFollowSidebars = !!parallax.followSidebars;
        root.parallaxFollowTiledColumns = !!parallax.followTiledColumns;
        root.parallaxPreferredScale = normalizedBoundedReal(parallax.preferredScale, 1.1, 1, 1.35);
        root.parallaxTiledColumnSpan = normalizedBoundedInt(parallax.tiledColumnSpan, 6, 2, 12);
        root.matugenScheme = normalizedOption(root.matugenSchemes, theme.matugenScheme, "scheme-tonal-spot");
        root.matugenTemplates = normalizedMatugenTemplates(theme.matugenTemplates);
        root.themeMode = theme.mode === "light" ? "light" : "dark";
        root.cursorTheme = root.normalizedCursorTheme(theme.cursorTheme);
        root.cursorSize = root.normalizedBoundedInt(theme.cursorSize, 24, 12, 128);
        root.cursorHideWhenTyping = typeof theme.cursorHideWhenTyping === "boolean" ? theme.cursorHideWhenTyping : false;
        root.cursorHideAfterInactiveMs = root.normalizedBoundedInt(theme.cursorHideAfterInactiveMs, 0, 0, 5000);
        root.iconTheme = theme.iconTheme || "";
        Fonts.setConfiguredFamilies(fonts.ui, fonts.mono, fonts.numeric, fonts.expressive);
        root.shellBackgroundOpacity = normalizedBoundedReal(effects.shellBackgroundOpacity, 1, 0, 1);
        root.shellBlurEnabled = typeof effects.shellBlurEnabled === "boolean" ? effects.shellBlurEnabled : false;
        root.shellBlurXray = typeof effects.shellBlurXray === "boolean" ? effects.shellBlurXray : true;
        root.keystoneStyle = normalizedOption(root.keystoneStyles, keystone.style, "bangs");
        root.keystonePosition = normalizedEdgePosition(keystone.position);
        root.keystoneHideDate = typeof keystone.hideDate === "boolean" ? keystone.hideDate : false;
        root.horizontalClockFontSize = root.normalizedBoundedInt(horizontalClock.fontSize, 22, 16, 28);
        root.horizontalClockAxes = root.normalizedHorizontalClockAxes(horizontalClock.axes);
        root.horizontalClockDigits = root.normalizedHorizontalClockDigits(horizontalClock.digits);
        root.barPosition = normalizedEdgePosition(bar.position);
        const hasBarLayout = Array.isArray(bar.barLeadingComponents) || Array.isArray(bar.barTrailingComponents);
        const barLayout = root.normalizedBarLayout(bar.barLeadingComponents, bar.barTrailingComponents, !hasBarLayout);
        root.barLeadingComponents = barLayout.leading;
        root.barTrailingComponents = barLayout.trailing;
        root.quickSettingsComponents = root.normalizedQuickSettingsComponents(bar.quickSettingsComponents);
        root.keepSidebarsLoaded = sidebar.keepLoaded === undefined ? true : !!sidebar.keepLoaded;
    }

    function needsScrollingMigration(parsed) {
        return !!(parsed && parsed.interactions !== undefined);
    }

    function needsWallpaperMigration(parsed) {
        const wallpaper = parsed && parsed.wallpaper;
        if (!wallpaper || typeof wallpaper !== "object")
            return true;

        return wallpaper.desktopBackend === undefined || wallpaper.awww === undefined || wallpaper.overview === undefined || wallpaper.parallax === undefined;
    }

    function needsEffectsMigration(parsed) {
        const effects = parsed && parsed.effects;
        if (!effects || typeof effects !== "object" || Array.isArray(effects))
            return true;

        return effects.shellBackgroundOpacity === undefined || effects.shellBlurEnabled === undefined || effects.shellBlurXray === undefined;
    }

    function needsThemeMigration(parsed) {
        const theme = parsed && parsed.theme;
        return !theme || typeof theme !== "object" || Array.isArray(theme) || theme.matugenTemplates === undefined || theme.fonts === undefined;
    }

    function needsEdgePositionMigration(parsed) {
        const bar = parsed && parsed.bar;
        const keystone = parsed && parsed.keystone;
        return !bar || typeof bar !== "object" || Array.isArray(bar) || bar.position !== root.normalizedEdgePosition(bar.position) || !keystone || typeof keystone !== "object" || Array.isArray(keystone) || keystone.position !== root.normalizedEdgePosition(keystone.position);
    }

    function save() {
        if (!root.storeReady || root.loading)
            return ;

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
            let parsed = {
            };
            root.loading = true;
            try {
                parsed = JSON.parse(configFile.text().trim() || "{}");
                shouldRepair = root.needsWallpaperMigration(parsed) || root.needsEffectsMigration(parsed) || root.needsThemeMigration(parsed) || root.needsEdgePositionMigration(parsed) || root.needsScrollingMigration(parsed);
                root.loadFromObject(parsed);
                shouldRepair = shouldRepair || JSON.stringify(parsed.wallpaper || {
                }) !== JSON.stringify(root.toJson().wallpaper) || JSON.stringify(parsed.effects || {
                }) !== JSON.stringify(root.toJson().effects) || JSON.stringify(parsed.theme || {
                }) !== JSON.stringify(root.toJson().theme) || JSON.stringify(parsed.bar || {
                }) !== JSON.stringify(root.toJson().bar) || JSON.stringify(parsed.keystone || {
                }) !== JSON.stringify(root.toJson().keystone);
            } catch (error) {
                console.warn("PersonalizationConfig failed to load:", error);
                shouldRepair = true;
            }
            root.loading = false;
            root.loaded = true;
            root.settingsLoaded();
            if (shouldRepair)
                root.save();

        }
        onLoadFailed: {
            root.loading = true;
            root.loadFromObject({
            });
            root.loading = false;
            root.loaded = true;
            root.settingsLoaded();
            root.save();
        }
    }

}
