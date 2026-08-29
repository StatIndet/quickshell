.pragma library

// Keep layout mode classification in one place.  This file owns geometry and
// collision solving; SystemCardPlacement.js owns the meaning of each mode.
Qt.include("../SystemCards/SystemCardPlacement.js");
Qt.include("../SystemCards/SystemCardGeometry.js");

var desktopCardGap = cellGap;
var desktopCardEdgeInset = 24;
var desktopGridColumnPitch = baseCellWidth + cellGap;
var desktopGridRowPitch = baseCellHeight + cellGap;

function safeNumber(value, fallback) {
    const number = Number(value);
    return isFinite(number) ? number : fallback;
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
}

function normalizedPosition(card) {
    return {
        xNorm: clamp(safeNumber(card.xNorm, 0.5), 0, 1),
        yNorm: clamp(safeNumber(card.yNorm, 0.5), 0, 1)
    };
}

function boundedSize(card, canvasWidth, canvasHeight) {
    return {
        width: Math.max(1, Math.min(
            safeNumber(card.width, 1), Math.max(1, canvasWidth))),
        height: Math.max(1, Math.min(
            safeNumber(card.height, 1), Math.max(1, canvasHeight)))
    };
}

function safeInset(canvasWidth, canvasHeight, size, inset) {
    const requested = Math.max(0, Number(inset) || 0);
    const availableX = Math.max(0, canvasWidth - size.width);
    const availableY = Math.max(0, canvasHeight - size.height);
    return Math.min(requested, availableX / 2, availableY / 2);
}

function gridMetrics(canvasWidth, canvasHeight) {
    const safeWidth = Math.max(1, safeNumber(canvasWidth, 1));
    const safeHeight = Math.max(1, safeNumber(canvasHeight, 1));
    const columns = Math.max(1, Math.floor(
        (safeWidth + cellGap - desktopCardEdgeInset * 2)
            / desktopGridColumnPitch));
    const rows = Math.max(1, Math.floor(
        (safeHeight + cellGap - desktopCardEdgeInset * 2)
            / desktopGridRowPitch));
    const gridWidth = columns * baseCellWidth
        + Math.max(0, columns - 1) * cellGap;
    const gridHeight = rows * baseCellHeight
        + Math.max(0, rows - 1) * cellGap;
    const originX = Math.max(0, (safeWidth - gridWidth) / 2);
    const originY = Math.max(0, (safeHeight - gridHeight) / 2);
    return {
        originX: originX,
        originY: originY,
        columnPitch: desktopGridColumnPitch,
        rowPitch: desktopGridRowPitch,
        cellWidth: baseCellWidth,
        cellHeight: baseCellHeight,
        columns: columns,
        rows: rows
    };
}

function gridAxisValues(maximum, origin, pitch) {
    const maxValue = Math.max(0, Number(maximum) || 0);
    const first = clamp(Number(origin) || 0, 0, maxValue);
    const step = Math.max(1, Number(pitch) || 1);
    const values = [];
    for (let value = first; value <= maxValue + 0.001; value += step)
        values.push(value);

    if (values.length === 0)
        values.push(first);
    return values;
}

function gridCandidatePoints(card, canvasWidth, canvasHeight) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const metrics = gridMetrics(canvasWidth, canvasHeight);
    const xValues = gridAxisValues(
        canvasWidth - metrics.originX - size.width,
        metrics.originX, metrics.columnPitch);
    const yValues = gridAxisValues(
        canvasHeight - metrics.originY - size.height,
        metrics.originY, metrics.rowPitch);
    const points = [];
    let rank = 0;
    yValues.forEach(function(y) {
        xValues.forEach(function(x) {
            points.push({ x: x, y: y, rank: rank });
            rank += 1;
        });
    });
    return points;
}

function snapPoint(x, y, cardWidth, cardHeight, canvasWidth, canvasHeight) {
    const card = {
        id: "snap-preview",
        width: cardWidth,
        height: cardHeight
    };
    const desired = { x: Number(x) || 0, y: Number(y) || 0 };
    const candidates = gridCandidatePoints(
        card, canvasWidth, canvasHeight);
    let closest = candidates[0] || desired;
    let closestDistance = movementDistance(closest, desired);
    for (let index = 1; index < candidates.length; index += 1) {
        const distance = movementDistance(candidates[index], desired);
        if (distance < closestDistance) {
            closest = candidates[index];
            closestDistance = distance;
        }
    }
    return { x: closest.x, y: closest.y };
}

