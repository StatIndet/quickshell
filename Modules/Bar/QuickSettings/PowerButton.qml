import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    id: root

    property var screen: null

    iconName: "power_settings_new"
    containerColor: "transparent"
    rippleColor: BarColors.foreground
    iconColor: BarColors.foreground
    tooltipText: qsTr("Power menu")
    onClicked: PowerMenuService.open(root.screen)
}
