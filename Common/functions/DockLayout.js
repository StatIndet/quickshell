.pragma library

// All windows remain in one row. Scale the gaps too when the row is crowded,
// so no window count or narrow output can force scrolling or negative sizes.
function windowPreviewRow(count, preferredWidth, availableWidth) {
    const available = Math.max(0, availableWidth);
    const margin = Math.min(8, available / 4);
    const inner = available - margin * 2;
    const gap = count > 1 ? Math.min(6, inner / (count * 8)) : 0;
    const cardWidth = count > 0 ? Math.min(Math.max(0, preferredWidth),
                                         (inner - gap * (count - 1)) / count) : 0;
    return { margin: margin, gap: gap, cardWidth: cardWidth,
             width: count > 0 ? margin * 2 + count * cardWidth + (count - 1) * gap : 0 };
}

// Work only in the unscaled coordinate system. Animated icon positions must
// never feed back into magnification, otherwise the dock chases the pointer.
function layout(kinds, preferredSize, available, magnification, sectionSpacing, pointer, sectionBoundary, strength = 1) {
    const gap = 8;
    const padding = 12;
    const count = kinds.length;
    const weights = kinds.map(kind => kind === "small-spacer" ? 0.5 : 1);
    const apps = weights.reduce((sum, weight) => sum + weight, 0);
    const maximum = Math.max(1, Math.min(2, magnification));
    // Fade the wave without changing the space reserved for its full size.
    // Its centre follows input directly; only its amplitude is animated.
    const amplitude = Math.max(0, Math.min(1, strength));
    const boundaries = (Array.isArray(sectionBoundary) ? sectionBoundary : [sectionBoundary])
        .filter((v, i, list) => v > 0 && v < count && list.indexOf(v) === i);
    const sectionGap = sectionSpacing + gap;
    const fixed = count * gap + padding * 2 + sectionGap * boundaries.length;
    const reserve = Math.min(apps, 5) * (maximum - 1);
    const size = Math.max(32, Math.min(preferredSize, (available - fixed) / Math.max(1, apps + reserve)));
    const baseLength = fixed + apps * size;
    let baseCursor = padding;
    let cursor = padding;
    let divider = -1;
    const dividers = [];
    const slots = [];
    for (let index = 0; index < count; ++index) {
        if (boundaries.indexOf(index) >= 0) {
            divider = cursor + sectionGap / 2;
            dividers.push(divider);
            baseCursor += sectionGap;
            cursor += sectionGap;
        }
        const baseSpan = size * weights[index] + gap;
        const center = baseCursor + baseSpan / 2;
        const distance = (pointer - center) / (size + gap);
        const scale = !isFinite(pointer) ? 1 : 1 + amplitude * (maximum - 1) * Math.exp(-distance * distance / 2);
        const span = size * weights[index] * scale + gap;
        slots.push({ center: center, start: cursor, span: span, size: size * scale });
        baseCursor += baseSpan;
        cursor += span;
    }
    return { size: size, baseLength: baseLength, length: cursor + padding, slots: slots, divider: divider, dividers: dividers,
             overflow: baseLength + reserve * size > available };
}

// Keep the automatic group divider out of model indices and persisted pins.
// A provisional drop slot belongs to the pinned group, including new apps.
function sectionBoundary(kinds, pinnedCount, order) {
    let hasPinnedApp = false;
    for (let index = 0; index < kinds.length; ++index) {
        const source = order ? order[index] : index;
        if (source >= pinnedCount)
            return hasPinnedApp ? index : -1;
        if (kinds[index] === "app")
            hasPinnedApp = true;
    }
    return -1;
}

function insertionIndex(slots, position) {
    for (let index = 0; index < slots.length; ++index) {
        if (position < slots[index].start + slots[index].span / 2)
            return index;
    }
    return slots.length;
}

// A drag changes presentation only. Gaps use the persisted list's indices,
// so committing a drop still uses the same insertion contract as DockService.
function previewOrder(kinds, sourceIndex, gapIndex, incomingKind) {
    const order = [];
    const previewKinds = [];
    for (let index = 0; index <= kinds.length; ++index) {
        if (index === gapIndex) {
            order.push(-1);
            previewKinds.push(incomingKind);
        }
        if (index < kinds.length && index !== sourceIndex) {
            order.push(index);
            previewKinds.push(kinds[index]);
        }
    }
    return { order: order, kinds: previewKinds };
}