function rectAt(card, x, y, canvasWidth, canvasHeight, inset) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const edge = safeInset(canvasWidth, canvasHeight, size, inset || 0);
    return {
        id: String(card.id),
        x: clamp(Number(x) || 0, edge,
            Math.max(edge, canvasWidth - edge - size.width)),
        y: clamp(Number(y) || 0, edge,
            Math.max(edge, canvasHeight - edge - size.height)),
        width: size.width,
        height: size.height
    };
}

function rectsOverlap(first, second, gap) {
    if (!first || !second)
        return false;
    const padding = Math.max(0, Number(gap) || 0);
    return first.x < second.x + second.width + padding
        && first.x + first.width + padding > second.x
        && first.y < second.y + second.height + padding
        && first.y + first.height + padding > second.y;
}

function overlapsAny(rect, occupied, gap) {
    const list = Array.isArray(occupied) ? occupied : [];
    for (let index = 0; index < list.length; index += 1) {
        if (rectsOverlap(rect, list[index], gap))
            return true;
    }
    return false;
}

function candidatePoints(card, canvasWidth, canvasHeight) {
    return gridCandidatePoints(card, canvasWidth, canvasHeight);
}

function busyScore(analysis, rect) {
    if (!analysis || !analysis.valid
            || typeof analysis.busyScore !== "function")
        return 0;
    const score = Number(analysis.busyScore(
        rect.x, rect.y, rect.width, rect.height));
    return isFinite(score) ? clamp(score, 0, 1) : 0;
}

function edgePenalty(rect, canvasWidth, canvasHeight) {
    const edgeDistance = Math.min(
        rect.x,
        rect.y,
        canvasWidth - rect.x - rect.width,
        canvasHeight - rect.y - rect.height
    ) / Math.max(1, Math.min(canvasWidth, canvasHeight));
    return Math.max(0, 0.08 - edgeDistance) * 0.02;
}

function movementPenalty(card, point, canvasWidth, canvasHeight) {
    const current = normalizedPosition(card);
    const dx = point.x / Math.max(1, canvasWidth) - current.xNorm;
    const dy = point.y / Math.max(1, canvasHeight) - current.yNorm;
    return (dx * dx + dy * dy) * 0.0005;
}

function candidateCost(card, point, rect, analysis, canvasWidth,
                      canvasHeight, mode) {
    const score = busyScore(analysis, rect);
    const wallpaperCost = mode === "mostBusy" ? -score : score;
    return wallpaperCost
        + edgePenalty(rect, canvasWidth, canvasHeight)
        + movementPenalty(card, point, canvasWidth, canvasHeight)
        + point.rank * 0.000000001;
}

function placeWallpaperCard(card, occupied, canvasWidth, canvasHeight,
                            analysis, gap, mode) {
    const candidates = candidatePoints(card, canvasWidth, canvasHeight);
    const scored = [];
    for (let index = 0; index < candidates.length; index += 1) {
        const point = candidates[index];
        const rect = rectAt(
            card, point.x, point.y, canvasWidth, canvasHeight, 0);
        if (overlapsAny(rect, occupied, gap))
            continue;
        scored.push({
            point: point,
            rect: rect,
            cost: candidateCost(
                card, point, rect, analysis,
                canvasWidth, canvasHeight, mode)
        });
    }

    scored.sort(function(first, second) {
        return first.cost - second.cost;
    });
    if (scored.length > 0)
        return scored[0];

    // The normal grid is intentionally sparse. Search narrow holes before
    // falling back to a deterministic bounded point.
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const maxX = Math.max(0, canvasWidth - size.width);
    const maxY = Math.max(0, canvasHeight - size.height);
    const fallbackStep = Math.max(1, Math.floor(
        Math.min(size.width, size.height) / 4));
    for (let y = 0; y <= maxY + 1; y += fallbackStep) {
        for (let x = 0; x <= maxX + 1; x += fallbackStep) {
            const rect = rectAt(card, x, y, canvasWidth, canvasHeight, 0);
            if (!overlapsAny(rect, occupied, gap)) {
                return {
                    point: { x: rect.x, y: rect.y, rank: 0 },
                    rect: rect,
                    cost: candidateCost(
                        card, { x: rect.x, y: rect.y, rank: 0 }, rect,
                        analysis, canvasWidth, canvasHeight, mode)
                };
            }
        }
    }
    // Let the caller retry with a smaller gap before using the final
    // deterministic collision fallback. Never silently return an overlapping
    // candidate merely because the preferred grid was exhausted.
    return null;
}

