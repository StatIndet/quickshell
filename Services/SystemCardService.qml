pragma Singleton
import QtQuick
import Quickshell
import qs.Services
import "../Modules/SystemCards/SystemCardCatalog.js" as Catalog
import "../Modules/SystemCards/SystemCardGeometry.js" as Geometry
import "../Modules/SystemCards/SystemCardState.js" as CardState

Singleton {
    id: root

    readonly property int schemaVersion: CardState.schemaVersion
    readonly property var cardDefinitions: Catalog.all()
    readonly property var cardIds: Catalog.ids()
    readonly property var state: CardState.normalize(internalState)
    readonly property var cards: state.cards
    readonly property var sidebarCardIds: CardState.activeSidebarIds(state)
    readonly property var desktopCardIds: CardState.activeDesktopIds(state)
    readonly property string globalDesktopLayoutMode: state.globalDesktopLayoutMode
    property bool preferencesLoaded: false
    property var sidebarForegroundOwners: ({})
    property int desktopLayoutRevision: 0
    property var internalState: CardState.defaultState()

    signal cardStateChanged(string cardId)
    signal desktopLayoutRequested()

    function card(cardId) {
        return root.cards[String(cardId)] || null;
    }

    function cardName(cardId) {
        return Catalog.nameFor(String(cardId));
    }

    function cardIcon(cardId) {
        const definition = Catalog.definitionFor(String(cardId));
        return definition ? definition.icon : "widgets";
    }

    function requiresSystemMonitor(cardId) {
        const definition = Catalog.definitionFor(String(cardId));
        return !!definition && (definition.monitorModules || []).length > 0;
    }

    function monitorModules(cardId) {
        const definition = Catalog.definitionFor(String(cardId));
        return definition ? (definition.monitorModules || []).slice() : [];
    }

    function cardExcludesHostBlur(cardId) {
        const definition = Catalog.definitionFor(String(cardId));
        return !!definition && definition.excludeHostBlur === true;
    }

    function isFreeLayoutMode(mode) {
        return CardState.isFreeMode(mode);
    }

    function isScreenLayoutMode(mode) {
        return CardState.isScreenLayoutMode(mode);
    }

    function isWallpaperLayoutMode(mode) {
        return CardState.isWallpaperLayoutMode(mode);
    }

    function cardSize(cardId) {
        return Geometry.sizeFor(String(cardId));
    }

    function persist(nextState) {
        UiPreferences.setSystemCards(CardState.serialize(nextState));
    }

    function commit(nextState, changedId, requestLayout) {
        const normalized = CardState.normalize(nextState);
        if (JSON.stringify(normalized) === JSON.stringify(root.internalState))
            return false;

        root.internalState = normalized;
        root.desktopLayoutRevision += 1;
        root.persist(normalized);
        if (changedId)
            root.cardStateChanged(String(changedId));

        root.syncMonitorOwnership();
        if (requestLayout)
            root.desktopLayoutRequested();

        return true;
    }

    function setCardEnabled(cardId, enabled) {
        return root.commit(CardState.setEnabled(root.internalState, String(cardId), enabled), cardId, false);
    }

    function setContainer(cardId, container, screenName, xNorm, yNorm, placementSpace) {
        const id = String(cardId);
        const next = CardState.setContainer(root.internalState, id, container, screenName, xNorm, yNorm, placementSpace);
        const committed = root.commit(next, id, container === "desktop");
        return committed;
    }

    function setDesktopScreenPosition(cardId, xNorm, yNorm, requestLayout) {
        return root.commit(CardState.setDesktopScreenPosition(root.internalState, String(cardId), xNorm, yNorm), cardId, !!requestLayout);
    }

    function setDesktopWallpaperPosition(cardId, xNorm, yNorm) {
        return root.commit(CardState.setDesktopWallpaperPosition(root.internalState, String(cardId), xNorm, yNorm), cardId, false);
    }

    function setPlacementSpace(cardId, placementSpace) {
        return root.commit(CardState.setPlacementSpace(root.internalState, String(cardId), placementSpace), cardId, false);
    }

    function setDesktopScreenPositions(positions, requestLayout) {
        if (!Array.isArray(positions))
            return false;

        const next = CardState.setDesktopScreenPositions(root.internalState, positions);
        return root.commit(next, "", !!requestLayout);
    }

    // Commit a Sidebar -> Desktop transfer together with the collision result
    // in one state transaction.  The transferred card remains the requested
    // drop point; collision resolution only moves the other cards.
    function transferToDesktop(cardId, screenName, xNorm, yNorm, positions, requestLayout) {
        const id = String(cardId);
        let next = CardState.setContainer(root.internalState, id, "desktop", String(screenName || ""), xNorm, yNorm, "screen");
        const batch = Array.isArray(positions) ? positions.slice() : [];
        let hasTransferredPosition = false;
        batch.forEach(function(position) {
            if (position && String(position.id) === id)
                hasTransferredPosition = true;

        });
        if (!hasTransferredPosition)
            batch.push({
            "id": id,
            "xNorm": xNorm,
            "yNorm": yNorm
        });

        next = CardState.setDesktopScreenPositions(next, batch);
        const committed = root.commit(next, id, !!requestLayout);
        return committed;
    }

    function requestDesktopLayout() {
        if (CardState.isAutomaticMode(root.globalDesktopLayoutMode))
            root.desktopLayoutRequested();

    }

    function setSidebarAnchor(cardId, column, row) {
        return root.commit(CardState.setSidebarAnchor(root.internalState, String(cardId), column, row), cardId, false);
    }

    function setSidebarLayout(layout) {
        if (!Array.isArray(layout))
            return false;

        let next = CardState.normalize(root.internalState);
        let changed = false;
        layout.forEach(function(tile) {
            if (!tile || typeof tile.id !== "string" || !next.cards[tile.id])
                return ;

            const current = next.cards[tile.id].sidebar;
            const column = Math.max(0, Math.round(Number(tile.column) || 0));
            const row = Math.max(0, Math.round(Number(tile.row) || 0));
            if (current.column !== column || current.row !== row) {
                next = CardState.setSidebarAnchor(next, tile.id, column, row);
                changed = true;
            }
        });
        return changed && root.commit(next, "", false);
    }

    function setGlobalDesktopLayoutMode(mode) {
        const next = CardState.setGlobalMode(root.internalState, mode);
        return root.commit(next, "", true);
    }

    function applyDesktopScreenLayout(placements) {
        return root.setDesktopScreenPositions(placements, false);
    }

    function applyDesktopLayout(placements) {
        if (!Array.isArray(placements))
            return false;

        let next = CardState.normalize(root.internalState);
        let changed = false;
        placements.forEach(function(placement) {
            if (!placement || typeof placement.id !== "string")
                return ;

            const current = next.cards[placement.id];
            if (!current || current.container !== "desktop")
                return ;

            const x = Math.max(0, Math.min(1, Number(placement.xNorm)));
            const y = Math.max(0, Math.min(1, Number(placement.yNorm)));
            if (!isFinite(x) || !isFinite(y))
                return ;

            if (Math.abs(current.desktop.wallpaper.xNorm - x) > 1e-05 || Math.abs(current.desktop.wallpaper.yNorm - y) > 1e-05) {
                next = CardState.setDesktopWallpaperPosition(next, placement.id, x, y);
                changed = true;
            }
        });
        return changed && root.commit(next, "", false);
    }

    function desktopIdsForScreen(screenName, screenNames) {
        return CardState.desktopIdsForScreen(root.state, String(screenName || ""), screenNames || []);
    }

    function resolvedScreenName(cardId, screenNames) {
        return CardState.resolvedScreenName(root.state, String(cardId), screenNames || []);
    }

    function sidebarAnchor(cardId) {
        const current = root.card(cardId);
        return current && current.sidebar ? {
            "column": current.sidebar.column,
            "row": current.sidebar.row
        } : Catalog.defaultAnchorFor(String(cardId));
    }

    function setSidebarForeground(owner, active) {
        const key = String(owner || "default");
        const next = Object.assign({}, root.sidebarForegroundOwners);
        if (active)
            next[key] = true;
        else
            delete next[key];
        root.sidebarForegroundOwners = next;
        root.syncMonitorOwnership();
    }

    function syncMonitorOwnership() {
        const desktopModules = [];
        root.desktopCardIds.forEach(function(id) {
            root.monitorModules(id).forEach(function(module) {
                if (desktopModules.indexOf(module) < 0)
                    desktopModules.push(module);
            });
        });
        SystemMonitorService.setConsumerModules("system-cards-desktop", desktopModules);

        const sidebarModules = [];
        if (Object.keys(root.sidebarForegroundOwners).length > 0) {
            root.sidebarCardIds.forEach(function(id) {
                root.monitorModules(id).forEach(function(module) {
                    if (sidebarModules.indexOf(module) < 0)
                        sidebarModules.push(module);
                });
            });
        }
        SystemMonitorService.setConsumerModules("system-cards-sidebar", sidebarModules);
    }

    function loadPreferences() {
        if (!UiPreferences.preferencesReady || root.preferencesLoaded)
            return ;

        const raw = UiPreferences.systemCards;
        root.internalState = CardState.normalize(raw);
        root.preferencesLoaded = true;
        // Missing systemCards is the legacy state: all cards remain in
        // the sidebar and are written as a new, independently versioned
        // document without touching drawerGridLayout.
        if (!raw || !raw.cards || JSON.stringify(raw) !== JSON.stringify(CardState.serialize(raw)))
            root.persist(root.internalState);

        root.syncMonitorOwnership();
    }

    Component.onCompleted: root.loadPreferences()
    Component.onDestruction: {
        SystemMonitorService.clearConsumer("system-cards-desktop");
        SystemMonitorService.clearConsumer("system-cards-sidebar");
    }

    Connections {
        function onPreferencesReadyChanged() {
            root.loadPreferences();
        }

        function onSystemCardsChanged() {
            if (!root.preferencesLoaded)
                root.loadPreferences();

        }

        target: UiPreferences
    }

}