function removalDistance(edge, x, y, width, height, edgeOffset) {
    if (edge === "left") return x - edgeOffset;
    if (edge === "right") return width - x - edgeOffset;
    return height - y - edgeOffset;
}

// The file area is a separate section even when there are no recent apps.
function sectionBoundaries(kinds, pinnedAppCount, order) {
    const result = [];
    let previous = "";
    let hasApp = false;
    for (let i = 0; i < kinds.length; ++i) {
        const source = order ? order[i] : i;
        const group = ["file", "folder", "trash"].indexOf(kinds[i]) >= 0 ? "files"
            : source < pinnedAppCount ? "pinned" : "running";
        if (i > 0 && group !== previous && (group === "files" || hasApp)) result.push(i);
        previous = group;
        if (kinds[i] === "app") hasApp = true;
    }
    return result;
}

// The scroll viewport uses uniform steps, while each row's icon and label
// share a tangent to this arc. Longer fans bend farther without tightening
// the gap between neighbours. Bounds include the rotated labels and action.
function bottomFanBounds(geometry) {
    const halfHeight = geometry.tileHeight / 2;
    const pivot = geometry.tileWidth - geometry.iconSize / 2 - 6;
    const right = geometry.iconSize / 2 + 6;
    const angle = geometry.angle;
    const radius = geometry.radius;
    // The lower left corner briefly swings left before following the arc.
    const leftAngle = Math.min(angle, Math.atan2(halfHeight, radius + pivot));
    return {
        left: radius - (radius + pivot) * Math.cos(leftAngle) - halfHeight * Math.sin(leftAngle),
        right: radius * (1 - Math.cos(angle)) + right * Math.cos(angle) + halfHeight * Math.sin(angle),
        top: angle > 0 ? -(radius + pivot) * Math.sin(angle) - halfHeight * Math.cos(angle)
                       : -geometry.count * geometry.step - geometry.stackReserve - halfHeight,
        bottom: halfHeight
    };
}

function bottomFolderFan(count, availableWidth, availableHeight, requestedIconSize, maximumOutset) {
    const padding = 8;
    const iconSize = Math.max(1, Math.min(requestedIconSize, availableWidth - padding * 2 - 18,
                                         availableHeight - padding * 2 - 8));
    const step = iconSize + Math.max(12, iconSize * 0.16);
    const preferredWidth = iconSize + 18 + Math.max(260, Math.min(440, iconSize * 4.5));
    const geometry = {iconSize: iconSize, step: step, tileHeight: iconSize + 8, slots: []};
    let shown = Math.max(0, Math.min(count, 8, Math.floor((availableHeight - iconSize - 8 - padding * 2) / step)));
    let bounds;
    do {
        geometry.count = shown;
        geometry.stackReserve = count > shown && shown > 0 ? 24 : 0;
        geometry.angle = shown > 0 ? Math.min(16, 6 + shown) * Math.PI / 180 : 0;
        const distance = shown * step + geometry.stackReserve;
        // Near an output edge, straighten the same arc rather than shifting
        // its foot away from the folder. The label still faces inward.
        if (isFinite(maximumOutset) && shown > 0) {
            let low = 0;
            let high = geometry.angle;
            for (let i = 0; i < 16; ++i) {
                const angle = (low + high) / 2;
                const outset = distance / angle * (1 - Math.cos(angle))
                    + (iconSize / 2 + 6) * Math.cos(angle)
                    + geometry.tileHeight / 2 * Math.sin(angle) + padding;
                if (outset <= maximumOutset - 1) low = angle;
                else high = angle;
            }
            geometry.angle = low;
        }
        geometry.radius = geometry.angle > 0 ? distance / geometry.angle : 0;
        geometry.tileWidth = preferredWidth;
        bounds = bottomFanBounds(geometry);
        const overflow = bounds.right - bounds.left + padding * 2 - availableWidth;
        if (overflow > 0) {
            geometry.tileWidth = Math.max(iconSize + 18, preferredWidth - overflow / Math.cos(geometry.angle));
            bounds = bottomFanBounds(geometry);
        }
        if (bounds.right - bounds.left + padding * 2 <= availableWidth
                && bounds.bottom - bounds.top + padding * 2 <= availableHeight || shown === 0)
            break;
        --shown;
    } while (true);
    geometry.width = Math.min(availableWidth, Math.ceil(bounds.right - bounds.left + padding * 2));
    geometry.height = Math.min(availableHeight, Math.ceil(bounds.bottom - bounds.top + padding * 2));
    geometry.originX = padding - bounds.left;
    geometry.originY = geometry.height - padding - bounds.bottom;
    geometry.iconInset = geometry.width - geometry.originX;
    // ListView's logical viewport stays rectangular. Its delegates map their
    // fractional scroll positions onto the same curve as the fixed action.
    geometry.header = geometry.height - shown * step;
    return geometry;
}

