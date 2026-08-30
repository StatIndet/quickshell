import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property var passwordTarget: null

    signal sectionRequested(string section)
    signal detailRequested(var target)

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2
    Component.onCompleted: NetworkService.acquireScan("control-center-network")
    Component.onDestruction: {
        nearbyPassword.text = "";
        root.passwordTarget = null;
        NetworkService.releaseScan("control-center-network");
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: !NetworkService.available || NetworkService.lastError.length > 0
            tone: "error"
            message: NetworkService.lastError.length > 0 ? NetworkService.lastError : qsTr("NetworkManager 后端不可用")
        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            visible: NetworkService.wiredDevices.length > 0
            title: qsTr("Ethernet")
            iconName: "lan"

            Repeater {
                model: NetworkService.wiredDevices

                SettingsRow {
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: "settings_ethernet"
                    title: modelData.name || qsTr("有线网络")
                    supportingText: modelData.connected ? qsTr("已连接 · %1 Mbps").arg(modelData.linkSpeed || "—") : modelData.hasLink ? qsTr("可连接") : qsTr("网线未连接")
                    interactive: true
                    highlighted: modelData.connected
                    onClicked: root.detailRequested(modelData)

                    trailing: MaterialSymbol {
                        text: "chevron_right"
                        iconSize: Metrics.iconS
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("Wi-Fi")
            iconName: "wifi"

            SettingsRow {
                Layout.fillWidth: true
                iconName: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
                title: qsTr("Wi-Fi")
                supportingText: !NetworkService.wifiAvailable ? qsTr("未检测到无线网卡") : !NetworkService.wifiHardwareEnabled ? qsTr("已被硬件开关阻止") : NetworkService.wifiEnabled ? qsTr("已开启") : qsTr("已关闭")

                trailing: StyledSwitch {
                    checked: NetworkService.wifiEnabled
                    enabled: NetworkService.available && NetworkService.wifiAvailable && NetworkService.wifiHardwareEnabled && !NetworkService.busy
                    onToggled: NetworkService.setWifiEnabled(checked)
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                visible: NetworkService.activeWifi !== null
                iconName: "wifi"
                title: NetworkService.activeWifi ? NetworkService.activeWifi.ssid : ""
                supportingText: qsTr("当前网络 · 信号 %1%").arg(NetworkService.signalStrength)
                interactive: true
                highlighted: true
                onClicked: root.detailRequested(NetworkService.activeWifi)

                trailing: MaterialSymbol {
                    text: "settings"
                    iconSize: Metrics.iconS
                    color: Appearance.colors.colOnSurfaceVariant
                }

            }

            RowLayout {
                Layout.fillWidth: true
                visible: NetworkService.wifiEnabled

                Text {
                    Layout.fillWidth: true
                    text: qsTr("附近网络")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                MaterialLoadingIndicator {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    contained: false
                    visible: NetworkService.wifiScanning
                }

                ActionButton {
                    text: qsTr("扫描")
                    iconName: "refresh"
                    enabled: !NetworkService.busy
                    onClicked: NetworkService.requestScan()
                }

            }

            Repeater {
                model: NetworkService.nearbyWifiNetworks.filter((network) => {
                    return !network.active;
                })

                SettingsRow {
                    id: wifiRow

                    required property var modelData

                    Layout.fillWidth: true
                    visible: NetworkService.wifiEnabled
                    iconName: modelData.strength >= 70 ? "signal_wifi_4_bar" : modelData.strength >= 35 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                    title: modelData.ssid
                    supportingText: (modelData.isSecure ? qsTr("安全") : qsTr("开放")) + (modelData.known ? qsTr(" · 已保存") : "") + qsTr(" · %1% · %2").arg(modelData.strength).arg(modelData.deviceName)
                    interactive: !NetworkService.busy
                    highlighted: modelData.active
                    onClicked: {
                        if (wifiRow.modelData.active)
                            root.detailRequested(wifiRow.modelData);
                        else if (wifiRow.modelData.isSecure && !wifiRow.modelData.known)
                            root.passwordTarget = wifiRow.modelData;
                        else
                            NetworkService.connectToWifiNetwork(wifiRow.modelData);
                    }

                    trailing: MaterialSymbol {
                        text: wifiRow.modelData.active ? "settings" : wifiRow.modelData.isSecure ? "lock" : "login"
                        iconSize: Metrics.iconS
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.passwordTarget !== null
                spacing: Metrics.spacingXS

                MaterialTextField {
                    id: nearbyPassword

                    Layout.fillWidth: true
                    labelText: root.passwordTarget ? qsTr("%1 的密码").arg(root.passwordTarget.ssid) : qsTr("密码")
                    echoMode: TextInput.Password
                    error: text.length > 0 && text.length < 8
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    ActionButton {
                        text: qsTr("取消")
                        onClicked: {
                            nearbyPassword.text = "";
                            root.passwordTarget = null;
                        }
                    }

                    ActionButton {
                        text: qsTr("连接")
                        filled: true
                        enabled: nearbyPassword.text.length >= 8 && !NetworkService.busy
                        onClicked: {
                            NetworkService.changePassword(root.passwordTarget, nearbyPassword.text);
                            nearbyPassword.text = "";
                            root.passwordTarget = null;
                        }
                    }

                }

            }

            Text {
                Layout.fillWidth: true
                visible: NetworkService.wifiEnabled && !NetworkService.wifiScanning && NetworkService.nearbyWifiNetworks.length === 0
                text: qsTr("未找到附近网络")
                color: Appearance.colors.colOutline
                horizontalAlignment: Text.AlignHCenter
                font.family: Typography.bodyMedium.family
                font.pixelSize: Typography.bodyMedium.pixelSize
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("其他设置")
            iconName: "tune"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "bookmark"
                text: qsTr("已保存网络")
                description: qsTr("%1 个 NetworkManager 配置").arg(NetworkService.savedWifiProfiles.length)
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("network-saved")
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "add"
                text: qsTr("添加网络")
                description: qsTr("手动添加 SSID 或隐藏网络")
                trailingIconName: "chevron_right"
                onClicked: root.sectionRequested("network-add")
            }

        }

    }

}
