import QtQuick
import qs.Common

ActionButton {
    id: root

    property bool vertical: false
    property bool expandedContent: true
    property real contentPadding: Sizes.barLabelSpacing

    contentColor: BarColors.foreground
    rippleColor: BarColors.foreground
    stateLayerColor: BarColors.foreground
    hoverStateLayerColor: BarColors.foreground
    pressedStateLayerColor: BarColors.foreground

    // Compact icon controls keep a 28px slot. Text and grouped content use
    // 6px of padding along the bar's main axis.
    leftPadding: !vertical && expandedContent ? root.contentPadding : 0
    rightPadding: leftPadding
    topPadding: vertical && expandedContent ? root.contentPadding : 0
    bottomPadding: topPadding
    implicitWidth: Math.max(Sizes.barControlCircleSize, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(Sizes.barControlCircleSize, implicitContentHeight + topPadding + bottomPadding)
}
