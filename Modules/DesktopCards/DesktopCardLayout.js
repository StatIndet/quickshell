.pragma library

// Keep layout mode classification in one place.  This file owns geometry and
// collision solving; SystemCardPlacement.js owns the meaning of each mode.
Qt.include("../SystemCards/SystemCardPlacement.js");
Qt.include("../SystemCards/SystemCardGeometry.js");
Qt.include("../SystemCards/SystemCardGrid.js");

var desktopCardGap = cellGap;
var desktopCardEdgeInset = 24;
var desktopGridColumnPitch = cardGridStep;
var desktopGridRowPitch = cardGridStep;

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
    return {originX: 0, originY: 0, columnPitch: cardGridStep, rowPitch: cardGridStep,
        columns: Math.floor(canvasWidth / cardGridStep), rows: Math.floor(canvasHeight / cardGridStep)};
}

// At most 33 x 33 coarse samples, including boundaries, on any output size.
// Collision handling and snapping never enumerate this analysis grid.
function gridCandidatePoints(card, canvasWidth, canvasHeight) {
    const maxX = Math.max(0, canvasWidth - card.width);
    const maxY = Math.max(0, canvasHeight - card.height);
    const stepX = Math.max(cardGridStep, Math.ceil(maxX / 32 / cardGridStep) * cardGridStep);
    const stepY = Math.max(cardGridStep, Math.ceil(maxY / 32 / cardGridStep) * cardGridStep);
    const points = [];
    for (let row = 0; row <= Math.ceil(maxY / stepY); row += 1) {
        for (let column = 0; column <= Math.ceil(maxX / stepX); column += 1)
            points.push({x: gridSnap(column * stepX, maxX), y: gridSnap(row * stepY, maxY), rank: points.length});
    }
    return points;
}

function snapPoint(x, y, cardWidth, cardHeight, canvasWidth, canvasHeight) {
    return {x: gridSnap(x, canvasWidth - cardWidth), y: gridSnap(y, canvasHeight - cardHeight)};
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
    return !!first && !!second && gridOverlaps(first, second, Math.max(0, Number(gap) || 0));
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
    const candidates = candidatePoints(card, canvasWidth, canvasHeight).concat(
        gridEdgeCandidates({id: card.id, x: card.xNorm * canvasWidth, y: card.yNorm * canvasHeight,
            width: card.width, height: card.height}, occupied, canvasWidth, canvasHeight, gap, cardGridStep));
    const scored = [];
    function score(point) {
        const rect = rectAt(card, point.x, point.y, canvasWidth, canvasHeight, 0);
        if (overlapsAny(rect, occupied, gap))
            return;
        scored.push({point: point, rect: rect, cost: candidateCost(card, point, rect, analysis,
            canvasWidth, canvasHeight, mode)});
    }
    candidates.forEach(score);
    scored.sort(function(a, b) { return a.cost - b.cost; });
    // Refine the four best coarse regions down to the actual snap step.
    let seeds = scored.slice(0, 4);
    let step = Math.max(cardGridStep, Math.ceil(Math.max(canvasWidth, canvasHeight) / 32 / cardGridStep) * cardGridStep);
    while (seeds.length > 0 && step >= cardGridStep) {
        seeds.forEach(function(seed) {
            for (let dy = -1; dy <= 1; dy += 1) {
                for (let dx = -1; dx <= 1; dx += 1) {
                    const point = snapPoint(seed.rect.x + dx * step, seed.rect.y + dy * step,
                        card.width, card.height, canvasWidth, canvasHeight);
                    point.rank = 0;
                    score(point);
                }
            }
        });
        scored.sort(function(a, b) { return a.cost - b.cost; });
        seeds = scored.slice(0, 4);
        if (step === cardGridStep)
            break;
        step = Math.max(cardGridStep, Math.floor(step / 2 / cardGridStep) * cardGridStep);
    }
    return scored.length > 0 ? scored[0] : null;
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
    if (!isWallpaperLayoutMode(selectedMode) || (cards || []).some(function(card) {
        return card.width > safeWidth || card.height > safeHeight;
    }))
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
    const size = boundedSize(card, canvasWidth, canvasHeight);
    const edge = Math.floor(safeInset(canvasWidth, canvasHeight, size, desktopCardEdgeInset) / cardGridStep) * cardGridStep;
    const candidates = gridEdgeCandidates({id: card.id, x: anchor.x - edge, y: anchor.y - edge,
        width: card.width, height: card.height}, occupied.map(function(rect) {
            return {x: rect.x - edge, y: rect.y - edge, width: rect.width, height: rect.height};
        }), canvasWidth - edge * 2, canvasHeight - edge * 2, gap, cardGridStep)
        .map(function(point) { return {x: point.x + edge, y: point.y + edge, rank: point.rank}; });
    const scored = [];
    candidates.forEach(function(point) {
        const rect = rectAt(
            card, point.x, point.y, canvasWidth, canvasHeight,
            0);
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
    if (!isScreenLayoutMode(selectedMode) || (cards || []).some(function(card) {
        return card.width > safeWidth || card.height > safeHeight;
    }))
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
function resolveWithStep(cards, preferredId, canvasWidth, canvasHeight, gap, step) {
    const source = collisionOrder(cards, preferredId);
    const occupied = [];
    const result = [];
    for (let index = 0; index < source.length; index += 1) {
        const card = source[index];
        const resolved = gridNearestFree(card, occupied, canvasWidth, canvasHeight, gap, step);
        if (!resolved)
            return [];
        occupied.push(resolved);
        result.push({id: String(card.id), x: resolved.x, y: resolved.y,
            width: resolved.width, height: resolved.height, rect: resolved});
    }
    return result;
}

function resolveAllContinuousCollisions(cards, preferredId, canvasWidth, canvasHeight, gap) {
    return resolveWithStep(cards, preferredId, canvasWidth, canvasHeight,
        gap === undefined ? desktopCardGap : gap, 0);
}

function resolveAllGridCollisions(cards, preferredId, canvasWidth, canvasHeight, gap) {
    return resolveWithStep(cards, preferredId, canvasWidth, canvasHeight,
        gap === undefined ? desktopCardGap : gap, cardGridStep);
}

function resolveAllCollisions(cards, preferredId, canvasWidth, canvasHeight, gap, snapToGrid) {
    const collisionGap = gap === undefined ? desktopCardGap : Math.max(0, Number(gap) || 0);
    const step = snapToGrid ? cardGridStep : 0;
    const resolved = resolveWithStep(cards, preferredId, canvasWidth, canvasHeight, collisionGap, step);
    if (resolved.length === (cards || []).length || collisionGap === 0)
        return resolved;
    return resolveWithStep(cards, preferredId, canvasWidth, canvasHeight, 0, step);
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