function folderFan(edge, count, maximumWidth, maximumHeight, labelsLeft, requestedIconSize, maximumOutset) {
    const availableWidth = Math.max(0, maximumWidth);
    const availableHeight = Math.max(0, maximumHeight);
    const iconSize = Math.max(64, Math.round(requestedIconSize || 64));
    let geometry;
    if (edge === "bottom") {
        geometry = bottomFolderFan(count, availableWidth, Math.min(availableHeight, Math.max(iconSize + 24, availableHeight * 0.75)), iconSize, maximumOutset);
    } else {
        // Reserve a final tile for open/back on the same horizontal arc.
        // Keep labels close to their icons and include rotated corners in the bounds.
        const size = Math.max(1, Math.min(iconSize, (availableWidth - 32) / 1.5,
                                         (availableHeight - 68) / 1.4));
        const tileHeight = size + 38;
        const tilt = 10 * Math.PI / 180;
        const padding = Math.ceil(tileHeight * Math.sin(tilt) + 12);
        const tileWidth = Math.max(1, Math.min(Math.max(100, size + 32), availableWidth - padding * 2));
        const step = tileWidth + 12;
        let shown = Math.max(0, Math.min(count, 8,
            Math.floor((availableWidth - padding * 2 - tileWidth) / step)));
        if (count > shown && shown * step + tileWidth + padding * 2 + 24 > availableWidth)
            shown = Math.max(0, shown - 1);
        const stackReserve = count > shown && shown > 0 ? 24 : 0;
        const distance = shown * step + stackReserve;
        const outset = Math.max(0, Math.min(32, distance * Math.tan(tilt) / 2,
                                           availableHeight - tileHeight - padding * 2));
        geometry = {
            width: Math.min(availableWidth, distance + tileWidth + padding * 2),
            height: Math.min(availableHeight, tileHeight + outset + padding * 2),
            count: shown, step: step, header: 0, stackReserve: stackReserve,
            iconSize: size, iconInset: padding + tileWidth / 2,
            tileWidth: tileWidth, tileHeight: tileHeight, outset: outset,
            padding: padding, distance: distance, slots: []
        };
    }
    for (let i = 0; i < geometry.count; ++i)
        geometry.slots.push(folderFanSlot(edge, i, geometry, labelsLeft));
    return geometry;
}

function folderFanSlot(edge, position, geometry, labelsLeft) {
    if (edge === "bottom") {
        const distance = position * geometry.step + (position >= geometry.count ? geometry.stackReserve : 0);
        const angle = geometry.radius > 0 ? distance / geometry.radius : 0;
        const arcX = geometry.originX + geometry.radius * (1 - Math.cos(angle));
        const centerX = labelsLeft ? arcX : geometry.width - arcX;
        const iconOffset = geometry.iconSize / 2 + 6;
        const pivotX = labelsLeft ? geometry.tileWidth - iconOffset : iconOffset;
        return {x: centerX - pivotX,
                y: geometry.originY - (geometry.radius > 0 ? geometry.radius * Math.sin(angle) : distance) - geometry.tileHeight / 2,
                width: geometry.tileWidth, height: geometry.tileHeight,
                rotation: (labelsLeft ? 1 : -1) * angle * 180 / Math.PI};
    }
    const distance = position * geometry.step + (position >= geometry.count ? geometry.stackReserve : 0);
    const fraction = geometry.distance > 0 ? distance / geometry.distance : 0;
    const x = geometry.padding + distance;
    const angle = geometry.distance > 0
        ? Math.atan2(-2 * geometry.outset * fraction, geometry.distance) * 180 / Math.PI : 0;
    return {x: edge === "left" ? x : geometry.width - x - geometry.tileWidth,
            y: geometry.padding + geometry.outset * (1 - fraction * fraction),
            width: geometry.tileWidth, height: geometry.tileHeight,
            rotation: edge === "left" ? angle : -angle};
}
