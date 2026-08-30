import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property var target: null
    readonly property bool isWired: target && target.type === "wired"
    readonly property string targetInterface: String(target ? target.deviceName || target.name || "" : "")
    readonly property bool runtimeMatchesInterface: NetworkService.runtimeDetails.interfaceName === targetInterface
    property bool profileRemoved: false
    readonly property var profile: {
        if (!target || profileRemoved)
            return null;

        if (target.nativeSettings) {
            const profiles = isWired ? NetworkService.wiredProfiles : NetworkService.savedWifiProfiles;
            return profiles.find((item) => {
                return item.uuid === target.uuid;
            }) || null;
        }
        const currentNetwork = !isWired ? NetworkService.allWifiNetworks.find((item) => {
            return item.deviceName === target.deviceName && item.ssid === target.ssid;
        }) : null;
        const currentProfiles = currentNetwork ? currentNetwork.profiles : target.profiles;
        if (currentProfiles && currentProfiles.length > 0) {
            const activeUuid = runtimeMatchesInterface ? NetworkService.runtimeDetails.connectionUuid : "";
            return currentProfiles.find((item) => {
                return activeUuid.length > 0 && item.uuid === activeUuid;
            }) || currentProfiles[0];
        }
        if (isWired) {
            const activeUuid = runtimeMatchesInterface ? NetworkService.runtimeDetails.connectionUuid : "";
            return NetworkService.wiredProfiles.find((item) => {
                return item.deviceName === target.name && activeUuid.length > 0 && item.uuid === activeUuid;
            }) || NetworkService.wiredProfiles.find((item) => {
                return item.deviceName === target.name;
            }) || null;
        }
        return null;
    }
    readonly property var nativeNetwork: target && target.nativeNetwork ? target.nativeNetwork : profile ? profile.nativeNetwork : null
    readonly property bool connectionIsActive: {
        if (!nativeNetwork || !nativeNetwork.connected)
            return false;

        if (target && target.nativeSettings)
            return runtimeMatchesInterface && NetworkService.runtimeDetails.connectionUuid === target.uuid;

        return true;
    }
    readonly property bool showRuntimeDetails: connectionIsActive && runtimeMatchesInterface
    property var original: null
    property string loadedProfileUuid: ""
    property string mode: "auto"
    property string address: ""
    property string gateway: ""
    property string dns: ""
    property bool autoconnect: true
    property bool saving: false
    property string errorMessage: ""
    property string successMessage: ""
    readonly property bool dirty: original && (mode !== original.method || address.trim() !== original.address || gateway.trim() !== original.gateway || normalizeDns(dns) !== normalizeDns(original.dns) || autoconnect !== original.autoconnect)
    readonly property bool addressValid: mode !== "manual" || validCidr(address)
    readonly property bool gatewayValid: mode !== "manual" || gateway.trim() === "" || validIpv4(gateway.trim())
    readonly property bool dnsValid: mode === "auto" || (mode === "manual" && normalizeDns(dns).length === 0) || (normalizeDns(dns).length > 0 && normalizeDns(dns).split(",").every((value) => {
        return validIpv4(value);
    }))
    readonly property bool formValid: addressValid && gatewayValid && dnsValid

    signal profileForgotten()

    function validIpv4(value) {
        const parts = String(value || "").split(".");
        if (parts.length !== 4)
            return false;

        return parts.every((part) => {
            return /^\d{1,3}$/.test(part) && Number(part) >= 0 && Number(part) <= 255;
        });
    }

    function validCidr(value) {
        const pieces = String(value || "").trim().split("/");
        return pieces.length === 2 && validIpv4(pieces[0]) && /^\d{1,2}$/.test(pieces[1]) && Number(pieces[1]) >= 0 && Number(pieces[1]) <= 32;
    }

    function normalizeDns(value) {
        return String(value || "").trim().split(/[\s,]+/).filter((item) => {
            return item.length > 0;
        }).join(",");
    }

    function loadProfile() {
        const snapshot = NetworkService.profileSnapshot(root.profile);
        if (!snapshot) {
            root.original = null;
            root.loadedProfileUuid = "";
            return ;
        }
        root.loadedProfileUuid = String(root.profile.uuid || "");
        root.original = snapshot;
        root.mode = snapshot.method;
        root.address = snapshot.address;
        root.gateway = snapshot.gateway;
        root.dns = snapshot.dns;
        root.autoconnect = snapshot.autoconnect;
    }

    function refreshRuntime() {
        if (root.target && root.nativeNetwork && root.nativeNetwork.connected)
            NetworkService.requestRuntimeDetails(root.profile || root.target);
        else
            NetworkService.releaseRuntimeDetails();
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2
    Component.onCompleted: {
        loadProfile();
        refreshRuntime();
    }
    Component.onDestruction: NetworkService.releaseRuntimeDetails()
    onTargetChanged: {
        root.profileRemoved = false;
        loadProfile();
        refreshRuntime();
    }
    onProfileChanged: {
        const uuid = String(root.profile ? root.profile.uuid || "" : "");
        if (uuid === root.loadedProfileUuid)
            return ;

        if (root.target && root.target.nativeSettings && uuid.length === 0 && root.loadedProfileUuid.length > 0) {
            root.profileRemoved = true;
            root.original = null;
            root.loadedProfileUuid = "";
            root.profileForgotten();
            return ;
        }
        const discardedChanges = root.dirty;
        root.loadProfile();
        if (discardedChanges)
            root.errorMessage = qsTr("活动网络配置已变化，未应用的修改已丢弃");

    }

    Connections {
        function onProfileWriteSucceeded(uuid) {
            if (!root.profile || uuid !== root.profile.uuid)
                return ;

            root.saving = false;
            root.errorMessage = "";
            root.successMessage = root.nativeNetwork && root.nativeNetwork.connected ? qsTr("配置已保存；重新连接后将完整应用新的 IPv4 设置") : qsTr("配置已保存");
            root.loadProfile();
            root.refreshRuntime();
        }

        function onProfileWriteFailed(uuid, message) {
            if (!root.profile || uuid !== root.profile.uuid)
                return ;

            root.saving = false;
            root.successMessage = "";
            root.errorMessage = message;
        }

        function onProfileForgetSucceeded(uuid) {
            if (!root.target || uuid !== String(root.target.uuid || ""))
                return ;

            root.profileRemoved = true;
            root.profileForgotten();
        }

        function onProfileForgetFailed(uuid, message) {
            if (!root.target || uuid !== String(root.target.uuid || ""))
                return ;

            root.errorMessage = message;
        }

        target: NetworkService
    }

    Connections {
        function onConnectedChanged() {
            root.refreshRuntime();
        }

        target: root.nativeNetwork
        enabled: root.nativeNetwork !== null
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingS

            ActionButton {
                visible: root.connectionIsActive
                text: qsTr("断开")
                iconName: "link_off"
                enabled: !NetworkService.busy
                onClicked: NetworkService.disconnectNetwork(root.target)
            }

            ActionButton {
                visible: root.nativeNetwork && !root.connectionIsActive
                text: qsTr("连接")
                iconName: "link"
                enabled: !NetworkService.busy && (!root.isWired || root.target.hasLink)
                onClicked: {
                    if (root.profile)
                        NetworkService.connectProfile(root.profile);
                    else
                        NetworkService.connectNetwork(root.target, null);
                }
            }

            ActionButton {
                visible: root.profile !== null && !root.isWired
                text: qsTr("忘记")
                iconName: "delete"
                enabled: !NetworkService.busy && !root.saving
                onClicked: {
                    root.errorMessage = "";
                    NetworkService.forgetProfile(root.profile);
                }
            }

            Item {
                Layout.fillWidth: true
            }

        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.errorMessage.length > 0 || NetworkService.runtimeDetailsError.length > 0
            tone: "error"
            message: root.errorMessage.length > 0 ? root.errorMessage : NetworkService.runtimeDetailsError
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.successMessage.length > 0
            tone: "info"
            iconName: "check_circle"
            message: root.successMessage
        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("连接信息")
            iconName: root.isWired ? "lan" : "wifi"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("配置")
                supportingText: root.profile ? root.profile.name : qsTr("无可编辑配置")
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("接口")
                supportingText: root.profile ? root.profile.deviceName : root.target ? root.target.name : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.isWired
                title: qsTr("链路速度")
                supportingText: root.target && root.target.linkSpeed ? root.target.linkSpeed + " Mbps" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: !root.isWired
                title: qsTr("信号")
                supportingText: root.target && root.target.strength !== undefined ? root.target.strength + "%" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: !root.isWired
                title: qsTr("安全类型")
                supportingText: root.target ? String(root.target.security || qsTr("未知")) : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: !root.isWired
                title: qsTr("频率")
                supportingText: root.showRuntimeDetails ? NetworkService.runtimeDetails.frequency || "—" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("IP 地址")
                supportingText: root.showRuntimeDetails && NetworkService.runtimeDetails.addresses ? NetworkService.runtimeDetails.addresses.join(", ") : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Gateway")
                supportingText: root.showRuntimeDetails ? NetworkService.runtimeDetails.gateway || "—" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("DNS")
                supportingText: root.showRuntimeDetails && NetworkService.runtimeDetails.dns ? NetworkService.runtimeDetails.dns.join(", ") : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("MAC")
                supportingText: root.target ? root.target.address || (root.profile ? root.profile.deviceAddress : "—") : "—"
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            visible: root.profile !== null
            title: qsTr("IPv4")
            iconName: "network_manage"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("自动连接")
                supportingText: qsTr("NetworkManager 可在网络可用时自动激活此配置")

                trailing: StyledSwitch {
                    checked: root.autoconnect
                    onToggled: root.autoconnect = checked
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXS

                Text {
                    text: qsTr("IP 分配")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    model: [{
                        "value": "auto",
                        "label": qsTr("自动 DHCP")
                    }, {
                        "value": "auto-dns",
                        "label": qsTr("DHCP + 自定义 DNS")
                    }, {
                        "value": "manual",
                        "label": qsTr("手动")
                    }]
                    currentValue: root.mode
                    onValueSelected: (value) => {
                        return root.mode = value;
                    }
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.mode === "manual"
                spacing: Metrics.spacingXS

                MaterialTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("IPv4 地址 / CIDR")
                    text: root.address
                    error: !root.addressValid
                    onTextChanged: root.address = text
                }

                Text {
                    visible: !root.addressValid
                    text: qsTr("请输入合法 IPv4 CIDR，例如 192.168.1.50/24")
                    color: Appearance.colors.colError
                    font.pixelSize: Typography.bodySmall.pixelSize
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("Gateway")
                    text: root.gateway
                    error: !root.gatewayValid
                    onTextChanged: root.gateway = text
                }

                Text {
                    visible: !root.gatewayValid
                    text: qsTr("请输入合法 IPv4 gateway")
                    color: Appearance.colors.colError
                    font.pixelSize: Typography.bodySmall.pixelSize
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.mode !== "auto"
                spacing: Metrics.spacingXS

                MaterialTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("DNS")
                    text: root.dns
                    error: !root.dnsValid
                    onTextChanged: root.dns = text
                }

                Text {
                    text: root.dnsValid ? qsTr("可使用逗号或空格分隔") : qsTr("请输入至少一个合法 IPv4 DNS 地址")
                    color: root.dnsValid ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colError
                    font.pixelSize: Typography.bodySmall.pixelSize
                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.profile && (root.dirty || root.saving)

            Item {
                Layout.fillWidth: true
            }

            MaterialLoadingIndicator {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                contained: false
                visible: root.saving
            }

            ActionButton {
                text: qsTr("应用")
                iconName: "save"
                filled: true
                enabled: root.dirty && root.formValid && !root.saving
                onClicked: {
                    root.errorMessage = "";
                    root.successMessage = "";
                    root.saving = NetworkService.writeProfile(root.profile, {
                        "method": root.mode,
                        "address": root.address.trim(),
                        "gateway": root.gateway.trim(),
                        "dns": root.normalizeDns(root.dns),
                        "autoconnect": root.autoconnect
                    });
                }
            }

        }

    }

}
