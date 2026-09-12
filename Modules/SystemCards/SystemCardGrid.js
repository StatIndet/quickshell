.pragma library

// Positioning is independent of the catalog's visual size presets.
var cardGridStep = 8;
var cardGridGuideStep = 24;

function gridSnap(value, maximum, step) {
    var pitch = step || cardGridStep;
    var limit = Math.max(0, Math.floor(maximum / pitch) * pitch);
    return Math.max(0, Math.min(limit, Math.round((Number(value) || 0) / pitch) * pitch));
}

function gridOverlaps(first, second, gap) {
    return first.x < second.x + second.width + gap
        && first.x + first.width + gap > second.x
        && first.y < second.y + second.height + gap
        && first.y + first.height + gap > second.y;
}

// Each free rectangle can slide to an occupied edge or a canvas boundary.
// Include both sides of a rounded edge so fractional desktop coordinates
// cannot remove a legal snapped candidate. Size is O(card count squared),
// independent of canvas resolution or the number of grid cells.
function gridEdgeCandidates(card, occupied, width, height, gap, step) {
    var maxX = Math.max(0, width - card.width);
    var maxY = Math.max(0, height - card.height);
    var xs = [];
    var ys = [];
    function add(values, value, maximum) {
        var options = step > 0
            ? [Math.floor(value / step) * step, Math.ceil(value / step) * step]
            : [value];
        options.forEach(function(option) {
            var limit = step > 0 ? Math.floor(maximum / step) * step : maximum;
            var bounded = Math.max(0, Math.min(limit, option));
            if (values.indexOf(bounded) === -1)
                values.push(bounded);
        });
    }
    add(xs, Number(card.x) || 0, maxX);
    add(ys, Number(card.y) || 0, maxY);
    add(xs, 0, maxX);
    add(ys, 0, maxY);
    add(xs, maxX, maxX);
    add(ys, maxY, maxY);
    occupied.forEach(function(rect) {
        add(xs, rect.x - card.width - gap, maxX);
        add(xs, rect.x + rect.width + gap, maxX);
        add(ys, rect.y - card.height - gap, maxY);
        add(ys, rect.y + rect.height + gap, maxY);
    });
    var points = [];
    ys.forEach(function(y) {
        xs.forEach(function(x) { points.push({x: x, y: y, rank: points.length}); });
    });
    return points;
}

function gridNearestFree(card, occupied, width, height, gap, step) {
    if (card.width > width || card.height > height)
        return null;
    var candidates = gridEdgeCandidates(card, occupied, width, height, gap, step);
    candidates.sort(function(a, b) {
        var delta = (a.x - card.x) * (a.x - card.x) + (a.y - card.y) * (a.y - card.y)
            - (b.x - card.x) * (b.x - card.x) - (b.y - card.y) * (b.y - card.y);
        if (delta !== 0)
            return delta;
        return a.y - b.y || a.x - b.x;
    });
    for (var i = 0; i < candidates.length; i += 1) {
        var rect = {id: card.id, x: candidates[i].x, y: candidates[i].y,
            width: card.width, height: card.height};
        if (!occupied.some(function(other) { return gridOverlaps(rect, other, gap); }))
            return rect;
    }
    return null;
}
