pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Services
import "../Common/functions/SpotlightSearch.js" as SpotlightSearch

Singleton {
    id: root

    readonly property var searchEngines: SpotlightSearch.engines
    readonly property string searchEngineName: SpotlightSearch.engineFor(UiPreferences.spotlightSearchEngine).label
    property string pendingUrl: ""
    property var browserIds: []
    property var previousWindows: []
    property double activationDeadline: 0
    property double openedAt: 0
    property var initialActiveWindow: null

    function searchUrl(query) {
        return SpotlightSearch.searchUrl(UiPreferences.spotlightSearchEngine, query);
    }

    function normalizedId(value) {
        return String(value || "").trim().toLowerCase().replace(/\.desktop$/, "");
    }

    function cancelActivation() {
        focusTimer.stop();
        root.pendingUrl = "";
        root.browserIds = [];
        root.previousWindows = [];
        root.initialActiveWindow = null;
    }

    function openUrl(url) {
        root.cancelActivation();
        root.pendingUrl = url;
        // Query the HTTPS handler per submission, including changes made outside Clavis.
        if (!browserQuery.running) {
            browserQuery.running = true;
            queryTimeout.restart();
        }
    }

    function launchBrowser(desktopId) {
        if (root.pendingUrl === "")
            return ;

        const entry = DefaultApplicationsService.applicationForId(desktopId);
        root.browserIds = [desktopId, entry ? entry.id : "", entry ? entry.startupClass : ""].map((value) => {
            return root.normalizedId(value);
        }).filter((value) => {
            return value !== "";
        });
        root.previousWindows = ToplevelManager.toplevels.values.map((window) => {
            return ({
                "window": window,
                "title": window.title,
                "active": window.activated
            });
        });
        root.initialActiveWindow = ToplevelManager.activeToplevel;
        const url = root.pendingUrl;
        root.pendingUrl = "";
        if (!Qt.openUrlExternally(url)) {
            console.warn("Spotlight could not open the search URL");
            root.cancelActivation();
            return ;
        }
        root.openedAt = Date.now();
        root.activationDeadline = root.openedAt + 5000;
        if (root.browserIds.length > 0)
            focusTimer.restart();

    }

    function tryActivateBrowser() {
        if (Date.now() >= root.activationDeadline) {
            root.cancelActivation();
            return ;
        }
        const candidates = ToplevelManager.toplevels.values.filter((window) => {
            return root.browserIds.includes(root.normalizedId(window.appId));
        });
        if (candidates.length === 0)
            return ;

        // Respect a browser's own window selection before choosing an existing window.
        if (candidates.some((window) => {
            return window.activated;
        })) {
            root.cancelActivation();
            return ;
        }
        let target = candidates.find((window) => {
            return !root.previousWindows.some((previous) => {
                return previous.window === window && previous.title === window.title;
            });
        });
        if (!target && Date.now() - root.openedAt < 600)
            return ;

        if (!target)
            target = candidates.find((window) => {
            return root.previousWindows.some((previous) => {
                return previous.window === window && previous.active;
            });
        }) || candidates[0];

        // The timer stops on acknowledgement or at the activation deadline.
        target.activate();
    }

    Connections {
        function onActiveToplevelChanged() {
            const active = ToplevelManager.activeToplevel;
            if (focusTimer.running && active && active !== root.initialActiveWindow && !root.browserIds.includes(root.normalizedId(active.appId)))
                root.cancelActivation();

        }

        target: ToplevelManager
    }

    Process {
        id: browserQuery

        command: ["xdg-mime", "query", "default", "x-scheme-handler/https"]
        onExited: (exitCode) => {
            queryTimeout.stop();
            root.launchBrowser(exitCode === 0 ? browserOutput.text.trim() : "");
        }

        stdout: StdioCollector {
            id: browserOutput
        }

    }

    Timer {
        id: queryTimeout

        interval: 1500
        onTriggered: {
            browserQuery.running = false;
            root.launchBrowser("");
        }
    }

    Timer {
        id: focusTimer

        interval: 150
        repeat: true
        onTriggered: root.tryActivateBrowser()
    }

}
