.pragma library

Qt.include("../../../SystemCards/SystemCardGeometry.js");
Qt.include("../../../SystemCards/SystemCardGrid.js");

var canvasWidth = 472;
var schemaVersion = 8;

function idsFor(activeIds) {
    var requested = Array.isArray(activeIds) ? activeIds : ids();
    return ids().filter(function(id) { return requested.indexOf(id) !== -1; });
}

function definitions(activeIds) { return sidebarDefinitions(idsFor(activeIds)); }
function tileDefinitionFor(id) { return definitionFor(String(id)); }
function placementFor(layout, id) {
    return (Array.isArray(layout) ? layout : []).find(function(tile) { return tile.id === id; }) || null;
}
function tileAt(id, point) {
    var size = sizeFor(id);
    return {id: id, x: point.x, y: point.y, width: size.width, height: size.height};
}
function clampAnchor(definition, x, y) {
    return {x: gridSnap(x, canvasWidth - widthFor(definition.id)),
        y: gridSnap(y, Number.MAX_SAFE_INTEGER)};
}
function withinBounds(tile) {
    return Number.isFinite(tile.x) && Number.isFinite(tile.y)
        && tile.x >= 0 && tile.y >= 0 && tile.x % cardGridStep === 0
        && tile.y % cardGridStep === 0 && tile.x + tile.width <= canvasWidth;
}
function validateLayout(layout, activeIds) {
    var expected = idsFor(activeIds);
    if (!Array.isArray(layout) || layout.length !== expected.length)
        return false;
    var seen = {};
    for (var i = 0; i < layout.length; i += 1) {
        var tile = layout[i];
        if (!tile || expected.indexOf(tile.id) === -1 || seen[tile.id]
                || tile.width !== widthFor(tile.id) || tile.height !== heightFor(tile.id)
                || !withinBounds(tile))
            return false;
        for (var j = 0; j < i; j += 1) {
            if (gridOverlaps(tile, layout[j], cellGap))
                return false;
        }
        seen[tile.id] = true;
    }
    return true;
}
function contentHeight(layout, activeIds) {
    var allowed = idsFor(activeIds);
    return (Array.isArray(layout) ? layout : []).reduce(function(bottom, tile) {
        return allowed.indexOf(tile.id) === -1 ? bottom : Math.max(bottom, tile.y + tile.height);
    }, baseCellHeight);
}
function place(id, anchor, occupied) {
    var fallback = defaultAnchorFor(id);
    var point = clampAnchor(tileDefinitionFor(id),
        anchor ? anchor.x : fallback.column * (baseCellWidth + cellGap),
        anchor ? anchor.y : fallback.row * (baseCellHeight + cellGap));
    var card = tileAt(id, point);
    var bottom = occupied.reduce(function(value, tile) { return Math.max(value, tile.y + tile.height); }, point.y);
    return gridNearestFree(card, occupied, canvasWidth, bottom + cellGap + card.height,
        cellGap, cardGridStep);
}
function buildLayout(activeIds, savedAnchors, preferredAnchors) {
    var expected = idsFor(activeIds);
    var occupied = [];
    // Reserve all persisted positions before placing returning or new cards.
    // A newly enabled earlier catalog entry must not displace a saved card.
    expected.forEach(function(id) {
        if (savedAnchors[id])
            occupied.push(tileAt(id, savedAnchors[id]));
    });
    expected.filter(function(id) { return !savedAnchors[id]; }).sort(function(a, b) {
        return Number(!!(preferredAnchors && preferredAnchors[b]))
            - Number(!!(preferredAnchors && preferredAnchors[a])) || expected.indexOf(a) - expected.indexOf(b);
    }).forEach(function(id) {
        occupied.push(place(id, preferredAnchors && preferredAnchors[id], occupied));
    });
    return expected.map(function(id) { return placementFor(occupied, id); });
}
function defaultLayout(activeIds, preferredAnchors) {
    return buildLayout(activeIds, {}, preferredAnchors);
}
function hydrateSaved(savedLayout, activeIds, preferredAnchors) {
    var expected = idsFor(activeIds);
    var version = savedLayout && Number(savedLayout.version);
    if ([6, 7, 8].indexOf(version) === -1 || !Array.isArray(savedLayout.tiles))
        return defaultLayout(expected, preferredAnchors);
    var anchors = {};
    var seen = {};
    var occupied = [];
    for (var i = 0; i < savedLayout.tiles.length; i += 1) {
        var saved = savedLayout.tiles[i];
        if (!saved || !tileDefinitionFor(saved.id) || seen[saved.id])
            return defaultLayout(expected, preferredAnchors);
        seen[saved.id] = true;
        if (version < 8 && (!Number.isInteger(saved.column) || !Number.isInteger(saved.row)))
            return defaultLayout(expected, preferredAnchors);
        var point = version === 8 ? {x: saved.x, y: saved.y}
            : {x: saved.column * 160, y: saved.row * 168};
        var tile = tileAt(saved.id, point);
        if (!withinBounds(tile))
            return defaultLayout(expected, preferredAnchors);
        if (expected.indexOf(saved.id) === -1)
            continue;
        if (occupied.some(function(other) { return gridOverlaps(tile, other, cellGap); }))
            return defaultLayout(expected, preferredAnchors);
        occupied.push(tile);
        anchors[saved.id] = point;
    }
    return buildLayout(expected, anchors, preferredAnchors);
}
function serializeLayout(layout, activeIds) {
    var expected = idsFor(activeIds);
    var source = validateLayout(layout, expected) ? layout : defaultLayout(expected);
    return {version: schemaVersion, tiles: expected.map(function(id) {
        var tile = placementFor(source, id);
        return {id: id, x: tile.x, y: tile.y};
    })};
}
function moveLayout(layout, tileId, targetX, targetY, activeIds) {
    var expected = idsFor(activeIds || (layout || []).map(function(tile) { return tile.id; }));
    if (!validateLayout(layout, expected) || expected.indexOf(tileId) === -1)
        return null;
    var moving = tileAt(tileId, clampAnchor(tileDefinitionFor(tileId), targetX, targetY));
    var occupied = [moving];
    var remaining = layout.filter(function(tile) { return tile.id !== tileId; });
    // Unaffected cards keep their positions. Only colliding cards need a slot.
    var displaced = [];
    remaining.forEach(function(tile) {
        if (gridOverlaps(tile, moving, cellGap))
            displaced.push(tile);
        else
            occupied.push(tileAt(tile.id, tile));
    });
    displaced.sort(function(a, b) { return b.width * b.height - a.width * a.height || expected.indexOf(a.id) - expected.indexOf(b.id); });
    displaced.forEach(function(tile) { occupied.push(place(tile.id, tile, occupied)); });
    return expected.map(function(id) { return placementFor(occupied, id); });
}
