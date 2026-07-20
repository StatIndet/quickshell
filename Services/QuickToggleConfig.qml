pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string configDir: Paths.homeDir + "/.cache/quickshell"
    readonly property string filePath: configDir + "/quick-toggles.json"

    property bool storeReady: false
    property var toggles: defaultToggles()

    function defaultToggles() {
        return [
            { "type": "network", "size": 2 },
            { "type": "bluetooth", "size": 2 },
            { "type": "caffeine", "size": 1 },
            { "type": "mic", "size": 1 },
            { "type": "audio", "size": 2 },
            { "type": "theme", "size": 2 },
            { "type": "dnd", "size": 1 }
        ];
    }

    function normalizeToggles(rawToggles) {
        if (!Array.isArray(rawToggles))
            return root.defaultToggles();

        const validTypes = root.defaultToggles().map(toggle => toggle.type);
        const seen = {};
        const normalized = [];
        for (const item of rawToggles) {
            const type = item && typeof item.type === "string" ? item.type : "";
            if (validTypes.indexOf(type) === -1 || seen[type])
                continue;

            seen[type] = true;
            normalized.push({
                "type": type,
                "size": Number(item.size) === 2 ? 2 : 1
            });
        }
        return normalized;
    }

    function indexOfType(type) {
        return root.toggles.findIndex(toggle => toggle.type === type);
    }

    function refreshBindings() {
        root.toggles = root.toggles.slice();
        root.save();
    }

    function toggleSize(type) {
        const index = root.indexOfType(type);
        if (index === -1)
            return;

        root.toggles[index].size = root.toggles[index].size === 2 ? 1 : 2;
        root.refreshBindings();
    }

    function move(type, offset) {
        const index = root.indexOfType(type);
        const target = index + offset;
        if (index === -1 || target < 0 || target >= root.toggles.length)
            return;

        const current = root.toggles[index];
        root.toggles[index] = root.toggles[target];
        root.toggles[target] = current;
        root.refreshBindings();
    }

    function save() {
        if (!root.storeReady)
            return;

        configFile.setText(JSON.stringify({
            "toggles": root.toggles
        }, null, 2));
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

    FileView {
        id: configFile
        path: root.filePath

        onLoaded: {
            try {
                const parsed = JSON.parse(configFile.text().trim() || "{}");
                root.toggles = root.normalizeToggles(parsed.toggles);
            } catch (error) {
                console.log("QuickToggleConfig failed to load:", error);
                root.toggles = root.defaultToggles();
                root.save();
            }
        }

        onLoadFailed: {
            root.toggles = root.defaultToggles();
            root.save();
        }
    }
}
