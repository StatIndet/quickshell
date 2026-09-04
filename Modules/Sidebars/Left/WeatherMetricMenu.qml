import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Popup {
    id: root

    required property Item anchorItem
    property var options: []
    property int selectedValue: -1
    property bool openAbove: false

    signal valueSelected(int value)

    parent: root.anchorItem
    x: root.anchorItem.width - width
    y: root.openAbove ? -height - Metrics.spacingXS : root.anchorItem.height + Metrics.spacingXS
    width: 232
    height: implicitHeight
    padding: Metrics.spacingXS
    modal: false
    dim: false
    focus: true
    transformOrigin: root.openAbove ? Item.BottomRight : Item.TopRight
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    onOpened: {
        if (menuRepeater.count > 0)
            menuRepeater.itemAt(0).forceActiveFocus();

    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "scale"
                from: 0.94
                to: 1
                duration: 200
                easing.type: Easing.OutCubic
            }

        }

    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 120
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.96
                duration: 120
                easing.type: Easing.InCubic
            }

        }

    }

    background: Rectangle {
        radius: Appearance.rounding.small
        color: Appearance.m3colors.m3surfaceContainerHigh
        opacity: 1
        border.width: Metrics.dividerWidth
        border.color: Appearance.m3colors.m3outlineVariant
    }

    contentItem: ColumnLayout {
        spacing: 0

        Repeater {
            id: menuRepeater

            model: root.options

            delegate: RippleButton {
                required property int index
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.touchTarget
                buttonRadius: Appearance.rounding.small
                buttonRadiusPressed: Appearance.rounding.medium
                toggled: root.selectedValue === Number(modelData.value)
                selectedStateLayerEnabled: toggled
                containerColor: "transparent"
                stateLayerColor: Appearance.colors.colOnSurface
                hoverStateLayerColor: Appearance.colors.colOnSurface
                focusStateLayerColor: Appearance.colors.colOnSurface
                pressedStateLayerColor: Appearance.colors.colOnSurface
                selectedStateLayerColor: Appearance.m3colors.m3secondaryContainer
                stateLayerOpacity: Appearance.interaction.hoverStateLayerOpacity
                focusStateLayerOpacity: Appearance.interaction.focusStateLayerOpacity
                pressedStateLayerOpacity: Appearance.interaction.pressedStateLayerOpacity
                selectedStateLayerOpacity: 1
                rippleColor: Appearance.colors.colOnSurface
                Accessible.name: modelData.label
                KeyNavigation.up: menuRepeater.itemAt(index > 0 ? index - 1 : menuRepeater.count - 1)
                KeyNavigation.down: menuRepeater.itemAt(index + 1 < menuRepeater.count ? index + 1 : 0)
                onClicked: {
                    root.valueSelected(Number(modelData.value));
                    root.close();
                }

                contentItem: RowLayout {
                    spacing: Metrics.spacingM

                    MaterialSymbol {
                        Layout.leftMargin: Metrics.spacingS
                        text: modelData.icon
                        iconSize: Metrics.iconM
                        fill: root.selectedValue === Number(modelData.value) ? 1 : 0
                        color: root.selectedValue === Number(modelData.value) ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        color: root.selectedValue === Number(modelData.value) ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
                        font.family: Typography.labelLarge.family
                        font.pixelSize: Typography.labelLarge.pixelSize
                        font.weight: Typography.labelLarge.weight
                        textFormat: Text.PlainText
                    }

                    MaterialSymbol {
                        Layout.rightMargin: Metrics.spacingS
                        text: "check"
                        iconSize: Metrics.iconS
                        fill: 1
                        visible: root.selectedValue === Number(modelData.value)
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                }

            }

        }

    }

}
