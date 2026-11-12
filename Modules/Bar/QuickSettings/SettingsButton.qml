import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    id: root

    property var screen: null
    readonly property bool active: WidgetState.quickSettingsOpen && WidgetState.quickSettingsView
                                   === "settings"

    iconName: "settings"
    selected: root.active
    containerColor: "transparent"
    rippleColor: BarColors.foreground
    iconColor: BarColors.foreground
    tooltipText: qsTr("Left click: Quick Settings\nRight click: Control Center")
    onClicked: {
        if (root.screen && root.screen.name)
            WidgetState.quickSettingsScreenName = root.screen.name;

        if (root.active) {
            WidgetState.quickSettingsOpen = false;
        } else {
            WidgetState.quickSettingsView = "settings";
            WidgetState.quickSettingsOpen = true;
        }
    }
    onAltClicked: ControlCenterService.openOrFocus()
}
