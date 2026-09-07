import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    id: root

    property var screen: null
    readonly property bool active: WidgetState.qsOpen && WidgetState.qsView === "settings"

    iconName: "settings"
    selected: root.active
    containerColor: Appearance.colors.colPrimaryContainer
    rippleColor: Appearance.colors.colOnPrimaryContainer
    iconColor: Appearance.colors.colOnPrimaryContainer
    tooltipText: qsTr("Left click: Quick Settings\nRight click: Control Center")
    onClicked: {
        if (root.screen && root.screen.name)
            WidgetState.qsScreenName = root.screen.name;

        if (root.active) {
            WidgetState.qsOpen = false;
        } else {
            WidgetState.qsView = "settings";
            WidgetState.qsOpen = true;
        }
    }
    onAltClicked: ControlCenterService.open()
}
