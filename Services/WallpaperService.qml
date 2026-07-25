pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property bool scanning: false
    property bool switching: false
    property bool primaryInstance: false
    property var wallpapers: []
    property string currentWallpaper: PersonalizationConfig.wallpaperPath
    property int revision: 0
    property int settingsRevision: 0
    property string pendingCycleAction: ""
    property bool pendingCycleFromIpc: false

    readonly property bool busy: scanning || switching || ThemeService.generating
    readonly property var imageExtensions: ["jpg", "jpeg", "png", "webp", "bmp", "gif"]

    function basename(path) {
        if (!path)
            return "";
        const value = String(path);
        if (root.isColorSource(value))
            return "纯色壁纸 " + value;
        return value.substring(value.lastIndexOf("/") + 1);
    }

    function parentFolder(path) {
        if (!path || path.indexOf("/") === -1)
            return "";
        return path.substring(0, path.lastIndexOf("/"));
    }

    function isColorSource(value) {
        return /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(String(value || ""));
    }

    function isImagePath(path) {
        const lower = String(path || "").toLowerCase();
        for (let i = 0; i < root.imageExtensions.length; i += 1) {
            if (lower.endsWith("." + root.imageExtensions[i]))
                return true;
        }
        return false;
    }

    function fillModeForScreen(screenName) {
        return PersonalizationConfig.perMonitorWallpaper ? PersonalizationConfig.monitorFillMode(screenName) : PersonalizationConfig.wallpaperFillMode;
    }

    function qtFillMode(modeName) {
        switch (modeName) {
        case "Stretch":
            return Image.Stretch;
        case "Fit":
        case "PreserveAspectFit":
            return Image.PreserveAspectFit;
        case "Fill":
        case "PreserveAspectCrop":
            return Image.PreserveAspectCrop;
        case "Tile":
            return Image.Tile;
        case "TileVertically":
            return Image.TileVertically;
        case "TileHorizontally":
            return Image.TileHorizontally;
        case "Pad":
            return Image.Pad;
        default:
            return Image.PreserveAspectCrop;
        }
    }

    function shaderFillMode(modeName) {
        switch (modeName) {
        case "Stretch":
            return 0;
        case "Fit":
        case "PreserveAspectFit":
            return 1;
        case "Fill":
        case "PreserveAspectCrop":
            return 2;
        case "Tile":
            return 3;
        case "TileVertically":
            return 4;
        case "TileHorizontally":
            return 5;
        case "Pad":
            return 6;
        default:
            return 2;
        }
    }

    function wallpaperForScreen(screenName) {
        let path = "";
        if (PersonalizationConfig.perMonitorWallpaper)
            path = PersonalizationConfig.monitorWallpaper(screenName);

        if (!path && PersonalizationConfig.perModeWallpaper)
            path = UiPreferences.darkMode ? PersonalizationConfig.wallpaperPathDark : PersonalizationConfig.wallpaperPathLight;

        if (!path)
            path = PersonalizationConfig.wallpaperPath;

        return path || "";
    }

    function forwardIpc(args) {
        if (root.primaryInstance || !args || args.length === 0)
            return;

        const command = ["quickshell", "ipc", "call", "wallpaper"];
        for (let i = 0; i < args.length; i += 1)
            command.push(String(args[i]));
        Quickshell.execDetached(command);
    }

    function scan() {
        if (scanProcess.running)
            return;

        root.wallpapers = [];
        scanProcess.command = [
            "find", PersonalizationConfig.wallpaperFolder,
            "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", "-o", "-iname", "*.gif", ")",
            "-print"
        ];
        scanProcess.running = false;
        scanProcess.running = true;
    }

    function rememberWallpaper(path) {
        if (!root.isImagePath(path) || root.wallpapers.indexOf(path) !== -1)
            return;

        const next = root.wallpapers.concat([path]);
        root.wallpapers = next.slice().sort();
    }

    function setWallpaper(path, screenName, fromIpc) {
        if (!path || path === "" || (!root.isImagePath(path) && !root.isColorSource(path)))
            return false;

        if (PersonalizationConfig.perMonitorWallpaper && screenName)
            PersonalizationConfig.setMonitorWallpaper(screenName, path);
        else if (PersonalizationConfig.perModeWallpaper)
            PersonalizationConfig.setWallpaperPathForMode(UiPreferences.darkMode ? "dark" : "light", path);
        else
            PersonalizationConfig.setWallpaperPath(path);

        root.currentWallpaper = path;
        root.rememberWallpaper(path);
        Appearance.currentWallpaperPreview = root.isColorSource(path) ? path : Paths.fileUrl(path);
        root.revision += 1;
        root.switching = true;

        if (root.isImagePath(path))
            ThemeService.generateFromWallpaper(path);
        else if (root.isColorSource(path))
            ThemeService.generateFromColor(path);
        else
            root.switching = false;

        if (!fromIpc)
            root.forwardIpc(["set", path, screenName || ""]);
        return true;
    }

    function clearWallpaper(screenName, fromIpc) {
        if (PersonalizationConfig.perMonitorWallpaper && screenName)
            PersonalizationConfig.setMonitorWallpaper(screenName, "");
        else if (PersonalizationConfig.perModeWallpaper)
            PersonalizationConfig.setWallpaperPathForMode(UiPreferences.darkMode ? "dark" : "light", "");
        else
            PersonalizationConfig.setWallpaperPath("");

        root.currentWallpaper = root.wallpaperForScreen("");
        Appearance.currentWallpaperPreview = "";
        root.revision += 1;
        root.switching = false;

        if (!fromIpc)
            root.forwardIpc(["clear", screenName || ""]);
        return true;
    }

    function setWallpaperFolder(path, fromIpc) {
        PersonalizationConfig.setWallpaperFolder(path || Paths.homeDir + "/.config/wallpaper");
        root.scan();
        if (!fromIpc)
            root.forwardIpc(["setFolder", PersonalizationConfig.wallpaperFolder]);
        return true;
    }

    function setWallpaperFillMode(value) {
        PersonalizationConfig.setWallpaperFillMode(value);
        return true;
    }

    function setWallpaperTransitionType(value) {
        PersonalizationConfig.setWallpaperTransitionType(value);
        return true;
    }

    function setTransitionDurationMs(value) {
        PersonalizationConfig.setTransitionDurationMs(value);
        return true;
    }

    function setTransitionEasingMode(value) {
        PersonalizationConfig.setTransitionEasingMode(value);
        return true;
    }

    function setTransitionBezierCurve(value) {
        PersonalizationConfig.setTransitionBezierCurve(value);
        return true;
    }

    function cycle(action, fromIpc) {
        if (root.wallpapers.length === 0) {
            root.pendingCycleAction = action;
            root.pendingCycleFromIpc = !!fromIpc;
            root.scan();
            return false;
        }

        return root.applyCycle(action, fromIpc);
    }

    function applyCycle(action, fromIpc) {
        if (root.wallpapers.length === 0)
            return false;

        const current = root.currentWallpaper || root.wallpaperForScreen("");
        let index = root.wallpapers.indexOf(current);
        let nextIndex = 0;

        if (action === "previous") {
            nextIndex = index >= 0 ? (index - 1 + root.wallpapers.length) % root.wallpapers.length : root.wallpapers.length - 1;
        } else if (action === "random") {
            if (root.wallpapers.length === 1) {
                nextIndex = 0;
            } else {
                do {
                    nextIndex = Math.floor(Math.random() * root.wallpapers.length);
                } while (nextIndex === index);
            }
        } else {
            nextIndex = index >= 0 ? (index + 1) % root.wallpapers.length : 0;
        }

        return root.setWallpaper(root.wallpapers[nextIndex], "", fromIpc);
    }

    function cycleNext(fromIpc) {
        const applied = root.cycle("next", !!fromIpc || !root.primaryInstance);
        if (!fromIpc)
            root.forwardIpc(["next"]);
        return applied;
    }

    function cyclePrevious(fromIpc) {
        const applied = root.cycle("previous", !!fromIpc || !root.primaryInstance);
        if (!fromIpc)
            root.forwardIpc(["previous"]);
        return applied;
    }

    function cycleRandom(fromIpc) {
        const applied = root.cycle("random", !!fromIpc || !root.primaryInstance);
        if (!fromIpc)
            root.forwardIpc(["random"]);
        return applied;
    }

    function refreshFromConfig() {
        root.currentWallpaper = root.wallpaperForScreen("");
        root.revision += 1;
    }

    function refreshSettingsFromConfig() {
        root.settingsRevision += 1;
    }

    Component.onCompleted: {
        root.refreshFromConfig();
        root.scan();
    }

    Connections {
        target: PersonalizationConfig

        function onWallpaperFolderChanged() {
            root.scan();
        }

        function onWallpaperPathChanged() {
            root.refreshFromConfig();
        }

        function onWallpaperPathLightChanged() {
            root.refreshFromConfig();
        }

        function onWallpaperPathDarkChanged() {
            root.refreshFromConfig();
        }

        function onPerModeWallpaperChanged() {
            root.refreshFromConfig();
        }

        function onPerMonitorWallpaperChanged() {
            root.refreshFromConfig();
            root.refreshSettingsFromConfig();
        }

        function onMonitorWallpapersChanged() {
            root.refreshFromConfig();
        }

        function onWallpaperFillModeChanged() {
            root.refreshSettingsFromConfig();
        }

        function onMonitorWallpaperFillModesChanged() {
            root.refreshSettingsFromConfig();
        }

        function onWallpaperTransitionTypeChanged() {
            root.refreshSettingsFromConfig();
        }

        function onIncludedTransitionsChanged() {
            root.refreshSettingsFromConfig();
        }

        function onTransitionDurationMsChanged() {
            root.refreshSettingsFromConfig();
        }

        function onTransitionEasingModeChanged() {
            root.refreshSettingsFromConfig();
        }

        function onTransitionBezierCurveChanged() {
            root.refreshSettingsFromConfig();
        }
    }

    Connections {
        target: UiPreferences

        function onDarkModeChanged() {
            if (PersonalizationConfig.perModeWallpaper)
                root.refreshFromConfig();
        }
    }

    Connections {
        target: ThemeService

        function onGeneratingChanged() {
            if (!ThemeService.generating)
                root.switching = false;
        }
    }

    Timer {
        id: cycleTimer
        interval: Math.max(5, PersonalizationConfig.autoCycleInterval) * 1000
        repeat: true
        running: root.primaryInstance && PersonalizationConfig.autoCycleEnabled && PersonalizationConfig.autoCycleMode === "interval"
        onTriggered: root.cycleNext()
    }

    Timer {
        id: dailyTimer
        interval: 30000
        repeat: true
        running: root.primaryInstance && PersonalizationConfig.autoCycleEnabled && PersonalizationConfig.autoCycleMode === "time"
        property string lastTriggered: ""
        onTriggered: {
            const now = new Date();
            const stamp = now.toISOString().slice(0, 10) + " " + PersonalizationConfig.autoCycleTime;
            const current = ("0" + now.getHours()).slice(-2) + ":" + ("0" + now.getMinutes()).slice(-2);
            if (current === PersonalizationConfig.autoCycleTime && lastTriggered !== stamp) {
                lastTriggered = stamp;
                root.cycleNext();
            }
        }
    }

    Process {
        id: scanProcess
        onRunningChanged: if (running) root.scanning = true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: file => {
                const path = file.trim();
                if (path !== "")
                    root.wallpapers = root.wallpapers.concat([path]);
            }
        }
        onExited: {
            root.scanning = false;
            const sorted = root.wallpapers.slice().sort();
            const unique = [];
            for (let i = 0; i < sorted.length; i += 1) {
                if (i === 0 || sorted[i] !== sorted[i - 1])
                    unique.push(sorted[i]);
            }
            root.wallpapers = unique;
            if (root.pendingCycleAction !== "" && root.wallpapers.length > 0) {
                const action = root.pendingCycleAction;
                const fromIpc = root.pendingCycleFromIpc;
                root.pendingCycleAction = "";
                root.pendingCycleFromIpc = false;
                root.applyCycle(action, fromIpc);
            }
        }
    }

}
