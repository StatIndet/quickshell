import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    id: root

    property var screen: null

    iconName: "power_settings_new"
    containerColor: Appearance.colors.colError
    rippleColor: Appearance.colors.colOnError
    iconColor: Appearance.colors.colOnError
    tooltipText: qsTr("电源菜单")
    onClicked: PowerMenuService.open(root.screen)
}