function sortedCards(cards) {
    const source = Array.isArray(cards) ? cards.slice() : [];
    source.sort(function(first, second) {
        const areaDifference = safeNumber(second.width, 0)
            * safeNumber(second.height, 0)
            - safeNumber(first.width, 0) * safeNumber(first.height, 0);
        if (areaDifference !== 0)
            return areaDifference;
        return String(first.id).localeCompare(String(second.id));
    });
    return source;
}

function solveWallpaperWithGap(cards, canvasWidth, canvasHeight, analysis,
                               mode, gap) {
    const occupied = [];
    const placements = [];
    sortedCards(cards).forEach(function(card) {
        const placed = placeWallpaperCard(
            card, occupied, canvasWidth, canvasHeight, analysis,
            gap, mode);
        if (!placed)
            return;
        occupied.push(placed.rect);
        placements.push({
            id: String(card.id),
            xNorm: clamp(placed.rect.x / canvasWidth, 0, 1),
            yNorm: clamp(placed.rect.y / canvasHeight, 0, 1),
            rect: placed.rect
        });
    });
    return placements;
}

function solve(cards, canvasWidth, canvasHeight, analysis, mode) {
    const safeWidth = Math.max(1, safeNumber(canvasWidth, 1));
    const safeHeight = Math.max(1, safeNumber(canvasHeight, 1));
    const selectedMode = String(mode || "");
    if (!isWallpaperLayoutMode(selectedMode))
        return [];

    let placements = solveWallpaperWithGap(
        cards, safeWidth, safeHeight, analysis,
        selectedMode, desktopCardGap);
    if (placements.length !== (Array.isArray(cards) ? cards.length : 0)
            || !hasNoOverlap(placements, desktopCardGap)) {
        placements = solveWallpaperWithGap(
            cards, safeWidth, safeHeight, analysis,
            selectedMode, 0);
    }
    if (placements.length !== (Array.isArray(cards) ? cards.length : 0)
            || !hasNoOverlap(placements, 0)) {
        return deterministicPackedPlacements(
            cards, placements, safeWidth, safeHeight, 0);
    }
    return placements;
}

function anchorPoint(mode, card, canvasWidth, canvasHeight) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const edge = safeInset(
        canvasWidth, canvasHeight, size, desktopCardEdgeInset);
    const maxX = Math.max(edge, canvasWidth - edge - size.width);
    const maxY = Math.max(edge, canvasHeight - edge - size.height);
    switch (String(mode || "")) {
    case "screenTopRight":
        return { x: maxX, y: edge };
    case "screenBottomLeft":
        return { x: edge, y: maxY };
    case "screenBottomRight":
        return { x: maxX, y: maxY };
    case "screenCenter":
        return {
            x: (canvasWidth - size.width) / 2,
            y: (canvasHeight - size.height) / 2
        };
    case "screenTopLeft":
    default:
        return { x: edge, y: edge };
    }
}

function screenCandidatePoints(card, canvasWidth, canvasHeight, mode) {
    return gridCandidatePoints(card, canvasWidth, canvasHeight);
}

function screenDistance(point, anchor, width, height) {
    const dx = (point.x - anchor.x) / Math.max(1, width);
    const dy = (point.y - anchor.y) / Math.max(1, height);
    return dx * dx + dy * dy;
}

function screenCandidateCost(card, point, anchor, width, height) {
    const current = normalizedPosition(card);
    const movementX = point.x / Math.max(1, width) - current.xNorm;
    const movementY = point.y / Math.max(1, height) - current.yNorm;
    return screenDistance(point, anchor, width, height)
        + (movementX * movementX + movementY * movementY) * 0.0005
        + point.rank * 0.000000001;
}

