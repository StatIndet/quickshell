import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    signal sectionRequested(string section)

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Interface")
            iconName: "dashboard"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "dock_to_bottom"
                text: qsTr("Bar")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("bar")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "side_navigation"
                text: qsTr("Sidebar")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("sidebar")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "search"
                text: "Spotlight"
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("spotlight")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "blur_on"
                text: qsTr("Transparency and blur")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("effects")
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("System")
            iconName: "settings_suggest"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "language"
                text: qsTr("Language & region")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("language-region")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "wifi"
                text: qsTr("Network")
                description: NetworkService.available ? NetworkService.activeConnection : qsTr(
                                                            "Network unavailable")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("network")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "devices_other"
                text: qsTr("Connected devices")
                description: {
                    if (!BluetoothService.available)
                        return qsTr("Bluetooth unavailable");

                    if (!BluetoothService.enabled)
                        return qsTr("Bluetooth is off");

                    if (BluetoothService.connectedDevices.length === 1)
                        return BluetoothService.connectedDevices[0].name;

                    if (BluetoothService.connectedDevices.length > 1)
                        return qsTr("%1 devices connected").arg(BluetoothService.connectedDevices.length);

                    return "";
                }
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("connected-devices")
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Applications")
            iconName: "apps"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "rocket_launch"
                text: qsTr("Autostart")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("autostart")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "apps"
                text: qsTr("Default applications")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("default-apps")
            }
        }
    }
}
