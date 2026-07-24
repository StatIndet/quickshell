.pragma library

var columnCount = 3;
var rowCount = 7;
var schemaVersion = 5;

var tileDefinitions = [
    { id: "time", columnSpan: 2, rowSpan: 2 },
    { id: "battery", columnSpan: 1, rowSpan: 2 },
    { id: "cpu", columnSpan: 1, rowSpan: 1 },
    { id: "gpu", columnSpan: 1, rowSpan: 1 },
    { id: "memoryUsed", columnSpan: 1, rowSpan: 1 },
    { id: "wifi", columnSpan: 1, rowSpan: 1 },
    { id: "network", columnSpan: 2, rowSpan: 1 },
    { id: "storage", columnSpan: 3, rowSpan: 1 },
    { id: "calendar", columnSpan: 1, rowSpan: 1 }
];

var defaultAnchors = {
    time: { column: 0, row: 0 },
    battery: { column: 2, row: 0 },
    cpu: { column: 0, row: 2 },
    gpu: { column: 1, row: 2 },
    memoryUsed: { column: 2, row: 2 },
    wifi: { column: 0, row: 3 },
    network: { column: 1, row: 3 },
    storage: { column: 0, row: 4 },
    calendar: { column: 0, row: 5 }
};

function cloneTile(tile) {
    return {
        id: String(tile.id),
        column: Number(tile.column),
        row: Number(tile.row),
        columnSpan: Number(tile.columnSpan),
        rowSpan: Number(tile.rowSpan)
    };
}

function definitions() {
    return tileDefinitions.map(function(definition) {
        return {
            id: definition.id,
            columnSpan: definition.columnSpan,
            rowSpan: definition.rowSpan
        };
    });
}

function definitionFor(id) {
    for (var index = 0; index < tileDefinitions.length; index += 1) {
        if (tileDefinitions[index].id === id)
            return tileDefinitions[index];
    }
    return null;
}

function defaultLayout() {
    return tileDefinitions.map(function(definition) {
        var anchor = defaultAnchors[definition.id];
        return {
            id: definition.id,
            column: anchor.column,
            row: anchor.row,
            columnSpan: definition.columnSpan,
            rowSpan: definition.rowSpan
        };
    });
}

function placementFor(layout, id) {
    if (!Array.isArray(layout))
        return null;
    for (var index = 0; index < layout.length; index += 1) {
        if (layout[index].id === id)
            return layout[index];
    }
    return null;
}

function maskFor(column, row, columnSpan, rowSpan) {
    var mask = 0;
    for (var y = row; y < row + rowSpan; y += 1) {
        for (var x = column; x < column + columnSpan; x += 1)
            mask |= (1 << (y * columnCount + x));
    }
    return mask;
}

function withinBounds(tile) {
    return Number.isInteger(tile.column)
        && Number.isInteger(tile.row)
        && tile.column >= 0
        && tile.row >= 0
        && tile.column + tile.columnSpan <= columnCount
        && tile.row + tile.rowSpan <= rowCount;
}

function validateLayout(layout) {
    if (!Array.isArray(layout) || layout.length !== tileDefinitions.length)
        return false;

    var seen = {};
    var occupied = 0;
    for (var index = 0; index < layout.length; index += 1) {
        var tile = layout[index];
        var definition = definitionFor(tile.id);
        if (!definition || seen[tile.id])
            return false;
        if (Number(tile.columnSpan) !== definition.columnSpan
                || Number(tile.rowSpan) !== definition.rowSpan) {
            return false;
        }
        if (!withinBounds(tile))
            return false;

        var mask = maskFor(
            tile.column,
            tile.row,
            tile.columnSpan,
            tile.rowSpan
        );
        if ((occupied & mask) !== 0)
            return false;
        occupied |= mask;
        seen[tile.id] = true;
    }

    for (var definitionIndex = 0;
            definitionIndex < tileDefinitions.length;
            definitionIndex += 1) {
        if (!seen[tileDefinitions[definitionIndex].id])
            return false;
    }
    return true;
}

function hydrateSaved(savedLayout) {
    if (!savedLayout
            || Number(savedLayout.version) !== schemaVersion
            || !Array.isArray(savedLayout.tiles)) {
        return defaultLayout();
    }

    var anchors = {};
    for (var index = 0; index < savedLayout.tiles.length; index += 1) {
        var saved = savedLayout.tiles[index];
        if (!saved || typeof saved.id !== "string" || anchors[saved.id])
            return defaultLayout();
        anchors[saved.id] = {
            column: Number(saved.column),
            row: Number(saved.row)
        };
    }

    var hydrated = tileDefinitions.map(function(definition) {
        var anchor = anchors[definition.id];
        return {
            id: definition.id,
            column: anchor ? anchor.column : NaN,
            row: anchor ? anchor.row : NaN,
            columnSpan: definition.columnSpan,
            rowSpan: definition.rowSpan
        };
    });
    return validateLayout(hydrated) ? hydrated : defaultLayout();
}

