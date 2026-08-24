.pragma library

// QML JavaScript files cannot use ES-module imports from another JS file.
// Include the catalog here so CardState and DrawerGridLayout still consume
// the same metadata source when they are run directly by qmltestrunner.
Qt.include("SystemCardCatalog.js");
Qt.include("SystemCardPlacement.js");

var schemaVersion = 3;
var placementSpaces = ["screen", "wallpaper"];

function isObject(value) {
    return value !== null
        && typeof value === "object"
        && !Array.isArray(value);
}

function validDesktopLayoutMode(value) {
    return desktopLayoutModes.indexOf(String(value || "")) !== -1;
}

function validPlacementSpace(value) {
    return placementSpaces.indexOf(String(value || "")) !== -1;
}

function clamp01(value, fallback) {
    var number = Number(value);
    if (!isFinite(number))
        number = fallback;
    return Math.max(0, Math.min(1, number));
}

function integerOr(value, fallback) {
    var number = Number(value);
    return isFinite(number) ? Math.round(number) : fallback;
}

function coordinate(raw, fallback) {
    var source = isObject(raw) ? raw : {};
    return {
        xNorm: clamp01(source.xNorm, fallback.xNorm),
        yNorm: clamp01(source.yNorm, fallback.yNorm)
    };
}

function defaultCard(definition) {
    var anchor = defaultAnchorFor(definition.id);
    return {
        enabled: true,
        container: "sidebar",
        screenName: "",
        sidebar: {
            column: anchor.column,
            row: anchor.row
        },
        desktop: {
            placementSpace: "screen",
            screen: {
                xNorm: 0.5,
                yNorm: 0.5
            },
            wallpaper: {
                xNorm: 0.5,
                yNorm: 0.5
            }
        }
    };
}

function defaultState() {
    var state = {
        version: schemaVersion,
        globalDesktopLayoutMode: "free",
        cards: {}
    };
    all().forEach(function(definition) {
        state.cards[definition.id] = defaultCard(definition);
    });
    return state;
}

function copy(value) {
    return JSON.parse(JSON.stringify(value));
}

function normalize(raw) {
    var source = isObject(raw) ? raw : {};
    var globalMode = validDesktopLayoutMode(source.globalDesktopLayoutMode)
        ? String(source.globalDesktopLayoutMode) : "free";
    var sourceCards = isObject(source.cards) ? source.cards : {};
    var normalized = {
        version: schemaVersion,
        globalDesktopLayoutMode: globalMode,
        cards: {}
    };

    all().forEach(function(definition) {
        var fallback = defaultCard(definition);
        var rawCard = isObject(sourceCards[definition.id])
            ? sourceCards[definition.id] : {};
        var rawSidebar = isObject(rawCard.sidebar)
            ? rawCard.sidebar : {};
        var rawDesktop = isObject(rawCard.desktop)
            ? rawCard.desktop : {};

        // Versions 1/2 stored desktop.xNorm/yNorm in wallpaper space. Keep
        // that meaning during migration instead of silently interpreting old
        // values as screen coordinates. A current v3 document with missing
        // nested coordinates is treated the same way as a malformed legacy
        // desktop record and safely falls back to wallpaper space.
        var legacyWallpaper = {
            xNorm: clamp01(rawDesktop.xNorm,
                fallback.desktop.wallpaper.xNorm),
            yNorm: clamp01(rawDesktop.yNorm,
                fallback.desktop.wallpaper.yNorm)
        };
        var rawScreen = isObject(rawDesktop.screen)
            ? coordinate(rawDesktop.screen, fallback.desktop.screen)
            : { xNorm: fallback.desktop.screen.xNorm,
                yNorm: fallback.desktop.screen.yNorm };
        var rawWallpaper = isObject(rawDesktop.wallpaper)
            ? coordinate(rawDesktop.wallpaper, legacyWallpaper)
            : legacyWallpaper;
        var hasExplicitSpace = validPlacementSpace(
            rawDesktop.placementSpace);
        var space = hasExplicitSpace
            ? String(rawDesktop.placementSpace)
            : (rawCard.container === "desktop" ? "wallpaper" : "screen");

        normalized.cards[definition.id] = {
            enabled: typeof rawCard.enabled === "boolean"
                ? rawCard.enabled : fallback.enabled,
            container: rawCard.container === "desktop"
                ? "desktop" : "sidebar",
            screenName: typeof rawCard.screenName === "string"
                ? rawCard.screenName : "",
            sidebar: {
                column: Math.max(0, integerOr(
                    rawSidebar.column, fallback.sidebar.column)),
                row: Math.max(0, integerOr(
                    rawSidebar.row, fallback.sidebar.row))
            },
            desktop: {
                placementSpace: space,
                screen: rawScreen,
                wallpaper: rawWallpaper
            }
        };
    });
    return normalized;
}

function card(state, id) {
    var normalized = normalize(state);
    return normalized.cards[id] || null;
}

