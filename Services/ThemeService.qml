pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import Clavis.Weather 1.0

Singleton {
    id: root

    property bool generating: false
    property string lastSource: ""
    property var availableIconThemes: [({ "label": qsTr("系统默认"), "value": "" })]
    property var availableCursorThemes: [({ "label": qsTr("系统默认"), "value": "" })]
    property string systemDefaultIconTheme: ""
    property string systemDefaultCursorTheme: ""
    property real sunriseEpoch: 0
    property real sunsetEpoch: 0

    readonly property bool followsSun:
        PersonalizationConfig.themeModePolicy === "sunrise-sunset"
    readonly property string automaticThemeSummary: {
        if (root.sunriseEpoch <= 0 || root.sunsetEpoch <= 0)
            return qsTr("等待天气服务提供日出日落时间");
        return qsTr("日出 %1 · 日落 %2 · 当前为%3模式")
            .arg(Qt.formatDateTime(new Date(root.sunriseEpoch * 1000), "HH:mm"))
            .arg(Qt.formatDateTime(new Date(root.sunsetEpoch * 1000), "HH:mm"))
            .arg(PersonalizationConfig.themeMode === "dark"
                ? qsTr("深色") : qsTr("浅色"));
    }

    readonly property string sessionDesktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP") || "").toLowerCase()
    readonly property bool isNiriSession: sessionDesktop.indexOf("niri") !== -1 || (Quickshell.env("NIRI_SOCKET") || "") !== ""

    function applyConfigToAppearance() {
        Appearance.matugenScheme = PersonalizationConfig.matugenScheme;
        Appearance.followGeneratedColors =
            PersonalizationConfig.shellFollowThemeMode;
        if (PersonalizationConfig.shellFollowThemeMode)
            Appearance.matugenMode = PersonalizationConfig.themeMode;
    }

    function syncApplicationTheme() {
        const shouldUseDark =
            PersonalizationConfig.themeMode === "dark";
        if (UiPreferences.darkMode !== shouldUseDark)
            UiPreferences.setDarkMode(shouldUseDark);
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
        const changed =
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

    function setThemeModePolicy(value) {
        if (value !== "sunrise-sunset") {
            root.setThemeMode(value);
            return;
        }
        PersonalizationConfig.setThemeModePolicy(value);
        root.evaluateAutomaticTheme(true);
    }

    function setShellFollowThemeMode(value) {
        PersonalizationConfig.setShellFollowThemeMode(value);
        root.applyConfigToAppearance();
        if (PersonalizationConfig.shellFollowThemeMode) {
            root.regenerateFromCurrentWallpaper();
            Appearance.reloadColors();
        }
    }

    function updateSunTimes() {
        let weather = WeatherPlugin.current();
        let sunrise = Number(weather.sunrise || 0);
        let sunset = Number(weather.sunset || 0);
        if ((sunrise <= 0 || sunset <= 0)
                && WeatherPlugin.dailyForecast.count() > 0) {
            weather = WeatherPlugin.dailyForecast.get(0);
            sunrise = Number(weather.sunrise || 0);
            sunset = Number(weather.sunset || 0);
        }
        root.sunriseEpoch = sunrise;
        root.sunsetEpoch = sunset;
        return sunrise > 0 && sunset > 0;
    }

    function evaluateAutomaticTheme(refreshIfMissing) {
        if (!root.followsSun)
            return;
        if (!root.updateSunTimes()) {
            if (refreshIfMissing && !WeatherPlugin.loading)
                WeatherPlugin.refresh();
            return;
        }

        const now = Math.floor(Date.now() / 1000);
        const nextMode = now >= root.sunriseEpoch && now < root.sunsetEpoch
            ? "light" : "dark";
        if (!PersonalizationConfig.setEffectiveThemeMode(nextMode))
            return;
        root.applyConfigToAppearance();
        UiPreferences.setDarkMode(nextMode === "dark");
        root.regenerateFromCurrentWallpaper();
    }

    function setCursorTheme(value) {
        PersonalizationConfig.setCursorTheme(value);
        root.applyCursorSettings();
    }

    function setCursorSize(value) {
        PersonalizationConfig.setCursorSize(value);
        root.applyCursorSettings();
    }

    function setCursorHideWhenTyping(value) {
        PersonalizationConfig.setCursorHideWhenTyping(value);
        root.applyCursorSettings();
    }

    function setCursorHideAfterInactiveMs(value) {
        PersonalizationConfig.setCursorHideAfterInactiveMs(value);
        root.applyCursorSettings();
    }

    function setIconTheme(value) {
        PersonalizationConfig.setIconTheme(value);

        const themeName = root.effectiveIconTheme();
        if (themeName !== "")
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", themeName]);
    }

    function effectiveIconTheme() {
        return PersonalizationConfig.iconTheme !== "" ? PersonalizationConfig.iconTheme : root.systemDefaultIconTheme;
    }

    function effectiveCursorTheme() {
        return PersonalizationConfig.cursorTheme !== "" ? PersonalizationConfig.cursorTheme : root.systemDefaultCursorTheme;
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function escapeKdlString(value) {
        return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
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
        return root.unique(base.concat([Paths.homeDir + "/.local/share", "/usr/local/share", "/usr/share"]));
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

    function iconThemeDetectionScript() {
        const paths = root.dataDirs().map(dir => dir + "/icons").concat([Paths.homeDir + "/.icons"]);
        const pathsArg = paths.map(path => root.shellQuote(path)).join(" ");
        return `
            printf 'SYSDEFAULT:%s\\n' "$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | sed "s/'//g" || true)"
            for dir in ${pathsArg}; do
                [ -d "$dir" ] || continue
                for theme in "$dir"/*/; do
                    [ -d "$theme" ] || continue
                    basename "$theme"
                done
            done | grep -v '^icons$' | grep -v '^default$' | grep -v '^hicolor$' | grep -v '^locolor$' | sort -u
        `;
    }

    function cursorThemeDetectionScript() {
        const paths = root.dataDirs().map(dir => dir + "/icons").concat([Paths.homeDir + "/.icons"]);
        const pathsArg = root.unique(paths).map(path => root.shellQuote(path)).join(" ");
        return `
            printf 'SYSDEFAULT:%s\\n' "$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | sed "s/'//g" || true)"
            for dir in ${pathsArg}; do
                [ -d "$dir" ] || continue
                for theme in "$dir"/*/; do
                    [ -d "$theme" ] || continue
                    [ -d "$theme/cursors" ] || continue
                    basename "$theme"
                done
            done | grep -v '^icons$' | grep -v '^default$' | sort -u
        `;
    }

    function detectAvailableThemes() {
        detectIconThemesProcess.command = ["bash", "-c", root.iconThemeDetectionScript()];
        detectCursorThemesProcess.command = ["bash", "-c", root.cursorThemeDetectionScript()];
        detectIconThemesProcess.running = false;
        detectCursorThemesProcess.running = false;
        detectIconThemesProcess.running = true;
        detectCursorThemesProcess.running = true;
    }

    function applyCursorSettings() {
        const themeName = root.effectiveCursorTheme();
        if (themeName !== "")
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", themeName]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", String(PersonalizationConfig.cursorSize)]);
        root.updateXResources();
        root.generateNiriCursorConfig();
    }

    function updateXResources() {
        const themeName = root.effectiveCursorTheme();
        if (themeName === "")
            return;

        const xresourcesPath = Paths.homeDir + "/.Xresources";
        const script = `
            xresources_file=${root.shellQuote(xresourcesPath)}
            theme_name=${root.shellQuote(themeName)}
            cursor_size=${PersonalizationConfig.cursorSize}

            [ -f "$xresources_file" ] && [ ! -w "$xresources_file" ] && exit 0

            current_theme=""
            current_size=""
            if [ -f "$xresources_file" ]; then
                current_theme=$(grep -E '^[[:space:]]*Xcursor\\.theme:' "$xresources_file" 2>/dev/null | sed 's/.*:[[:space:]]*//' | head -1)
                current_size=$(grep -E '^[[:space:]]*Xcursor\\.size:' "$xresources_file" 2>/dev/null | sed 's/.*:[[:space:]]*//' | head -1)
            fi

            [ "$current_theme" = "$theme_name" ] && [ "$current_size" = "$cursor_size" ] && exit 0

            temp_file="$xresources_file.tmp.$$"
            if [ -f "$xresources_file" ]; then
                grep -v '^[[:space:]]*Xcursor\\.theme:' "$xresources_file" | grep -v '^[[:space:]]*Xcursor\\.size:' > "$temp_file" 2>/dev/null || true
            else
                touch "$temp_file"
            fi

            printf 'Xcursor.theme: %s\\n' "$theme_name" >> "$temp_file"
            printf 'Xcursor.size: %s\\n' "$cursor_size" >> "$temp_file"
            mv "$temp_file" "$xresources_file"
            xrdb -merge "$xresources_file" 2>/dev/null || true
        `;
        Quickshell.execDetached(["bash", "-c", script]);
    }

    function generateNiriCursorConfig() {
        if (!root.isNiriSession)
            return;

        const niriDmsDir = Paths.homeDir + "/.config/niri/dms";
        const cursorPath = niriDmsDir + "/cursor.kdl";
        const themeName = root.effectiveCursorTheme();
        const size = PersonalizationConfig.cursorSize;
        const hideWhenTyping = PersonalizationConfig.cursorHideWhenTyping;
        const hideAfterMs = PersonalizationConfig.cursorHideAfterInactiveMs;
        const hasCursorConfig = themeName !== "" || size !== 24 || hideWhenTyping || hideAfterMs > 0;
        let content = "";

        if (hasCursorConfig) {
            content = `// ! DO NOT EDIT !
// ! AUTO-GENERATED BY CLAVIS !
// ! CHANGES WILL BE OVERWRITTEN !
// ! PLACE YOUR CUSTOM CONFIGURATION ELSEWHERE !

cursor {
`;
            if (themeName !== "")
                content += `    xcursor-theme "${root.escapeKdlString(themeName)}"\n`;
            content += `    xcursor-size ${size}\n`;
            if (hideWhenTyping)
                content += "    hide-when-typing\n";
            if (hideAfterMs > 0)
                content += `    hide-after-inactive-ms ${hideAfterMs}\n`;
            content += "}\n";
        }

        writeNiriCursorProcess.command = [
            "bash", "-c",
            "mkdir -p " + root.shellQuote(niriDmsDir) + " && printf '%s' " + root.shellQuote(content) + " > " + root.shellQuote(cursorPath)
        ];
        writeNiriCursorProcess.running = false;
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
        if (!PersonalizationConfig.shellFollowThemeMode)
            command.push("--skip-quickshell");
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
        if (!PersonalizationConfig.shellFollowThemeMode)
            command.push("--skip-quickshell");
        generateColorsProcess.command = command;
        generateColorsProcess.running = false;
        generateColorsProcess.running = true;
    }

    function regenerateFromCurrentWallpaper() {
        const path = WallpaperService.currentWallpaper || PersonalizationConfig.wallpaperPath;
        if (path && path !== "" && WallpaperService.isImagePath(path))
            root.generateFromWallpaper(path);
        else if (path && path !== "" && WallpaperService.isColorSource(path))
            root.generateFromColor(path);
        else
            root.generateFromColor(Appearance.m3colors.m3sourceColor);
    }

    Component.onCompleted: {
        root.applyConfigToAppearance();
        root.detectAvailableThemes();
        if (root.followsSun)
            root.evaluateAutomaticTheme(true);
        else
            root.syncApplicationTheme();
    }

    Connections {
        target: PersonalizationConfig

        function onMatugenSchemeChanged() {
            root.applyConfigToAppearance();
        }

        function onThemeModeChanged() {
            root.applyConfigToAppearance();
            root.syncApplicationTheme();
        }

        function onShellFollowThemeModeChanged() {
            root.applyConfigToAppearance();
            if (PersonalizationConfig.shellFollowThemeMode)
                Appearance.reloadColors();
        }

        function onThemeModePolicyChanged() {
            if (root.followsSun)
                root.evaluateAutomaticTheme(true);
        }
    }

    Connections {
        target: WeatherPlugin

        function onDataChanged() {
            root.evaluateAutomaticTheme(false);
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.followsSun
        triggeredOnStart: true
        onTriggered: root.evaluateAutomaticTheme(false)
    }

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