function serializeLayout(layout) {
    var source = validateLayout(layout) ? layout : defaultLayout();
    return {
        version: schemaVersion,
        tiles: tileDefinitions.map(function(definition) {
            var tile = placementFor(source, definition.id);
            return {
                id: definition.id,
                column: tile.column,
                row: tile.row
            };
        })
    };
}

function serializedLayoutsEqual(first, second) {
    return JSON.stringify(serializeLayout(hydrateSaved(first)))
        === JSON.stringify(serializeLayout(hydrateSaved(second)));
}

function clampAnchor(definition, column, row) {
    return {
        column: Math.max(
            0,
            Math.min(
                columnCount - definition.columnSpan,
                Math.round(Number(column) || 0)
            )
        ),
        row: Math.max(
            0,
            Math.min(
                rowCount - definition.rowSpan,
                Math.round(Number(row) || 0)
            )
        )
    };
}

function candidatesFor(tile, original) {
    var candidates = [];
    for (var row = 0; row <= rowCount - tile.rowSpan; row += 1) {
        for (var column = 0;
                column <= columnCount - tile.columnSpan;
                column += 1) {
            var distance = Math.abs(column - original.column)
                + Math.abs(row - original.row);
            candidates.push({
                column: column,
                row: row,
                mask: maskFor(
                    column,
                    row,
                    tile.columnSpan,
                    tile.rowSpan
                ),
                cost: distance * 1000 + row * columnCount + column
            });
        }
    }
    candidates.sort(function(first, second) {
        return first.cost - second.cost;
    });
    return candidates;
}

function moveLayout(layout, tileId, targetColumn, targetRow) {
    var current = validateLayout(layout)
        ? layout.map(cloneTile)
        : defaultLayout();
    var moving = placementFor(current, tileId);
    var definition = definitionFor(tileId);
    if (!moving || !definition)
        return null;

    var target = clampAnchor(definition, targetColumn, targetRow);
    var fixedMask = maskFor(
        target.column,
        target.row,
        definition.columnSpan,
        definition.rowSpan
    );
    var originalById = {};
    current.forEach(function(tile) {
        originalById[tile.id] = tile;
    });

    var remaining = current.filter(function(tile) {
        return tile.id !== tileId;
    });
    remaining.sort(function(first, second) {
        var areaDifference = second.columnSpan * second.rowSpan
            - first.columnSpan * first.rowSpan;
        if (areaDifference !== 0)
            return areaDifference;
        return first.id.localeCompare(second.id);
    });

    var candidateMap = {};
    remaining.forEach(function(tile) {
        candidateMap[tile.id] = candidatesFor(
            tile,
            originalById[tile.id]
        );
    });

    var bestCost = Number.POSITIVE_INFINITY;
    var bestPlacements = null;
    var placements = {};
    var visitedNodes = 0;
    var maximumNodes = 250000;

    function lowerBound(startIndex, occupiedMask) {
        var bound = 0;
        for (var itemIndex = startIndex;
                itemIndex < remaining.length;
                itemIndex += 1) {
            var candidates = candidateMap[remaining[itemIndex].id];
            var found = false;
            for (var candidateIndex = 0;
                    candidateIndex < candidates.length;
                    candidateIndex += 1) {
                if ((occupiedMask & candidates[candidateIndex].mask) === 0) {
                    bound += candidates[candidateIndex].cost;
                    found = true;
                    break;
                }
            }
            if (!found)
                return Number.POSITIVE_INFINITY;
        }
        return bound;
    }

    function search(index, occupiedMask, totalCost) {
        visitedNodes += 1;
        if (visitedNodes > maximumNodes || totalCost >= bestCost)
            return;
        if (index >= remaining.length) {
            bestCost = totalCost;
            bestPlacements = {};
            Object.keys(placements).forEach(function(id) {
                bestPlacements[id] = placements[id];
            });
            return;
        }

        var optimistic = lowerBound(index, occupiedMask);
        if (!isFinite(optimistic) || totalCost + optimistic >= bestCost)
            return;

        var tile = remaining[index];
        var candidates = candidateMap[tile.id];
        for (var candidateIndex = 0;
                candidateIndex < candidates.length;
                candidateIndex += 1) {
            var candidate = candidates[candidateIndex];
            if ((occupiedMask & candidate.mask) !== 0)
                continue;
            placements[tile.id] = candidate;
            search(
                index + 1,
                occupiedMask | candidate.mask,
                totalCost + candidate.cost
            );
            delete placements[tile.id];
        }
    }

    search(0, fixedMask, 0);
    if (!bestPlacements)
        return null;

    var result = tileDefinitions.map(function(tileDefinition) {
        if (tileDefinition.id === tileId) {
            return {
                id: tileId,
                column: target.column,
                row: target.row,
                columnSpan: tileDefinition.columnSpan,
                rowSpan: tileDefinition.rowSpan
            };
        }
        var placement = bestPlacements[tileDefinition.id];
        return {
            id: tileDefinition.id,
            column: placement.column,
            row: placement.row,
            columnSpan: tileDefinition.columnSpan,
            rowSpan: tileDefinition.rowSpan
        };
    });
    return validateLayout(result) ? result : null;
}
