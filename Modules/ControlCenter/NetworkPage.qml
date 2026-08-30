import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property var parentModal: null
    property var passwordTarget: null
    readonly property var nearbyNetworks: NetworkService.nearbyWifiNetworks.filter((network) => {
        return !network.active;
    })
    readonly property var activeNetwork: NetworkService.activeNetwork
    readonly property string activeConnectionKey: activeNetwork ? [activeNetwork.type, activeNetwork.deviceName, activeNetwork.name].join(":") : ""
    readonly property bool runtimeMatchesActive: activeNetwork !== null && NetworkService.runtimeDetails.interfaceName === String(activeNetwork.deviceName || "")

    function connectionStatus() {
        if (!NetworkService.connected)
            return qsTr("未连接");

        if (NetworkService.internetAvailable)
            return qsTr("已连接 · Internet 可用");

        if (NetworkService.captivePortal)
            return qsTr("已连接 · 需要登录");

        if (NetworkService.limitedConnectivity)
            return qsTr("已连接 · 连接受限");

        return qsTr("已连接");
    }

    function profileForTarget(target) {
        if (!target)
            return null;

        let profiles = [];
        if (target.nativeSettings) {
            profiles = target.type === "wired" ? NetworkService.wiredProfiles : NetworkService.savedWifiProfiles;
            return profiles.find((profile) => {
                return profile.uuid === target.uuid;
            }) || null;
        }
        if (target.type === "wired") {
            const interfaceName = String(target.deviceName || target.name || "");
            profiles = NetworkService.wiredProfiles.filter((profile) => {
                return profile.deviceName === interfaceName;
            });
        } else {
            profiles = target.profiles || [];
        }
        if (profiles.length === 0)
            return null;

        const activeUuid = root.runtimeMatchesActive ? String(NetworkService.runtimeDetails.connectionUuid || "") : "";
        const activeProfile = profiles.find((profile) => {
            return activeUuid.length > 0 && profile.uuid === activeUuid;
        }) || null;
        if (activeProfile)
            return activeProfile;

        return profiles.length === 1 || !target.connected ? profiles[0] : null;
    }

    function wiredDeviceForProfile(profile) {
        if (!profile)
            return null;

        return NetworkService.wiredDevices.find((device) => {
            return device.deviceName === profile.deviceName;
        }) || null;
    }

    function refreshRuntimeDetails() {
        if (root.activeNetwork && String(root.activeNetwork.deviceName || "").length > 0)
            NetworkService.requestRuntimeDetails(root.activeNetwork);
        else
            NetworkService.releaseRuntimeDetails();
    }

    function openProfile(target) {
        const profile = root.profileForTarget(target);
        if (profile)
            configWindow.openProfile(profile, "");

    }

    function closeChildWindows() {
        configWindow.dismiss();
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2
    onActiveConnectionKeyChanged: root.refreshRuntimeDetails()
    Component.onCompleted: {
        NetworkService.acquireScan("control-center-network");
        root.refreshRuntimeDetails();
    }
    Component.onDestruction: {
        nearbyPassword.text = "";
        root.passwordTarget = null;
        NetworkService.releaseRuntimeDetails();
        NetworkService.releaseScan("control-center-network");
    }

    Connections {
        function onOperationSucceeded(operation) {
            if (operation === "connect" || operation === "disconnect")
                root.refreshRuntimeDetails();

        }

        function onProfileWriteSucceeded(uuid) {
            root.refreshRuntimeDetails();
        }

        target: NetworkService
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
            title: qsTr("当前连接")
            iconName: root.activeNetwork && root.activeNetwork.type === "wired" ? "lan" : "wifi"

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: root.activeNetwork === null
                message: qsTr("当前没有活动网络连接")
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null
                iconName: root.activeNetwork && root.activeNetwork.type === "wired" ? "settings_ethernet" : "wifi"
                title: root.activeNetwork ? root.activeNetwork.name : ""
                supportingText: root.connectionStatus()
                highlighted: NetworkService.connected

                trailing: MaterialLoadingIndicator {
                    implicitWidth: Metrics.controlHeightS
                    implicitHeight: Metrics.controlHeightS
                    contained: false
                    visible: NetworkService.runtimeDetailsLoading
                }

            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: NetworkService.runtimeDetailsError.length > 0
                tone: "error"
                message: NetworkService.runtimeDetailsError
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null
                title: qsTr("接口")
                supportingText: root.activeNetwork ? root.activeNetwork.deviceName : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null
                title: qsTr("IP 地址")
                supportingText: root.runtimeMatchesActive && NetworkService.runtimeDetails.addresses ? NetworkService.runtimeDetails.addresses.join(", ") : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null
                title: qsTr("Gateway")
                supportingText: root.runtimeMatchesActive ? NetworkService.runtimeDetails.gateway || "—" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null
                title: qsTr("DNS")
                supportingText: root.runtimeMatchesActive && NetworkService.runtimeDetails.dns ? NetworkService.runtimeDetails.dns.join(", ") : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null
                title: qsTr("连接 UUID")
                supportingText: root.runtimeMatchesActive ? NetworkService.runtimeDetails.connectionUuid || "—" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null
                title: qsTr("MAC")
                supportingText: root.activeNetwork ? root.activeNetwork.address || "—" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null && root.activeNetwork.type === "wifi"
                title: qsTr("信号与安全")
                supportingText: root.activeNetwork ? qsTr("%1% · %2").arg(root.activeNetwork.strength).arg(root.activeNetwork.security || qsTr("未知")) : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null && root.activeNetwork.type === "wifi"
                title: qsTr("频率")
                supportingText: root.runtimeMatchesActive ? NetworkService.runtimeDetails.frequency || "—" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null && root.activeNetwork.type === "wired"
                title: qsTr("链路")
                supportingText: root.activeNetwork && root.activeNetwork.hasLink ? qsTr("已连接 · %1 Mbps").arg(root.activeNetwork.linkSpeed || "—") : qsTr("网线未连接")
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            visible: NetworkService.wiredDevices.length > 0
            title: qsTr("Ethernet")
            iconName: "lan"

            Repeater {
                model: NetworkService.wiredProfiles

                SettingsRow {
                    id: wiredRow

                    required property var modelData
                    readonly property var device: root.wiredDeviceForProfile(wiredRow.modelData)

                    Layout.fillWidth: true
                    iconName: "settings_ethernet"
                    title: wiredRow.modelData.name || wiredRow.modelData.deviceName || qsTr("有线网络")
                    supportingText: wiredRow.device && wiredRow.device.connected ? qsTr("%1 · 已连接 · %2 Mbps").arg(wiredRow.modelData.deviceName).arg(wiredRow.device.linkSpeed || "—") : wiredRow.device && wiredRow.device.hasLink ? qsTr("%1 · 可连接").arg(wiredRow.modelData.deviceName) : qsTr("%1 · 网线未连接").arg(wiredRow.modelData.deviceName)
                    interactive: true
                    highlighted: wiredRow.device ? wiredRow.device.connected : false
                    onClicked: configWindow.openProfile(wiredRow.modelData, "")

                    trailing: MaterialSymbol {
                        text: "chevron_right"
                        iconSize: Metrics.iconS
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                }

            }

            Repeater {
                model: NetworkService.wiredProfiles.length === 0 ? NetworkService.wiredDevices : []

                SettingsRow {
                    id: unconfiguredWiredRow

                    required property var modelData

                    Layout.fillWidth: true
                    iconName: "settings_ethernet"
                    title: unconfiguredWiredRow.modelData.name || qsTr("有线网络")
                    supportingText: unconfiguredWiredRow.modelData.hasLink ? qsTr("没有可编辑的 NetworkManager 配置") : qsTr("网线未连接 · 没有可编辑配置")
                    interactive: false
                    highlighted: unconfiguredWiredRow.modelData.connected
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
                interactive: root.profileForTarget(NetworkService.activeWifi) !== null
                highlighted: true
                onClicked: root.openProfile(NetworkService.activeWifi)

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

            StyledListView {
                id: nearbyList

                readonly property real rowHeight: Metrics.controlHeightXL + Metrics.spacingS
                readonly property real maximumViewportHeight: rowHeight * 6 + spacing * 5

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.max(0, contentHeight), maximumViewportHeight)
                visible: NetworkService.wifiEnabled && count > 0
                model: root.nearbyNetworks
                spacing: Metrics.spacingXS
                boundsBehavior: Flickable.StopAtBounds
                fasterTouchpadScroll: true
                showVerticalScrollBar: true
                animateMovement: true

                delegate: SettingsRow {
                    id: wifiRow

                    required property var modelData

                    width: ListView.view.width
                    height: nearbyList.rowHeight
                    iconName: wifiRow.modelData.strength >= 70 ? "signal_wifi_4_bar" : wifiRow.modelData.strength >= 35 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                    title: wifiRow.modelData.ssid
                    supportingText: (wifiRow.modelData.isSecure ? qsTr("安全") : qsTr("开放")) + (wifiRow.modelData.known ? qsTr(" · 已保存") : "") + qsTr(" · %1% · %2").arg(wifiRow.modelData.strength).arg(wifiRow.modelData.deviceName)
                    interactive: !NetworkService.busy
                    highlighted: false
                    onClicked: {
                        if (wifiRow.modelData.isSecure && !wifiRow.modelData.known)
                            root.passwordTarget = wifiRow.modelData;
                        else
                            NetworkService.connectToWifiNetwork(wifiRow.modelData);
                    }

                    trailing: MaterialSymbol {
                        text: wifiRow.modelData.isSecure ? "lock" : "login"
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
                visible: NetworkService.wifiEnabled && !NetworkService.wifiScanning && root.nearbyNetworks.length === 0
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
                onClicked: configWindow.openSavedNetworks()
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "add"
                text: qsTr("添加网络")
                description: qsTr("手动添加 SSID 或隐藏网络")
                trailingIconName: "chevron_right"
                onClicked: configWindow.openAddNetwork()
            }

        }

    }

    NetworkConfigWindow {
        id: configWindow

        parentModal: root.parentModal
    }

}
