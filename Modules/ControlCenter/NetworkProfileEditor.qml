import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property var target: null
    readonly property bool isWired: target && target.type === "wired"
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
        if (currentProfiles && currentProfiles.length > 0)
            return currentProfiles[0];

        if (isWired) {
            const interfaceName = String(target.deviceName || target.name || "");
            for (const wiredProfile of NetworkService.wiredProfiles) {
                if (wiredProfile.deviceName === interfaceName)
                    return wiredProfile;

            }
        }
        return null;
    }
    readonly property var nativeNetwork: target && target.nativeNetwork ? target.nativeNetwork : profile ? profile.nativeNetwork : null
    readonly property bool connectionIsActive: !!(nativeNetwork && nativeNetwork.connected)
    readonly property var wiredDevice: isWired && profile ? NetworkService.wiredDevices.find((device) => {
        return device.deviceName === profile.deviceName;
    }) || null : null
    property var original: null
    property string loadedProfileUuid: ""
    property string mode: "auto"
    property string address: ""
    property string gateway: ""
    property string dns: ""
    property bool autoconnect: true
    property bool addressTouched: false
    property bool gatewayTouched: false
    property bool dnsTouched: false
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
        root.addressTouched = false;
        root.gatewayTouched = false;
        root.dnsTouched = false;
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

    function resetEditor() {
        root.profileRemoved = false;
        root.saving = false;
        root.errorMessage = "";
        root.successMessage = "";
        root.loadProfile();
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2
    Component.onCompleted: root.resetEditor()
    onTargetChanged: root.resetEditor()
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
                enabled: !NetworkService.busy && (!root.isWired || root.wiredDevice && root.wiredDevice.hasLink)
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
            radius: Metrics.cornerM
            visible: root.errorMessage.length > 0
            tone: "error"
            message: root.errorMessage
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            radius: Metrics.cornerM
            visible: root.successMessage.length > 0
            tone: "info"
            iconName: "check_circle"
            message: root.successMessage
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("基本信息")
            iconName: "info"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("配置名称")
                supportingText: root.profile ? root.profile.name : qsTr("无可编辑配置")
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: !root.isWired
                title: qsTr("SSID")
                supportingText: root.profile ? root.profile.ssid : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("接口")
                supportingText: root.profile ? root.profile.deviceName : root.target ? root.target.deviceName || root.target.name : "—"
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            visible: root.profile !== null
            title: qsTr("IPv4")
            iconName: "network_manage"
            contentSpacing: Metrics.spacingL

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("自动连接")

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
                spacing: Metrics.spacingM

                OutlinedTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("IPv4 地址 / CIDR")
                    text: root.address
                    errorText: root.addressTouched && !root.addressValid ? qsTr("请输入合法 IPv4 CIDR，例如 192.168.1.50/24") : ""
                    onTextChanged: root.address = text
                    onEditingFinished: root.addressTouched = true
                }

                OutlinedTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("Gateway")
                    text: root.gateway
                    errorText: root.gatewayTouched && !root.gatewayValid ? qsTr("请输入合法 IPv4 gateway") : ""
                    onTextChanged: root.gateway = text
                    onEditingFinished: root.gatewayTouched = true
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.mode !== "auto"
                spacing: Metrics.spacingM

                OutlinedTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("DNS")
                    text: root.dns
                    errorText: root.dnsTouched && !root.dnsValid ? qsTr("请输入至少一个合法 IPv4 DNS 地址") : ""
                    onTextChanged: root.dns = text
                    onEditingFinished: root.dnsTouched = true
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
