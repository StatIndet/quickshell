import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

RippleButton {
    id: root

    property bool filled: false
    property string iconName: ""
    property color contentColor: root.filled ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary

    implicitWidth: Math.max(64, actionContent.implicitWidth + Metrics.spacingL * 2)
    implicitHeight: Metrics.controlHeightM
    leftPadding: Metrics.spacingM
    rightPadding: Metrics.spacingM
    buttonRadius: Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.full
    containerColor: root.filled ? Appearance.colors.colPrimary : "transparent"
    rippleColor: root.filled ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
    stateLayerColor: root.filled ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary
    hoverStateLayerColor: root.filled ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary
    pressedStateLayerColor: root.filled ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimary
    stateLayerOpacity: root.filled ? 1 : Appearance.interaction.hoverStateLayerOpacity
    pressedStateLayerOpacity: root.filled ? 1 : Appearance.interaction.pressedStateLayerOpacity
    focusStateLayerOpacity: root.filled ? 1 : Appearance.interaction.focusStateLayerOpacity
    focusPolicy: Qt.StrongFocus
    Accessible.name: root.text

    contentItem: Item {
        implicitWidth: actionContent.implicitWidth
        implicitHeight: actionContent.implicitHeight

        RowLayout {
            id: actionContent

            anchors.centerIn: parent
            spacing: Metrics.spacingXS

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: root.iconName !== ""
                text: root.iconName
                iconSize: Metrics.iconS + Metrics.spacingXXS
                color: root.contentColor
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.text
                color: root.contentColor
                font.family: Typography.labelLarge.family
                font.pixelSize: Typography.labelLarge.pixelSize
                font.weight: Typography.labelLarge.weight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

        }

    }

}
