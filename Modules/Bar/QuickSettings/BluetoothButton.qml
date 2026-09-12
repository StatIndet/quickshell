import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

BarCircularButton {
    id: root

    property var screen: null
    readonly property bool active: WidgetState.quickSettingsOpen && WidgetState.quickSettingsView
                                   === "bluetooth"

    iconName: BluetoothService.connected ? "bluetooth_connected" : BluetoothService.enabled ? "bluetooth" :
                                                                                              "bluetooth_disabled"
    selected: root.active
    enabled: BluetoothService.available
    containerColor: Appearance.colors.colSecondaryContainer
    rippleColor: Appearance.colors.colOnSecondaryContainer
    iconColor: Appearance.colors.colOnSecondaryContainer
    tooltipText: BluetoothService.connected ? (BluetoothService.connectedName || qsTr("Bluetooth connected")) :
                                              BluetoothService.enabled ? qsTr("Bluetooth on") : qsTr(
                                                                             "Bluetooth off")
    onClicked: {
        if (root.screen && root.screen.name)
            WidgetState.quickSettingsScreenName = root.screen.name;

        if (root.active) {
            WidgetState.quickSettingsOpen = false;
        } else {
            WidgetState.quickSettingsView = "bluetooth";
            WidgetState.quickSettingsOpen = true;
        }
    }
}