function placeScreenCard(card, occupied, canvasWidth, canvasHeight, mode,
                         gap) {
    const anchor = anchorPoint(mode, card, canvasWidth, canvasHeight);
    const candidates = screenCandidatePoints(
        card, canvasWidth, canvasHeight, mode);
    const scored = [];
    candidates.forEach(function(point) {
        const rect = rectAt(
            card, point.x, point.y, canvasWidth, canvasHeight,
            desktopCardEdgeInset);
        if (overlapsAny(rect, occupied, gap))
            return;
        scored.push({
            point: point,
            rect: rect,
            cost: screenCandidateCost(
                card, point, anchor, canvasWidth, canvasHeight)
        });
    });
    scored.sort(function(first, second) {
        return first.cost - second.cost;
    });
    if (scored.length > 0)
        return scored[0];
    // Let solveScreen retry with zero gap. If the output is genuinely over
    // capacity, the deterministic fallback is applied after both attempts.
    return null;
}

function solveScreenWithGap(cards, canvasWidth, canvasHeight, mode, gap) {
    const occupied = [];
    const placements = [];
    sortedCards(cards).forEach(function(card) {
        const placed = placeScreenCard(
            card, occupied, canvasWidth, canvasHeight, mode, gap);
        if (!placed)
            return;
        occupied.push(placed.rect);
        placements.push({
            id: String(card.id),
            xNorm: clamp(placed.rect.x / canvasWidth, 0, 1),
            yNorm: clamp(placed.rect.y / canvasHeight, 0, 1),
            rect: placed.rect
        });
    });
    return placements;
}

function solveScreen(cards, canvasWidth, canvasHeight, mode) {
    const safeWidth = Math.max(1, safeNumber(canvasWidth, 1));
    const safeHeight = Math.max(1, safeNumber(canvasHeight, 1));
    const selectedMode = String(mode || "");
    if (!isScreenLayoutMode(selectedMode))
        return [];
    let placements = solveScreenWithGap(
        cards, safeWidth, safeHeight, selectedMode, desktopCardGap);
    if (placements.length !== (Array.isArray(cards) ? cards.length : 0)
            || !hasNoOverlap(placements, desktopCardGap)) {
        // Very small outputs may not have room for the preferred gap. Keep
        // the layout deterministic and prioritize non-overlap over spacing.
        placements = solveScreenWithGap(
            cards, safeWidth, safeHeight, selectedMode, 0);
    }
    if (placements.length !== (Array.isArray(cards) ? cards.length : 0)
            || !hasNoOverlap(placements, 0)) {
        placements = deterministicPackedPlacements(
            cards, placements, safeWidth, safeHeight, 0);
    }
    return placements;
}

function movementDistance(first, second) {
    const dx = Number(first.x) - Number(second.x);
    const dy = Number(first.y) - Number(second.y);
    return dx * dx + dy * dy;
}

function uniqueCoordinate(values, value, maximum) {
    const bounded = clamp(Number(value) || 0, 0,
        Math.max(0, maximum));
    const normalized = Math.round(bounded * 1000) / 1000;
    if (values.some(function(existing) {
        return Math.abs(existing - normalized) < 0.001;
    })) {
        return;
    }
    values.push(normalized);
}

function avoidanceCandidates(card, occupied, canvasWidth, canvasHeight,
                             gap) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const current = rectAt(
        card, card.x, card.y, canvasWidth, canvasHeight, 0);
    const maxX = Math.max(0, canvasWidth - size.width);
    const maxY = Math.max(0, canvasHeight - size.height);
    const padding = Math.max(0, Number(gap) || 0);
    const xValues = [];
    const yValues = [];

    uniqueCoordinate(xValues, current.x, maxX);
    uniqueCoordinate(xValues, 0, maxX);
    uniqueCoordinate(xValues, maxX, maxX);
    uniqueCoordinate(yValues, current.y, maxY);
    uniqueCoordinate(yValues, 0, maxY);
    uniqueCoordinate(yValues, maxY, maxY);

    // A free rectangle can be slid until an edge touches either the output
    // boundary or an occupied edge. Enumerating these boundaries is a
    // complete small candidate set for the normal case and avoids the old
    // fixed-radius search that could silently leave an overlap.
    (Array.isArray(occupied) ? occupied : []).forEach(function(rect) {
        uniqueCoordinate(xValues,
            rect.x - size.width - padding, maxX);
        uniqueCoordinate(xValues,
            rect.x + rect.width + padding, maxX);
        uniqueCoordinate(yValues,
            rect.y - size.height - padding, maxY);
        uniqueCoordinate(yValues,
            rect.y + rect.height + padding, maxY);
    });

    const points = [];
    xValues.forEach(function(x) {
        yValues.forEach(function(y) {
            points.push({
                x: x,
                y: y,
                rank: Math.abs(x - current.x) + Math.abs(y - current.y)
            });
        });
    });
    return points;
}

