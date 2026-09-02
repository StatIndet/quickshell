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
            title: qsTr("界面")
            iconName: "dashboard"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "dock_to_bottom"
                text: qsTr("条栏")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("bar")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "side_navigation"
                text: qsTr("侧边栏")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("sidebar")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "blur_on"
                text: qsTr("透明与模糊")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("effects")
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("系统")
            iconName: "settings_suggest"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "language"
                text: qsTr("语言与地区")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("language-region")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "wifi"
                text: qsTr("网络")
                description: NetworkService.available ? NetworkService.activeConnection : qsTr("NetworkManager 不可用")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("network")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "devices_other"
                text: qsTr("连接的设备")
                description: {
                    if (!BluetoothService.available)
                        return qsTr("蓝牙不可用");

                    if (!BluetoothService.enabled)
                        return qsTr("蓝牙已关闭");

                    if (BluetoothService.connectedDevices.length === 1)
                        return BluetoothService.connectedDevices[0].name;

                    if (BluetoothService.connectedDevices.length > 1)
                        return qsTr("%1 台设备已连接").arg(BluetoothService.connectedDevices.length);

                    return "";
                }
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("connected-devices")
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("应用")
            iconName: "apps"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "rocket_launch"
                text: qsTr("开机启动")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("autostart")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "apps"
                text: qsTr("默认应用")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("default-apps")
            }

        }

    }

}
