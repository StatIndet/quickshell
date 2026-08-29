pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Singleton {
    id: root

    property bool generating: false
    property string lastSource: ""
    property bool cursorIntegrationReady: false
    property bool cursorWritePending: false
    property string cursorLastError: ""
    readonly property bool cursorSyncBusy:
        cursorWritePending || writeNiriCursorProcess.running
    property var availableIconThemes: [({ "label": qsTr("系统默认"), "value": "" })]
    property var availableCursorThemes: [({ "label": qsTr("系统默认"), "value": "" })]
    property string systemDefaultIconTheme: ""
    property string systemDefaultCursorTheme: ""

    readonly property string sessionDesktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP") || "").toLowerCase()
    readonly property bool isNiriSession: sessionDesktop.indexOf("niri") !== -1 || (Quickshell.env("NIRI_SOCKET") || "") !== ""
    readonly property string niriConfigPath:
        Paths.xdgConfigHome + "/niri/config.kdl"
    readonly property string cursorConfigPath:
        Paths.xdgConfigHome + "/niri/clavis/cursor.kdl"
    readonly property string cursorConfigScript:
        Paths.scriptPath("theme", "write_niri_cursor_config.sh")
    function applyConfigToAppearance() {
        Appearance.matugenScheme = PersonalizationConfig.matugenScheme;
        Appearance.matugenMode = PersonalizationConfig.themeMode;
    }

    function setMatugenScheme(value) {
        PersonalizationConfig.setMatugenScheme(value);
        root.applyConfigToAppearance();
        root.regenerateFromCurrentWallpaper();
    }

    function enabledMatugenTemplates() {
        const enabled = [];
        for (let i = 0;
             i < PersonalizationConfig.matugenTemplateIds.length;
             i += 1) {
            const id = PersonalizationConfig.matugenTemplateIds[i];
            if (PersonalizationConfig.isMatugenTemplateEnabled(id))
                enabled.push(id);
        }
        return enabled;
    }

    function setMatugenTemplateEnabled(id, enabled) {
        let changed =
            PersonalizationConfig.setMatugenTemplateEnabled(id, enabled);
        if (changed && enabled)
            root.regenerateFromCurrentWallpaper();
    }

    function setThemeMode(value) {
        PersonalizationConfig.setThemeMode(value);
        root.applyConfigToAppearance();
        UiPreferences.setDarkMode(PersonalizationConfig.themeMode === "dark");
        root.regenerateFromCurrentWallpaper();
    }

    function setCursorTheme(value) {
        PersonalizationConfig.setCursorTheme(value);
    }

    function setCursorSize(value) {
        PersonalizationConfig.setCursorSize(value);
    }

    function setCursorHideWhenTyping(value) {
        PersonalizationConfig.setCursorHideWhenTyping(value);
    }

    function setCursorHideAfterInactiveMs(value) {
        PersonalizationConfig.setCursorHideAfterInactiveMs(value);
    }

    function setIconTheme(value) {
        PersonalizationConfig.setIconTheme(value);
    }

    function effectiveIconTheme() {
        return PersonalizationConfig.iconTheme !== "" ? PersonalizationConfig.iconTheme : root.systemDefaultIconTheme;
    }

    function effectiveCursorTheme() {
        return PersonalizationConfig.cursorTheme !== "" ? PersonalizationConfig.cursorTheme : root.systemDefaultCursorTheme;
    }

    function unique(values) {
        const result = [];
        const seen = {};
        for (let i = 0; i < values.length; i += 1) {
            const value = String(values[i] || "").trim();
            if (value === "" || seen[value])
                continue;
            seen[value] = true;
            result.push(value);
        }
        return result;
    }

    function dataDirs() {
        const raw = Quickshell.env("XDG_DATA_DIRS") || "";
        const base = raw.trim() !== "" ? raw.split(":") : ["/usr/local/share", "/usr/share"];
        return root.unique(base.concat([Paths.xdgDataHome, "/usr/local/share", "/usr/share"]));
    }

    function hasOption(options, value) {
        for (let i = 0; i < options.length; i += 1) {
            if (options[i].value === value)
                return true;
        }
        return false;
    }

    function defaultOption(label, systemDefault) {
        return {
            "label": systemDefault !== "" ? label + " · " + systemDefault : label,
            "value": ""
        };
    }

    function parseDetectedThemes(output, defaultLabel, currentValue, cursorThemes) {
        let systemDefault = "";
        const names = [];
        const lines = String(output || "").split("\n");
        for (let i = 0; i < lines.length; i += 1) {
            const line = lines[i].trim();
            if (line === "")
                continue;
            if (line.indexOf("SYSDEFAULT:") === 0) {
                systemDefault = line.substring(11).trim();
                continue;
            }
            names.push(line);
        }

        if (cursorThemes)
            root.systemDefaultCursorTheme = systemDefault;
        else
            root.systemDefaultIconTheme = systemDefault;

        const options = [root.defaultOption(defaultLabel, systemDefault)];
        const sorted = root.unique(names).sort((a, b) => a.localeCompare(b));
        for (let j = 0; j < sorted.length; j += 1)
            options.push({ "label": sorted[j], "value": sorted[j] });

        if (currentValue !== "" && !root.hasOption(options, currentValue))
            options.splice(1, 0, { "label": currentValue, "value": currentValue });

        return options;
    }

    function detectAvailableThemes() {
        const paths = root.dataDirs().map(dir => dir + "/icons")
            .concat([Paths.homeDir + "/.icons"]);
        const script = Paths.scriptPath("theme", "list_cursor_icon_themes.sh");
        detectIconThemesProcess.command = ["bash", script, "icon", ...paths];
        detectCursorThemesProcess.command = ["bash", script, "cursor", ...paths];
        detectIconThemesProcess.running = false;
        detectCursorThemesProcess.running = false;
        detectIconThemesProcess.running = true;
        detectCursorThemesProcess.running = true;
    }

    function applyCursorSettings() {
        if (!root.isNiriSession || !PersonalizationConfig.ready)
            return;
        root.generateNiriCursorConfig();
    }

    function generateNiriCursorConfig() {
        if (!root.isNiriSession || !PersonalizationConfig.ready)
            return;
        if (writeNiriCursorProcess.running) {
            root.cursorWritePending = true;
            return;
        }

        root.cursorWritePending = false;
        root.cursorLastError = "";
        writeNiriCursorProcess.command = [
            "bash",
            root.cursorConfigScript,
            root.cursorConfigPath,
            root.niriConfigPath,
            root.effectiveCursorTheme(),
            String(PersonalizationConfig.cursorSize),
            PersonalizationConfig.cursorHideWhenTyping ? "true" : "false",
            String(PersonalizationConfig.cursorHideAfterInactiveMs),
            "niri"
        ];
        writeNiriCursorProcess.running = true;
    }

    function generateFromWallpaper(path) {
        if (!path || path === "")
            return;

        root.applyConfigToAppearance();
        root.lastSource = path;
        const command = [
            "bash", Paths.scriptPath("theme", "generate_matugen_colors.sh"),
            "--image", path,
            "--scheme", PersonalizationConfig.matugenScheme,
            "--mode", PersonalizationConfig.themeMode,
            "--templates", root.enabledMatugenTemplates().join(",")
        ];
        generateColorsProcess.command = command;
        generateColorsProcess.running = false;
        generateColorsProcess.running = true;
    }

    function opaqueHexFromColor(value) {
        const color = Qt.color(value);
        const r = Math.round(Math.max(0, Math.min(1, color.r)) * 255).toString(16).padStart(2, "0");
        const g = Math.round(Math.max(0, Math.min(1, color.g)) * 255).toString(16).padStart(2, "0");
        const b = Math.round(Math.max(0, Math.min(1, color.b)) * 255).toString(16).padStart(2, "0");
        return "#" + r + g + b;
    }

    function generateFromColor(value) {
        if (!value || value === "")
            return;

        const sourceColor = root.opaqueHexFromColor(value);
        root.applyConfigToAppearance();
        root.lastSource = value;
        const command = [
            "bash", Paths.scriptPath("theme", "generate_matugen_colors.sh"),
            "--color", sourceColor,
            "--scheme", PersonalizationConfig.matugenScheme,
            "--mode", PersonalizationConfig.themeMode,
            "--templates", root.enabledMatugenTemplates().join(",")
        ];
        generateColorsProcess.command = command;
        generateColorsProcess.running = false;
        generateColorsProcess.running = true;
    }

    function regenerateFromCurrentWallpaper() {
        const path = WallpaperService.currentWallpaper
            || PersonalizationConfig.wallpaperPath;
        if (path && path !== "" && WallpaperService.isImagePath(path))
            root.generateFromWallpaper(path);
        else if (path && path !== "" && WallpaperService.isColorSource(path))
            root.generateFromColor(path);
    }

    Component.onCompleted: {
        root.applyConfigToAppearance();
        root.detectAvailableThemes();
        root.applyCursorSettings();
        if (PersonalizationConfig.themeMode === "dark" && !UiPreferences.darkMode)
            UiPreferences.setDarkMode(true);
    }

    Connections {
        target: PersonalizationConfig

        function onMatugenSchemeChanged() {
            root.applyConfigToAppearance();
        }

        function onThemeModeChanged() {
            root.applyConfigToAppearance();
        }

        function onSettingsLoaded() {
            root.applyCursorSettings();
        }

        function onCursorThemeChanged() {
            root.applyCursorSettings();
        }

        function onCursorSizeChanged() {
            root.applyCursorSettings();
        }

        function onCursorHideWhenTypingChanged() {
            root.applyCursorSettings();
        }

        function onCursorHideAfterInactiveMsChanged() {
            root.applyCursorSettings();
        }
    }

    onSystemDefaultCursorThemeChanged: root.applyCursorSettings()

    Process {
        id: detectIconThemesProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.availableIconThemes = root.parseDetectedThemes(this.text, qsTr("系统默认"), PersonalizationConfig.iconTheme, false);
            }
        }
    }

    Process {
        id: detectCursorThemesProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.availableCursorThemes = root.parseDetectedThemes(this.text, qsTr("系统默认"), PersonalizationConfig.cursorTheme, true);
            }
        }
    }

    Process {
        id: writeNiriCursorProcess

        stderr: StdioCollector {
            id: writeNiriCursorError
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.cursorIntegrationReady = true;
                root.cursorLastError = "";
                root.refreshCursorIntegrationState();
            } else {
                root.cursorLastError = writeNiriCursorError.text.trim()
                    || qsTr("无法写入 Niri 光标配置");
            }

            if (root.cursorWritePending)
                root.generateNiriCursorConfig();
        }
    }

    function includesCursorConfig(text) {
        return /(^|\n)\s*include(?:\s+optional=true)?\s+"clavis\/cursor\.kdl"\s*(?:\/\/[^\n]*)?(?:\n|$)/
            .test(String(text || ""));
    }

    function refreshCursorIntegrationState() {
        if (root.isNiriSession)
            niriConfigFile.reload();
    }

    FileView {
        id: niriConfigFile

        path: root.niriConfigPath
        blockLoading: true
        watchChanges: true

        onLoaded: root.cursorIntegrationReady =
            root.includesCursorConfig(niriConfigFile.text())
        onLoadFailed: root.cursorIntegrationReady = false
        onFileChanged: Qt.callLater(root.refreshCursorIntegrationState)
    }

    Process {
        id: generateColorsProcess
        onRunningChanged: if (running) root.generating = true
        onExited: exitCode => {
            root.generating = false;
            if (exitCode === 0)
                Appearance.reloadColors();
            else
                console.error("Matugen color generation failed with exit code", exitCode);
        }
    }
}