function exhaustiveGridPosition(card, occupied, canvasWidth, canvasHeight,
                                gap) {
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const maxX = Math.max(0, canvasWidth - size.width);
    const maxY = Math.max(0, canvasHeight - size.height);
    const step = 4;
    let best = null;
    for (let y = 0; y <= maxY + 0.001; y += step) {
        for (let x = 0; x <= maxX + 0.001; x += step) {
            const rect = rectAt(
                card, x, y, canvasWidth, canvasHeight, 0);
            if (overlapsAny(rect, occupied, gap))
                continue;
            const candidate = {
                rect: rect,
                cost: movementDistance(rect, card) + x + y
            };
            if (!best || candidate.cost < best.cost)
                best = candidate;
        }
    }
    return best ? best.rect : null;
}

function nearestFreePosition(card, occupied, canvasWidth, canvasHeight,
                             gap) {
    const candidates = avoidanceCandidates(
        card, occupied, canvasWidth, canvasHeight, gap);
    const scored = [];
    function collect(points) {
        points.forEach(function(point) {
            const rect = rectAt(
                card, point.x, point.y, canvasWidth, canvasHeight, 0);
            if (overlapsAny(rect, occupied, gap))
                return;
            scored.push({
                rect: rect,
                cost: movementDistance(rect, card)
                    + point.rank * 0.000001
            });
        });
    }
    collect(candidates);
    if (scored.length === 0) {
        const exhaustive = exhaustiveGridPosition(
            card, occupied, canvasWidth, canvasHeight, gap);
        if (exhaustive)
            scored.push({
                rect: exhaustive,
                cost: movementDistance(exhaustive, card)
            });
    }
    scored.sort(function(first, second) {
        return first.cost - second.cost;
    });
    return scored.length > 0 ? scored[0].rect : null;
}

function nearestFreeGridPosition(card, occupied, canvasWidth, canvasHeight,
                                 gap) {
    const candidates = gridCandidatePoints(
        card, canvasWidth, canvasHeight);
    const scored = [];
    candidates.forEach(function(point) {
        const rect = rectAt(
            card, point.x, point.y, canvasWidth, canvasHeight,
            desktopCardEdgeInset);
        if (overlapsAny(rect, occupied, gap))
            return;
        scored.push({
            rect: rect,
            cost: movementDistance(rect, card)
                + point.rank * 0.000001
        });
    });
    scored.sort(function(first, second) {
        return first.cost - second.cost;
    });
    return scored.length > 0 ? scored[0].rect : null;
}

function collisionOrder(cards, preferredId) {
    const preferred = String(preferredId || "");
    const source = Array.isArray(cards) ? cards.slice() : [];
    source.sort(function(first, second) {
        const firstId = String(first.id);
        const secondId = String(second.id);
        if (firstId === preferred && secondId !== preferred)
            return -1;
        if (secondId === preferred && firstId !== preferred)
            return 1;
        const areaDifference = safeNumber(second.width, 0)
            * safeNumber(second.height, 0)
            - safeNumber(first.width, 0) * safeNumber(first.height, 0);
        if (areaDifference !== 0)
            return areaDifference;
        return firstId.localeCompare(secondId);
    });
    return source;
}

// Resolve a complete set of desired screen-space rectangles in deterministic
// order. The preferred card is placed first and is therefore authoritative;
// every later card is an avoider. The result is runtime geometry and never
// writes persistence by itself.
function resolveAllContinuousCollisions(cards, preferredId, canvasWidth,
                                        canvasHeight, gap) {
    const collisionGap = gap === undefined
        ? desktopCardGap : Math.max(0, Number(gap) || 0);
    const source = collisionOrder(cards, preferredId);
    const occupied = [];
    const result = [];
    source.forEach(function(card) {
        const original = rectAt(
            card, card.x, card.y, canvasWidth, canvasHeight, 0);
        let resolved = original;
        if (overlapsAny(original, occupied, collisionGap)) {
            resolved = nearestFreePosition(
                { id: card.id, x: original.x, y: original.y,
                    width: original.width, height: original.height },
                occupied, canvasWidth, canvasHeight, collisionGap
            ) || (collisionGap > 0 ? nearestFreePosition(
                { id: card.id, x: original.x, y: original.y,
                    width: original.width, height: original.height },
                occupied, canvasWidth, canvasHeight, 0
            ) : null) || original;
        }
        occupied.push(resolved);
        result.push({
            id: String(card.id),
            x: resolved.x,
            y: resolved.y,
            width: resolved.width,
            height: resolved.height,
            rect: resolved
        });
    });
    return result;
}

