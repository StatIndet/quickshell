pragma Singleton
import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string configDir: Paths.configHome
    readonly property string filePath: configDir + "/ui-preferences.json"
    property bool dndEnabled: false
    property bool darkMode: false
    property string language: normalizedLanguage(Qt.locale().name)
    property string weatherTemperatureUnit: "celsius"
    property string systemTemperatureUnit: "celsius"
    property string systemMonitorGpuId: "auto"
    property string systemMonitorDiskDevice: ""
    property string storageCapacityDiskDevice: "follow-io"
    property int systemMonitorIntervalMs: 2000
    property bool useTwelveHourClock: true
    property string sidebarClockStyle: "digital"
    property int sidebarCookieSides: 14
    property bool sidebarCookieConstantlyRotate: false
    property bool sidebarCookieHourMarks: false
    property bool sidebarCookieTimeIndicators: true
    property string sidebarCookieDialStyle: "full"
    property string sidebarCookieHourHandStyle: "fill"
    property string sidebarCookieMinuteHandStyle: "medium"
    property string sidebarCookieSecondHandStyle: "dot"
    property string sidebarCookieDateStyle: "bubble"
    property bool storeReady: false
    property bool preferencesReady: false
    property bool savePending: false
    property bool systemThemeWriteQueued: false
    property bool requestedDarkMode: false
    property string systemThemeLastError: ""
    property var drawerGridLayout: ({
    })
    property var systemCards: ({
    })
    property bool cloudBackupFoldersInitialized: false
    property int cloudBackupFoldersVersion: 0
    property var cloudBackupFolders: []
    property string cloudDefaultRemoteName: ""
    property string cloudBackupRoot: "Backups"
    property string cloudUploadRoot: "Uploads"
    readonly property string defaultRecordingVideoDirectory: root.standardDirectory(StandardPaths.MoviesLocation, "Videos") + "/Recordings"
    readonly property string defaultRecordingGifDirectory: root.standardDirectory(StandardPaths.PicturesLocation, "Pictures") + "/GIFs"
    readonly property string defaultRecordingMicrophoneDirectory: root.standardDirectory(StandardPaths.MusicLocation, "Music") + "/Recordings/Microphone"
    readonly property string defaultRecordingSystemAudioDirectory: root.standardDirectory(StandardPaths.MusicLocation, "Music") + "/Recordings/System"
    property string recordingVideoDirectory: defaultRecordingVideoDirectory
    property string recordingGifDirectory: defaultRecordingGifDirectory
    property string recordingMicrophoneDirectory: defaultRecordingMicrophoneDirectory
    property string recordingSystemAudioDirectory: defaultRecordingSystemAudioDirectory

    function normalizedLanguage(value) {
        const normalized = String(value || "").replace("-", "_").toLowerCase();
        if (normalized.startsWith("en"))
            return "en_US";

        if (normalized === "zh_tw" || normalized === "zh_hk" || normalized === "zh_mo" || normalized.indexOf("hant") >= 0)
            return "zh_TW";

        return "zh_CN";
    }

    function setDndEnabled(value) {
        root.dndEnabled = value;
        root.save();
    }

    function toggleDnd() {
        root.setDndEnabled(!root.dndEnabled);
    }

    function setLanguage(value) {
        const normalized = root.normalizedLanguage(value);
        if (root.language === normalized)
            return ;

        root.language = normalized;
        root.save();
    }

    function normalizedTemperatureUnit(value) {
        return String(value || "").toLowerCase() === "fahrenheit" ? "fahrenheit" : "celsius";
    }

    function setWeatherTemperatureUnit(value) {
        const normalized = root.normalizedTemperatureUnit(value);
        if (root.weatherTemperatureUnit === normalized)
            return ;

        root.weatherTemperatureUnit = normalized;
        root.save();
    }

    function setSystemTemperatureUnit(value) {
        const normalized = root.normalizedTemperatureUnit(value);
        if (root.systemTemperatureUnit === normalized)
            return ;

        root.systemTemperatureUnit = normalized;
        root.save();
    }

    function normalizedSystemMonitorGpuId(value) {
        if (typeof value !== "string")
            return "auto";

        return value.trim() || "auto";
    }

    function setSystemMonitorGpuId(value) {
        const normalized = root.normalizedSystemMonitorGpuId(value);
        if (root.systemMonitorGpuId === normalized)
            return ;

        root.systemMonitorGpuId = normalized;
        root.save();
    }

    function normalizedDiskDevice(value, fallback) {
        const normalized = String(value || "").trim();
        return normalized === "" ? String(fallback || "") : normalized;
    }

    function setSystemMonitorDiskDevice(value) {
        const normalized = root.normalizedDiskDevice(value, "");
        if (root.systemMonitorDiskDevice === normalized)
            return ;

        root.systemMonitorDiskDevice = normalized;
        root.save();
    }

    function setStorageCapacityDiskDevice(value) {
        const normalized = root.normalizedDiskDevice(value, "follow-io");
        if (root.storageCapacityDiskDevice === normalized)
            return ;

        root.storageCapacityDiskDevice = normalized;
        root.save();
    }

    function normalizedSystemMonitorIntervalMs(value) {
        if (value === undefined || value === null || String(value).trim() === "")
            return -1;

        const numberValue = Number(value);
        if (!isFinite(numberValue))
            return -1;

        return Math.max(100, Math.min(60000, Math.round(numberValue)));
    }

    function setSystemMonitorIntervalMs(value) {
        const normalized = root.normalizedSystemMonitorIntervalMs(value);
        if (normalized < 0 || root.systemMonitorIntervalMs === normalized)
            return ;

        root.systemMonitorIntervalMs = normalized;
        root.save();
    }

    function setUseTwelveHourClock(value) {
        const enabled = !!value;
        if (root.useTwelveHourClock === enabled)
            return ;

        root.useTwelveHourClock = enabled;
        root.save();
    }

    function allowedValue(value, allowed, fallback) {
        const normalized = String(value || "");
        return allowed.indexOf(normalized) >= 0 ? normalized : fallback;
    }

    function setSidebarClockStyle(value) {
        const normalized = root.allowedValue(value, ["digital", "cookie"], "digital");
        if (root.sidebarClockStyle === normalized)
            return ;

        root.sidebarClockStyle = normalized;
        root.save();
    }

    function setSidebarCookieSides(value) {
        const normalized = Math.max(0, Math.min(40, Math.round(Number(value) || 0)));
        if (root.sidebarCookieSides === normalized)
            return ;

        root.sidebarCookieSides = normalized;
        root.save();
    }

    function setSidebarCookieConstantlyRotate(value) {
        root.sidebarCookieConstantlyRotate = !!value;
        root.save();
    }

    function setSidebarCookieHourMarks(value) {
        root.sidebarCookieHourMarks = !!value;
        root.save();
    }

    function setSidebarCookieTimeIndicators(value) {
        root.sidebarCookieTimeIndicators = !!value;
        root.save();
    }

    function setSidebarCookieDialStyle(value) {
        root.sidebarCookieDialStyle = root.allowedValue(value, ["none", "dots", "full", "numbers"], "full");
        if (root.sidebarCookieDialStyle !== "dots" && root.sidebarCookieDialStyle !== "full")
            root.sidebarCookieHourMarks = false;

        if (root.sidebarCookieDialStyle === "numbers")
            root.sidebarCookieTimeIndicators = false;

        root.save();
    }

    function setSidebarCookieHourHandStyle(value) {
        root.sidebarCookieHourHandStyle = root.allowedValue(value, ["hide", "classic", "hollow", "fill"], "fill");
        root.save();
    }

    function setSidebarCookieMinuteHandStyle(value) {
        root.sidebarCookieMinuteHandStyle = root.allowedValue(value, ["hide", "classic", "thin", "medium", "bold"], "medium");
        root.save();
    }

    function setSidebarCookieSecondHandStyle(value) {
        root.sidebarCookieSecondHandStyle = root.allowedValue(value, ["hide", "classic", "line", "dot"], "dot");
        root.save();
    }

    function setSidebarCookieDateStyle(value) {
        root.sidebarCookieDateStyle = root.allowedValue(value, ["hide", "bubble", "border", "rect"], "bubble");
        root.save();
    }

    function convertedTemperature(value, unit) {
        const numberValue = Number(value);
        if (!isFinite(numberValue))
            return NaN;

        return root.normalizedTemperatureUnit(unit) === "fahrenheit" ? numberValue * 9 / 5 + 32 : numberValue;
    }

    function weatherTemperature(value) {
        return root.convertedTemperature(value, root.weatherTemperatureUnit);
    }

    function systemTemperature(value) {
        return root.convertedTemperature(value, root.systemTemperatureUnit);
    }

    function weatherTemperatureSymbol() {
        return root.weatherTemperatureUnit === "fahrenheit" ? "°F" : "°C";
    }

    function systemTemperatureSymbol() {
        return root.systemTemperatureUnit === "fahrenheit" ? "°F" : "°C";
    }

    function shortTime(value) {
        return Qt.formatDateTime(value, root.useTwelveHourClock ? "hh:mm AP" : "HH:mm");
    }

    function hourTime(value) {
        return Qt.formatDateTime(value, root.useTwelveHourClock ? "hh AP" : "HH:00");
    }

    function setDarkMode(value) {
        const enabled = !!value;
        root.darkMode = enabled;
        root.requestedDarkMode = enabled;
        root.save();
        root.systemThemeWriteQueued = true;
        themePoller.running = false;
        root.writeSystemColorScheme();
    }

    function toggleDarkMode() {
        root.setDarkMode(!root.darkMode);
    }

    function writeSystemColorScheme() {
        if (systemThemeWriter.running) {
            root.systemThemeWriteQueued = true;
            return ;
        }
        root.systemThemeWriteQueued = false;
        root.systemThemeLastError = "";
        systemThemeWriter.command = ["bash", Paths.scriptPath("theme", "set_system_color_scheme.sh"), root.requestedDarkMode ? "dark" : "light"];
        systemThemeWriter.running = true;
    }

    function setDrawerGridLayout(layout) {
        try {
            root.drawerGridLayout = JSON.parse(JSON.stringify(layout || {
            }));
        } catch (error) {
            console.warn("UiPreferences rejected drawer grid layout:", error);
            return ;
        }
        root.save();
    }

    function setSystemCards(cards) {
        try {
            root.systemCards = JSON.parse(JSON.stringify(cards || {
            }));
        } catch (error) {
            console.warn("UiPreferences rejected system card state:", error);
            return ;
        }
        root.save();
    }

    function normalizedLocalPath(value) {
        let path = String(value || "").trim();
        if (path.startsWith("file://")) {
            try {
                path = decodeURIComponent(path.substring(7));
            } catch (error) {
                path = path.substring(7);
            }
        }
        if (!path.startsWith("/"))
            return "";

        return path === "/" ? path : path.replace(/\/+$/, "");
    }

    function standardDirectory(location, fallbackName) {
        const standardPath = root.normalizedLocalPath(StandardPaths.writableLocation(location));
        if (standardPath !== "")
            return standardPath;

        const homePath = root.normalizedLocalPath(StandardPaths.writableLocation(StandardPaths.HomeLocation));
        return homePath === "" ? "/" + fallbackName : homePath + "/" + fallbackName;
    }

    function normalizedRecordingDirectory(value, fallback) {
        const normalized = root.normalizedLocalPath(value);
        return normalized === "" ? fallback : normalized;
    }

    function setRecordingDirectory(key, value) {
        const fallbacks = {
            "recordingVideoDirectory": root.defaultRecordingVideoDirectory,
            "recordingGifDirectory": root.defaultRecordingGifDirectory,
            "recordingMicrophoneDirectory": root.defaultRecordingMicrophoneDirectory,
            "recordingSystemAudioDirectory": root.defaultRecordingSystemAudioDirectory
        };
        if (!(key in fallbacks))
            return false;

        const normalized = root.normalizedRecordingDirectory(value, fallbacks[key]);
        if (root[key] === normalized)
            return true;

        root[key] = normalized;
        root.save();
        return true;
    }

    function setCloudBackupFolders(folders) {
        const normalized = [];
        const seen = {
        };
        for (const folder of folders || []) {
            const path = root.normalizedLocalPath(folder && folder.path);
            if (path === "" || seen[path])
                continue;

            seen[path] = true;
            normalized.push({
                "path": path,
                "enabled": folder.enabled === undefined ? true : !!folder.enabled,
                "kind": String(folder && folder.kind || "custom")
            });
        }
        root.cloudBackupFolders = normalized;
        root.cloudBackupFoldersInitialized = true;
        root.cloudBackupFoldersVersion = 3;
        root.save();
    }

    function normalizedCloudRemoteName(value) {
        return String(value || "").trim().replace(/:+$/, "");
    }

    function setCloudDefaultRemoteName(value) {
        const normalized = root.normalizedCloudRemoteName(value);
        if (root.cloudDefaultRemoteName === normalized)
            return ;

        root.cloudDefaultRemoteName = normalized;
        root.save();
    }

    function normalizedCloudBackupRoot(value) {
        let normalized = String(value || "").trim().replace(/^\/+|\/+$/g, "");
        normalized = normalized.replace(/\/{2,}/g, "/");
        if (normalized === "" || normalized.indexOf(":") >= 0)
            return "Backups";

        return normalized;
    }

    function setCloudBackupRoot(value) {
        const normalized = root.normalizedCloudBackupRoot(value);
        if (root.cloudBackupRoot === normalized)
            return ;

        root.cloudBackupRoot = normalized;
        root.save();
    }

    function normalizedCloudUploadRoot(value) {
        let normalized = String(value || "").trim().replace(/^\/+|\/+$/g, "");
        normalized = normalized.replace(/\/{2,}/g, "/");
        if (normalized === "" || normalized.indexOf(":") >= 0)
            return "Uploads";

        return normalized;
    }

    function setCloudUploadRoot(value) {
        const normalized = root.normalizedCloudUploadRoot(value);
        if (root.cloudUploadRoot === normalized)
            return ;

        root.cloudUploadRoot = normalized;
        root.save();
    }

    function save() {
        if (!root.storeReady) {
            root.savePending = true;
            return ;
        }
        root.savePending = false;
        prefsFile.setText(JSON.stringify({
            "dndEnabled": root.dndEnabled,
            "language": root.language,
            "weatherTemperatureUnit": root.weatherTemperatureUnit,
            "systemTemperatureUnit": root.systemTemperatureUnit,
            "systemMonitorGpuId": root.systemMonitorGpuId,
            "systemMonitorDiskDevice": root.systemMonitorDiskDevice,
            "storageCapacityDiskDevice": root.storageCapacityDiskDevice,
            "systemMonitorIntervalMs": root.systemMonitorIntervalMs,
            "useTwelveHourClock": root.useTwelveHourClock,
            "sidebarClockStyle": root.sidebarClockStyle,
            "sidebarCookieSides": root.sidebarCookieSides,
            "sidebarCookieConstantlyRotate": root.sidebarCookieConstantlyRotate,
            "sidebarCookieHourMarks": root.sidebarCookieHourMarks,
            "sidebarCookieTimeIndicators": root.sidebarCookieTimeIndicators,
            "sidebarCookieDialStyle": root.sidebarCookieDialStyle,
            "sidebarCookieHourHandStyle": root.sidebarCookieHourHandStyle,
            "sidebarCookieMinuteHandStyle": root.sidebarCookieMinuteHandStyle,
            "sidebarCookieSecondHandStyle": root.sidebarCookieSecondHandStyle,
            "sidebarCookieDateStyle": root.sidebarCookieDateStyle,
            "drawerGridLayout": root.drawerGridLayout,
            "systemCards": root.systemCards,
            "cloudBackupFoldersInitialized": root.cloudBackupFoldersInitialized,
            "cloudBackupFoldersVersion": root.cloudBackupFoldersVersion,
            "cloudBackupFolders": root.cloudBackupFolders,
            "cloudDefaultRemoteName": root.cloudDefaultRemoteName,
            "cloudBackupRoot": root.cloudBackupRoot,
            "cloudUploadRoot": root.cloudUploadRoot,
            "recordingVideoDirectory": root.recordingVideoDirectory,
            "recordingGifDirectory": root.recordingGifDirectory,
            "recordingMicrophoneDirectory": root.recordingMicrophoneDirectory,
            "recordingSystemAudioDirectory": root.recordingSystemAudioDirectory
        }, null, 2));
    }

    Process {
        id: ensureStoreDir

        command: ["mkdir", "-p", root.configDir]
        running: true
        onExited: {
            root.storeReady = true;
            prefsFile.reload();
            if (root.savePending)
                root.save();

        }
    }

    FileView {
        id: prefsFile

        path: root.filePath
        watchChanges: true
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        onFileChanged: preferencesReloadDebounce.restart()
        onLoaded: {
            try {
                const parsed = JSON.parse(prefsFile.text().trim() || "{}");
                if (typeof parsed.dndEnabled === "boolean")
                    root.dndEnabled = parsed.dndEnabled;

                root.language = root.normalizedLanguage(parsed.language || Qt.locale().name);
                root.weatherTemperatureUnit = root.normalizedTemperatureUnit(parsed.weatherTemperatureUnit);
                root.systemTemperatureUnit = root.normalizedTemperatureUnit(parsed.systemTemperatureUnit);
                root.systemMonitorGpuId = root.normalizedSystemMonitorGpuId(parsed.systemMonitorGpuId);
                root.systemMonitorDiskDevice = root.normalizedDiskDevice(parsed.systemMonitorDiskDevice, "");
                root.storageCapacityDiskDevice = root.normalizedDiskDevice(parsed.storageCapacityDiskDevice, "follow-io");
                const monitorInterval = root.normalizedSystemMonitorIntervalMs(parsed.systemMonitorIntervalMs === undefined ? 2000 : parsed.systemMonitorIntervalMs);
                root.systemMonitorIntervalMs = monitorInterval < 0 ? 2000 : monitorInterval;
                root.useTwelveHourClock = typeof parsed.useTwelveHourClock === "boolean" ? parsed.useTwelveHourClock : true;
                root.sidebarClockStyle = root.allowedValue(parsed.sidebarClockStyle, ["digital", "cookie"], "digital");
                root.sidebarCookieSides = Math.max(0, Math.min(40, Math.round(Number(parsed.sidebarCookieSides === undefined ? 14 : parsed.sidebarCookieSides) || 0)));
                root.sidebarCookieConstantlyRotate = !!parsed.sidebarCookieConstantlyRotate;
                root.sidebarCookieHourMarks = !!parsed.sidebarCookieHourMarks;
                root.sidebarCookieTimeIndicators = parsed.sidebarCookieTimeIndicators === undefined ? true : !!parsed.sidebarCookieTimeIndicators;
                root.sidebarCookieDialStyle = root.allowedValue(parsed.sidebarCookieDialStyle, ["none", "dots", "full", "numbers"], "full");
                root.sidebarCookieHourHandStyle = root.allowedValue(parsed.sidebarCookieHourHandStyle, ["hide", "classic", "hollow", "fill"], "fill");
                root.sidebarCookieMinuteHandStyle = root.allowedValue(parsed.sidebarCookieMinuteHandStyle, ["hide", "classic", "thin", "medium", "bold"], "medium");
                root.sidebarCookieSecondHandStyle = root.allowedValue(parsed.sidebarCookieSecondHandStyle, ["hide", "classic", "line", "dot"], "dot");
                root.sidebarCookieDateStyle = root.allowedValue(parsed.sidebarCookieDateStyle, ["hide", "bubble", "border", "rect"], "bubble");
                if (root.sidebarCookieDialStyle !== "dots" && root.sidebarCookieDialStyle !== "full")
                    root.sidebarCookieHourMarks = false;

                if (root.sidebarCookieDialStyle === "numbers")
                    root.sidebarCookieTimeIndicators = false;

                if (parsed.drawerGridLayout && typeof parsed.drawerGridLayout === "object")
                    root.drawerGridLayout = parsed.drawerGridLayout;

                if (parsed.systemCards && typeof parsed.systemCards === "object" && !Array.isArray(parsed.systemCards))
                    root.systemCards = parsed.systemCards;

                root.cloudBackupFoldersInitialized = parsed.cloudBackupFoldersInitialized === true;
                root.cloudBackupFoldersVersion = Math.max(0, Math.round(Number(parsed.cloudBackupFoldersVersion) || 0));
                if (Array.isArray(parsed.cloudBackupFolders))
                    root.cloudBackupFolders = parsed.cloudBackupFolders;

                root.cloudDefaultRemoteName = root.normalizedCloudRemoteName(parsed.cloudDefaultRemoteName);
                root.cloudBackupRoot = root.normalizedCloudBackupRoot(parsed.cloudBackupRoot);
                root.cloudUploadRoot = root.normalizedCloudUploadRoot(parsed.cloudUploadRoot);
                root.recordingVideoDirectory = root.normalizedRecordingDirectory(parsed.recordingVideoDirectory, root.defaultRecordingVideoDirectory);
                root.recordingGifDirectory = root.normalizedRecordingDirectory(parsed.recordingGifDirectory, root.defaultRecordingGifDirectory);
                root.recordingMicrophoneDirectory = root.normalizedRecordingDirectory(parsed.recordingMicrophoneDirectory, root.defaultRecordingMicrophoneDirectory);
                root.recordingSystemAudioDirectory = root.normalizedRecordingDirectory(parsed.recordingSystemAudioDirectory, root.defaultRecordingSystemAudioDirectory);
            } catch (error) {
                console.warn("UiPreferences failed to load:", error);
            }
            root.preferencesReady = true;
        }
        onLoadFailed: {
            root.preferencesReady = true;
            root.save();
        }
    }

    Timer {
        id: preferencesReloadDebounce

        interval: 100
        repeat: false
        onTriggered: prefsFile.reload()
    }

    Process {
        id: themePoller

        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                if (!systemThemeWriter.running && !root.systemThemeWriteQueued)
                    root.darkMode = this.text.toLowerCase().includes("prefer-dark");

            }
        }

    }

    Process {
        id: systemThemeWriter

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.systemThemeLastError = systemThemeWriteError.text.trim() || qsTr("无法同步系统亮暗色设置");
                console.warn("UiPreferences failed to set system color scheme:", root.systemThemeLastError);
            }
            if (root.systemThemeWriteQueued) {
                root.writeSystemColorScheme();
                return ;
            }
            themeDebounce.restart();
        }

        stderr: StdioCollector {
            id: systemThemeWriteError
        }

    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!systemThemeWriter.running && !root.systemThemeWriteQueued)
                themePoller.running = true;

        }
    }

    Timer {
        id: themeDebounce

        interval: 350
        running: false
        repeat: false
        onTriggered: themePoller.running = true
    }

}