function updateCard(state, id, updater) {
    var normalized = normalize(state);
    if (!normalized.cards[id] || typeof updater !== "function")
        return normalized;
    var next = copy(normalized);
    var result = updater(copy(next.cards[id]));
    var cards = Object.assign({}, next.cards);
    cards[id] = result;
    next.cards[id] = normalize({
        version: schemaVersion,
        globalDesktopLayoutMode: next.globalDesktopLayoutMode,
        cards: cards
    }).cards[id];
    return next;
}

function setEnabled(state, id, enabled) {
    return updateCard(state, id, function(next) {
        next.enabled = !!enabled;
        return next;
    });
}

function setContainer(state, id, container, screenName, xNorm, yNorm,
                      placementSpace) {
    return updateCard(state, id, function(next) {
        next.container = container === "desktop" ? "desktop" : "sidebar";
        if (typeof screenName === "string")
            next.screenName = screenName;
        if (next.container !== "desktop")
            return next;

        var space = validPlacementSpace(placementSpace)
            ? String(placementSpace) : "screen";
        next.desktop.placementSpace = space;
        if (isFinite(Number(xNorm)) && isFinite(Number(yNorm))) {
            var target = space === "wallpaper"
                ? next.desktop.wallpaper : next.desktop.screen;
            target.xNorm = clamp01(xNorm, target.xNorm);
            target.yNorm = clamp01(yNorm, target.yNorm);
        }
        return next;
    });
}

function setDesktopScreenPosition(state, id, xNorm, yNorm) {
    return updateCard(state, id, function(next) {
        next.desktop.placementSpace = "screen";
        next.desktop.screen.xNorm = clamp01(
            xNorm, next.desktop.screen.xNorm);
        next.desktop.screen.yNorm = clamp01(
            yNorm, next.desktop.screen.yNorm);
        return next;
    });
}

// Apply a set of screen-space placements as one pure state operation.  The
// service persists the returned state once, after all cards have been
// normalized.  This is also used by collision resolution so intermediate
// overlapping states never become observable or durable.
function setDesktopScreenPositions(state, positions) {
    var normalized = normalize(state);
    var next = copy(normalized);
    var changed = false;
    (Array.isArray(positions) ? positions : []).forEach(function(position) {
        if (!position || typeof position.id !== "string")
            return;
        var card = next.cards[position.id];
        if (!card || card.container !== "desktop")
            return;
        var x = Number(position.xNorm);
        var y = Number(position.yNorm);
        if (!isFinite(x) || !isFinite(y))
            return;
        var nextX = clamp01(x, card.desktop.screen.xNorm);
        var nextY = clamp01(y, card.desktop.screen.yNorm);
        if (card.desktop.placementSpace !== "screen"
                || card.desktop.screen.xNorm !== nextX
                || card.desktop.screen.yNorm !== nextY) {
            card.desktop.placementSpace = "screen";
            card.desktop.screen.xNorm = nextX;
            card.desktop.screen.yNorm = nextY;
            changed = true;
        }
    });
    return changed ? normalize(next) : normalized;
}

function setDesktopWallpaperPosition(state, id, xNorm, yNorm) {
    return updateCard(state, id, function(next) {
        next.desktop.wallpaper.xNorm = clamp01(
            xNorm, next.desktop.wallpaper.xNorm);
        next.desktop.wallpaper.yNorm = clamp01(
            yNorm, next.desktop.wallpaper.yNorm);
        return next;
    });
}

function setPlacementSpace(state, id, placementSpace) {
    return updateCard(state, id, function(next) {
        if (validPlacementSpace(placementSpace))
            next.desktop.placementSpace = String(placementSpace);
        return next;
    });
}

function setSidebarAnchor(state, id, column, row) {
    return updateCard(state, id, function(next) {
        next.sidebar.column = Math.max(0, integerOr(
            column, next.sidebar.column));
        next.sidebar.row = Math.max(0, integerOr(
            row, next.sidebar.row));
        return next;
    });
}

function setGlobalMode(state, mode) {
    var normalized = normalize(state);
    if (!validDesktopLayoutMode(mode))
        return normalized;
    var next = copy(normalized);
    next.globalDesktopLayoutMode = String(mode);
    return next;
}

function activeSidebarIds(state) {
    var normalized = normalize(state);
    return ids().filter(function(id) {
        var item = normalized.cards[id];
        return item.enabled && item.container === "sidebar";
    });
}

function activeDesktopIds(state) {
    var normalized = normalize(state);
    return ids().filter(function(id) {
        var item = normalized.cards[id];
        return item.enabled && item.container === "desktop";
    });
}

function resolvedScreenName(state, id, screenNames) {
    var item = card(state, id);
    if (!item)
        return "";
    var available = (screenNames || []).map(String).sort();
    if (item.screenName !== ""
            && available.indexOf(item.screenName) !== -1)
        return item.screenName;
    return available.length > 0 ? available[0] : item.screenName;
}

function desktopIdsForScreen(state, screenName, screenNames) {
    return activeDesktopIds(state).filter(function(id) {
        return resolvedScreenName(state, id, screenNames) === screenName;
    });
}

function requiresMonitor(state, id) {
    var item = card(state, id);
    var definition = definitionFor(id);
    return !!item && item.enabled && item.container === "desktop"
        && !!definition && (definition.monitorModules || []).length > 0;
}

function serialize(state) {
    return copy(normalize(state));
}
