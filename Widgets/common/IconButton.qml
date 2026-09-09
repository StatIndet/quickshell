import QtQuick
import qs.Common
import qs.Components

RippleButton {
    id: root

    property string iconName: ""
    property string selectedIconName: ""
    property string accessibleName: ""
    property string tooltipText: ""
    property string variant: "standard"
    property bool selected: false
    property bool disabledHoverFeedback: false
    readonly property string effectiveAccessibleName: accessibleName.length > 0 ? accessibleName : tooltipText
    readonly property string effectiveTooltipText: tooltipText.length > 0 ? tooltipText : accessibleName
    property bool showTooltip: effectiveTooltipText.length > 0
    property real controlSize: Metrics.controlHeightM
    property real iconSize: Metrics.iconM
    property real iconFill: selected ? 1 : 0
    property real iconRotation: 0
    property color iconColor: root.variant === "filled" ? Appearance.colors.colOnPrimary : root.variant
                                                          === "tonal"
                                                          ? Appearance.colors.colOnSecondaryContainer :
                                                            Appearance.colors.colOnSurfaceVariant
    property color selectedIconColor: root.variant === "filled" ? Appearance.colors.colOnPrimary :
                                                                  root.variant === "tonal"
                                                                  ? Appearance.colors.colOnSecondaryContainer :
                                                                    Appearance.colors.colPrimary
    property color normalContainerColor: root.variant === "filled" ? Appearance.colors.colPrimary :
                                                                     root.variant === "tonal"
                                                                     ? Appearance.colors.colSecondaryContainer :
                                                                       "transparent"
    property color selectedContainerColor: root.variant === "standard" || root.variant === "outlined"
                                           ? "transparent" : root.normalContainerColor
    property color normalHoverStateLayerColor: root.variant === "filled" ? Appearance.colors.colPrimaryHover :
                                                                           root.variant === "tonal"
                                                                           ? Appearance.colors.colSecondaryContainerHover :
                                                                             Appearance.applyAlpha(
                                                                                 root.iconColor, 0.08)
    property color normalPressedStateLayerColor: root.variant === "filled"
                                                 ? Appearance.colors.colPrimaryActive : root.variant
                                                   === "tonal"
                                                   ? Appearance.colors.colSecondaryContainerActive :
                                                     Appearance.applyAlpha(root.iconColor, 0.12)
    property color selectedHoverStateLayerColor: root.variant === "standard" || root.variant === "outlined"
                                                 ? Appearance.applyAlpha(root.selectedIconColor, 0.08) :
                                                   root.normalHoverStateLayerColor
    property color selectedPressedStateLayerColor: root.variant === "standard" || root.variant === "outlined"
                                                   ? Appearance.applyAlpha(root.selectedIconColor, 0.12) :
                                                     root.normalPressedStateLayerColor
    property color outlineColor: Appearance.colors.colOutline
    readonly property alias iconItem: iconGlyph
    readonly property color effectiveContainerColor: root.selected ? root.selectedContainerColor :
                                                                     root.normalContainerColor
    readonly property color effectiveHoverStateLayerColor: root.selected ? root.selectedHoverStateLayerColor :
                                                                           root.normalHoverStateLayerColor
    readonly property color effectivePressedStateLayerColor: root.selected
                                                             ? root.selectedPressedStateLayerColor :
                                                               root.normalPressedStateLayerColor

    implicitWidth: root.controlSize
    implicitHeight: root.controlSize
    padding: 0
    toggled: root.selected
    buttonRadius: Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.full
    containerColor: root.effectiveContainerColor
    rippleColor: root.selected ? root.selectedIconColor : root.iconColor
    stateLayerColor: root.effectiveHoverStateLayerColor
    hoverStateLayerColor: root.effectiveHoverStateLayerColor
    focusStateLayerColor: root.effectiveHoverStateLayerColor
    pressedStateLayerColor: root.effectivePressedStateLayerColor
    stateLayerOpacity: 1
    focusStateLayerOpacity: 1
    pressedStateLayerOpacity: 1
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.effectiveAccessibleName
    Accessible.role: Accessible.Button

    HoverHandler {
        id: disabledHover
        enabled: root.disabledHoverFeedback && !root.enabled
        cursorShape: Qt.ForbiddenCursor
    }

    StyledToolTip {
        text: root.effectiveTooltipText
        extraVisibleCondition: root.showTooltip && (root.pointerHovered || root.visualFocus
                                                    || disabledHover.hovered)
    }

    backgroundContent: Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: "transparent"
        border.width: root.variant === "outlined" ? Metrics.dividerWidth : 0
        border.color: root.outlineColor
    }

    contentItem: MaterialSymbol {
        id: iconGlyph

        text: root.selected && root.selectedIconName.length > 0 ? root.selectedIconName : root.iconName
        iconSize: root.iconSize
        fill: root.iconFill
        color: root.selected ? root.selectedIconColor : root.iconColor
        rotation: root.iconRotation
    }
}