function resolveAllGridCollisions(cards, preferredId, canvasWidth,
                                  canvasHeight, gap) {
    const source = collisionOrder(cards, preferredId);
    const occupied = [];
    const result = [];
    for (let index = 0; index < source.length; index += 1) {
        const card = source[index];
        const resolved = nearestFreeGridPosition(
            card, occupied, canvasWidth, canvasHeight, gap);
        if (!resolved)
            return [];
        occupied.push(resolved);
        result.push({
            id: String(card.id),
            x: resolved.x,
            y: resolved.y,
            width: resolved.width,
            height: resolved.height,
            rect: resolved
        });
    }
    return result;
}

function resolveAllCollisions(cards, preferredId, canvasWidth, canvasHeight,
                              gap, snapToGrid) {
    const collisionGap = gap === undefined
        ? desktopCardGap : Math.max(0, Number(gap) || 0);
    if (!!snapToGrid) {
        let gridResult = resolveAllGridCollisions(
            cards, preferredId, canvasWidth, canvasHeight, collisionGap);
        if (gridResult.length === (Array.isArray(cards) ? cards.length : 0)
                && hasNoOverlap(gridResult, collisionGap))
            return gridResult;
        if (collisionGap > 0) {
            gridResult = resolveAllGridCollisions(
                cards, preferredId, canvasWidth, canvasHeight, 0);
            if (gridResult.length === (Array.isArray(cards) ? cards.length : 0)
                    && hasNoOverlap(gridResult, 0))
                return gridResult;
        }
    }
    return resolveAllContinuousCollisions(
        cards, preferredId, canvasWidth, canvasHeight, collisionGap);
}

// The dragged card is authoritative. Every other card is an avoider. The
// result is runtime-only screen geometry; callers decide when to batch commit
// it to the persistent CardState.
function resolveDraggedCollision(cards, draggedId, draggedRect,
                                 canvasWidth, canvasHeight, snapToGrid) {
    const source = Array.isArray(cards) ? cards.slice() : [];
    const id = String(draggedId || "");
    const dragged = source.find(function(card) {
        return String(card.id) === id;
    });
    if (!dragged)
        return [];
    const desired = source.map(function(card) {
        if (String(card.id) === id) {
            return {
                id: id,
                x: Number(draggedRect.x),
                y: Number(draggedRect.y),
                width: Number(draggedRect.width),
                height: Number(draggedRect.height)
            };
        }
        return card;
    });
    return resolveAllCollisions(
        desired, id, canvasWidth, canvasHeight, desktopCardGap,
        !!snapToGrid);
}

function deterministicPackedPlacements(cards, existing, canvasWidth,
                                        canvasHeight, gap) {
    const byId = {};
    (Array.isArray(existing) ? existing : []).forEach(function(placement) {
        const rect = placement.rect || placement;
        byId[String(placement.id)] = rect;
    });
    const desired = (Array.isArray(cards) ? cards : []).map(function(card) {
        const rect = byId[String(card.id)];
        const fallback = normalizedPosition(card);
        return {
            id: String(card.id),
            x: rect ? rect.x : fallback.xNorm * canvasWidth,
            y: rect ? rect.y : fallback.yNorm * canvasHeight,
            width: card.width,
            height: card.height
        };
    });
    const resolved = resolveAllCollisions(
        desired, "", canvasWidth, canvasHeight, gap);
    return resolved.map(function(rect) {
        return {
            id: rect.id,
            xNorm: clamp(rect.x / Math.max(1, canvasWidth), 0, 1),
            yNorm: clamp(rect.y / Math.max(1, canvasHeight), 0, 1),
            rect: rect.rect
        };
    });
}

function hasNoOverlap(placements, gap) {
    const list = Array.isArray(placements) ? placements : [];
    for (let first = 0; first < list.length; first += 1) {
        for (let second = first + 1; second < list.length; second += 1) {
            const firstRect = list[first].rect || list[first];
            const secondRect = list[second].rect || list[second];
            if (rectsOverlap(firstRect, secondRect,
                    gap === undefined ? desktopCardGap : gap))
                return false;
        }
    }
    return true;
}
