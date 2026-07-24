import QtQuick
Text {
    id: root

    property real iconSize: 22
    property real fill: 0
    readonly property real roundedFill: Number(fill).toFixed(1)
    // Qt creates a new variable-font face for every distinct pixel/opsz
    // combination. Continuously animated values therefore retain thousands
    // of mappings for the 14 MiB Material Symbols font. Keep the rendered
    // font on a small, stable set of values; geometry can animate around it.
    readonly property int renderedIconSize:
        Math.max(1, Math.round(root.iconSize))
    readonly property int opticalSize: {
        if (root.renderedIconSize <= 20)
            return 20;
        if (root.renderedIconSize <= 28)
            return 24;
        if (root.renderedIconSize <= 44)
            return 40;
        return 48;
    }

    renderType: Text.NativeRendering
    font {
        family: "Material Symbols Rounded"
        pixelSize: root.renderedIconSize
        weight: Font.Normal + (Font.DemiBold - Font.Normal) * root.roundedFill
        variableAxes: {
            "FILL": root.roundedFill,
            "opsz": root.opticalSize
        }
    }
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
