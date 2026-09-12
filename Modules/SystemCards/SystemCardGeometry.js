.pragma library

// The catalog size presets are shared by every SystemCard surface.
// Desktop cards deliberately use these same dimensions; wallpaper placement
// changes the coordinate system, not the card's visual scale.
Qt.include("SystemCardCatalog.js");

var baseCellWidth = 152;
var baseCellHeight = 160;
var cellGap = 8;

function widthForSpan(columnSpan) {
    var span = Math.max(1, Math.round(Number(columnSpan) || 1));
    return span * baseCellWidth + (span - 1) * cellGap;
}

function heightForSpan(rowSpan) {
    var span = Math.max(1, Math.round(Number(rowSpan) || 1));
    return span * baseCellHeight + (span - 1) * cellGap;
}

function sizeFor(id) {
    var definition = definitionFor(String(id));
    if (!definition)
        return { width: baseCellWidth, height: baseCellHeight };
    return {
        width: widthForSpan(definition.columnSpan),
        height: heightForSpan(definition.rowSpan)
    };
}

function widthFor(id) {
    return sizeFor(id).width;
}

function heightFor(id) {
    return sizeFor(id).height;
}
