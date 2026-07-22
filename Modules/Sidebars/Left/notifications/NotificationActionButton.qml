import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.Common
import qs.Widgets.common

MaterialRippleButton {
    id: root

    property string iconName: ""
    property string urgency: NotificationUrgency.Normal.toString()
    readonly property bool critical: urgency === NotificationUrgency.Critical
        || urgency === NotificationUrgency.Critical.toString()
    readonly property bool iconOnly: iconName !== "" && buttonText === ""

    implicitHeight: 34
    implicitWidth: iconOnly ? 40 : Math.max(64, contentItem.implicitWidth + 30)
    buttonRadius: Appearance.rounding.small
    buttonRadiusPressed: Appearance.rounding.small
    rippleDuration: 1200
    rippleFadeDuration: 2400
    rippleOpacity: 1
    colBackground: critical ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer4
    colBackgroundHover: critical ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer4Hover
    colRipple: critical ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer4Active

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        RowLayout {
            id: contentRow

            anchors.centerIn: parent
            spacing: 6

            Text {
                visible: root.iconName !== ""
                text: root.iconName
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
                color: root.critical
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnLayer4
            }

            Text {
                visible: root.buttonText !== ""
                text: root.buttonText
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                color: root.critical
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnLayer4
            }
        }
    }
}
