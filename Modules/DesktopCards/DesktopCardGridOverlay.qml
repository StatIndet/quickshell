import QtQuick
import qs.Common
import "./DesktopCardLayout.js" as DesktopCardLayout

Item {
    id: root

    property bool active: false
    property var highlightRect: null
    readonly property var metrics: DesktopCardLayout.gridMetrics(width, height)

    visible: opacity > 0
    opacity: active ? 1 : 0

    Repeater {
        model: root.active ? root.metrics.columns * root.metrics.rows : 0

        delegate: Rectangle {
            required property int index
            readonly property int column: index % root.metrics.columns
            readonly property int row: Math.floor(index / root.metrics.columns)

            x: root.metrics.originX + column * root.metrics.columnPitch
            y: root.metrics.originY + row * root.metrics.rowPitch
            width: root.metrics.cellWidth
            height: root.metrics.cellHeight
            radius: Metrics.cornerS
            color: "transparent"
            border.width: Metrics.dividerWidth
            border.color: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.42)
        }

    }

    Rectangle {
        visible: root.active && root.highlightRect !== null
        x: root.highlightRect ? Number(root.highlightRect.x) : 0
        y: root.highlightRect ? Number(root.highlightRect.y) : 0
        width: root.highlightRect ? Number(root.highlightRect.width) : 0
        height: root.highlightRect ? Number(root.highlightRect.height) : 0
        radius: Appearance.rounding.extraLarge
        color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.14)
        border.width: 2
        border.color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.82)
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }

    }

}
