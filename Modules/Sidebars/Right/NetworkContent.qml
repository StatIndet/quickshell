import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: root

    property bool foreground: false
    readonly property bool isActive: root.foreground && WidgetState.qsView === "network"
    property bool scanLeaseAcquired: false
    property bool initialLoadAttempted: false
    property bool initialLoading: false
    property bool refreshLoading: false
    property var pendingForgetNetwork: null
    readonly property bool networkUsable: NetworkService.available && NetworkService.wifiAvailable && NetworkService.wifiEnabled
    readonly property var savedWifiProfiles: NetworkService.savedWifiProfiles
    readonly property var availableWifiNetworks: NetworkService.availableWifiNetworks
    readonly property bool linearLoading: refreshLoading || NetworkService.busy
    readonly property string stateMessage: {
        if (NetworkService.lastError.length > 0)
            return NetworkService.lastError;

        if (!NetworkService.available)
            return qsTr("NetworkManager 当前不可用");

        if (!NetworkService.wifiAvailable)
            return qsTr("未检测到 Wi-Fi 设备");

        if (!NetworkService.wifiHardwareEnabled)
            return qsTr("Wi-Fi 已被硬件开关或 rfkill 阻止");

        if (!NetworkService.wifiEnabled)
            return qsTr("Wi-Fi 已关闭");

        return "";
    }

    function beginInitialLoad() {
        if (!root.isActive || !root.networkUsable || root.initialLoadAttempted)
            return ;

        initialLoadTimer.stop();
        root.initialLoadAttempted = true;
        initialLoading = NetworkService.availableWifiNetworks.length === 0;
        if (initialLoading)
            initialLoadTimer.restart();

    }

    function finishTransientLoading() {
        initialLoading = false;
        refreshLoading = false;
        initialLoadTimer.stop();
        refreshTimer.stop();
    }

    function updateScanLease() {
        if (isActive && !scanLeaseAcquired) {
            NetworkService.acquireScan("right-sidebar-network");
            scanLeaseAcquired = true;
            Qt.callLater(root.beginInitialLoad);
        } else if (!isActive && scanLeaseAcquired) {
            NetworkService.releaseScan("right-sidebar-network");
            scanLeaseAcquired = false;
            finishTransientLoading();
            NetworkService.cancelPasswordRequest(null);
        }
    }

    function requestRefresh() {
        if (!root.networkUsable || root.refreshLoading)
            return ;

        initialLoading = false;
        initialLoadTimer.stop();
        refreshLoading = true;
        refreshTimer.restart();
        NetworkService.requestScan();
    }

    function connectivityText() {
        if (NetworkService.captivePortal)
            return qsTr("需要登录网络门户");

        if (NetworkService.limitedConnectivity)
            return qsTr("网络连接受限");

        if (NetworkService.internetAvailable)
            return qsTr("互联网可用");

        if (NetworkService.connected)
            return qsTr("已连接，无法确认互联网状态");

        return qsTr("当前未连接");
    }

    function savedProfileDetails(profile) {
        const details = [];
        const profileName = String(profile.name || "");
        const ssid = String(profile.ssid || "");
        if (profileName.length > 0 && profileName !== ssid)
            details.push(ssid);

        if (profile.ipv4Method === "manual")
            details.push(qsTr("手动 IPv4"));
        else if (profile.customDns)
            details.push(qsTr("DHCP + 自定义 DNS"));
        else
            details.push(qsTr("自动 DHCP"));
        if (profile.autoconnect)
            details.push(qsTr("自动连接"));

        return details.join(" · ");
    }

    function forgetTargetLabel(target) {
        if (!target)
            return "";

        const name = String(target.name || target.ssid || "");
        if (!target.uuid)
            return name;

        const details = root.savedProfileDetails(target);
        return details.length > 0 ? name + " · " + details : name;
    }

    title: qsTr("网络")
    icon: "wifi"
    showBackButton: true
    backAction: () => {
        return WidgetState.qsView = "settings";
    }
    onIsActiveChanged: updateScanLease()
    onAvailableWifiNetworksChanged: {
        if (NetworkService.availableWifiNetworks.length > 0)
            root.finishTransientLoading();

    }
    Component.onCompleted: updateScanLease()
    Component.onDestruction: {
        if (scanLeaseAcquired)
            NetworkService.releaseScan("right-sidebar-network");

        NetworkService.cancelPasswordRequest(null);
    }

    Connections {
        function onWifiEnabledChanged() {
            if (!NetworkService.wifiEnabled)
                root.finishTransientLoading();
            else if (root.isActive)
                Qt.callLater(root.beginInitialLoad);
        }

        function onOperationFailed(operation, message) {
            if (operation === "scan") {
                root.refreshLoading = false;
                refreshTimer.stop();
            }
        }

        target: NetworkService
    }

    Timer {
        id: initialLoadTimer

        interval: 4000
        repeat: false
        onTriggered: root.initialLoading = false
    }

    Timer {
        id: refreshTimer

        interval: 4000
        repeat: false
        onTriggered: root.refreshLoading = false
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: root.linearLoading ? 4 : 0
            opacity: root.linearLoading ? 1 : 0
            indeterminate: true
            Material.accent: Appearance.colors.colPrimary

            Behavior on Layout.preferredHeight {
                ElementMoveAnimation {
                }

            }

            Behavior on opacity {
                ElementMoveAnimation {
                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true

            SettingsRow {
                Layout.fillWidth: true
                iconName: NetworkService.activeConnectionType === "ETHERNET" ? "lan" : NetworkService.wifiConnected ? "wifi" : "wifi_off"
                title: NetworkService.activeNetwork ? NetworkService.activeConnection : qsTr("未连接")
                supportingText: root.connectivityText()
                highlighted: NetworkService.connected

                trailing: RowLayout {
                    spacing: Appearance.spacing.xSmall

                    Text {
                        visible: NetworkService.wifiConnected
                        text: NetworkService.signalStrength + "%"
                        color: Appearance.colors.colOnLayer1
                        font.family: Fonts.numeric
                        font.pixelSize: 12
                    }

                    MaterialSymbol {
                        text: NetworkService.internetAvailable ? "language" : NetworkService.captivePortal ? "captive_portal" : "public_off"
                        iconSize: 19
                        color: NetworkService.internetAvailable ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                    }

                }

            }

            ActionButton {
                Layout.fillWidth: true
                visible: NetworkService.captivePortal
                text: qsTr("打开网络门户")
                filled: true
                onClicked: NetworkService.openPublicWifiPortal()
            }

        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.stateMessage.length > 0
            tone: NetworkService.lastError.length > 0 ? "error" : "info"
            message: root.stateMessage
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.networkUsable
            contentWidth: width
            contentHeight: networkContent.implicitHeight

            ColumnLayout {
                id: networkContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                SettingsSection {
                    Layout.fillWidth: true
                    visible: root.savedWifiProfiles.length > 0
                    title: qsTr("已保存网络")

                    Repeater {
                        model: root.savedWifiProfiles

                        SavedWifiProfileItem {
                            required property var modelData

                            Layout.fillWidth: true
                            profile: modelData
                        }

                    }

                }

                SettingsSection {
                    Layout.fillWidth: true
                    title: qsTr("可选网络")
                    supportingText: root.initialLoading ? qsTr("正在获取扫描结果") : NetworkService.availableWifiNetworks.length + qsTr(" 个网络")

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.initialLoading ? 116 : 0
                        visible: root.initialLoading
                        opacity: root.initialLoading ? 1 : 0
                        clip: true

                        Column {
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.small

                            MaterialLoadingIndicator {
                                anchors.horizontalCenter: parent.horizontalCenter
                                running: root.initialLoading
                                accessibleName: qsTr("正在查找可选网络")
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("正在查找可选网络")
                                color: Appearance.colors.colOnLayer1
                                font.family: Fonts.ui
                                font.pixelSize: 12
                            }

                        }

                        Behavior on Layout.preferredHeight {
                            ElementMoveAnimation {
                            }

                        }

                        Behavior on opacity {
                            ElementMoveAnimation {
                            }

                        }

                    }

                    StyledListView {
                        id: availableNetworkList

                        readonly property real baseContentHeight: count * 64 + Math.max(0, count - 1) * spacing

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(Sizes.sidebarScrollableListMaxHeight, Math.max(baseContentHeight, contentHeight))
                        visible: count > 0
                        spacing: Appearance.spacing.xSmall
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        model: NetworkService.availableWifiNetworks

                        delegate: WifiNetworkItem {
                            required property var modelData

                            width: ListView.view.width
                            wifiNetwork: modelData
                        }

                        Behavior on Layout.preferredHeight {
                            ElementMoveAnimation {
                            }

                        }

                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: !root.initialLoading && !root.refreshLoading && NetworkService.availableWifiNetworks.length === 0
                        iconName: "search_off"
                        title: qsTr("未发现可选网络")
                    }

                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.spacing.small
                }

            }

        }

    }

    MaterialDialog {
        id: forgetDialog

        width: Math.min(320, root.width - 48)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        dialogTitle: qsTr("遗忘网络")
        messageText: root.pendingForgetNetwork ? qsTr("将删除“") + root.forgetTargetLabel(root.pendingForgetNetwork) + qsTr("”的已保存连接。") : ""

        actionsComponent: Component {
            RowLayout {
                spacing: Metrics.spacingS

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    text: qsTr("取消")
                    onClicked: {
                        forgetDialog.close();
                        root.pendingForgetNetwork = null;
                    }
                }

                ActionButton {
                    text: qsTr("遗忘")
                    onClicked: {
                        const target = root.pendingForgetNetwork;
                        forgetDialog.close();
                        root.pendingForgetNetwork = null;
                        if (target) {
                            if (target.uuid && target.nativeSettings)
                                NetworkService.forgetProfile(target);
                            else
                                NetworkService.forgetNetwork(target);
                        }
                    }
                }

            }

        }

    }

    headerTools: RowLayout {
        spacing: Appearance.spacing.xSmall

        IconButton {
            enabled: root.networkUsable && !root.refreshLoading
            iconName: "refresh"
            iconSize: 21
            iconColor: Appearance.colors.colOnLayer2
            accessibleName: qsTr("刷新网络列表")
            hoverStateLayerColor: Appearance.colors.colLayer2Hover
            pressedStateLayerColor: Appearance.colors.colLayer2Active
            onClicked: root.requestRefresh()

            RotationAnimation on iconRotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.refreshLoading
            }

        }

        StyledSwitch {
            scale: 0.8
            checked: NetworkService.wifiEnabled
            enabled: NetworkService.available && NetworkService.wifiAvailable && NetworkService.wifiHardwareEnabled && !NetworkService.busy
            Accessible.name: qsTr("Wi-Fi 开关")
            onToggled: NetworkService.setWifiEnabled(checked)
        }

    }

    component SavedWifiProfileItem: Rectangle {
        id: profileRoot

        required property var profile
        readonly property bool targetBusy: NetworkService.connectTargetUuid.length > 0 && NetworkService.connectTargetUuid === String(profile.uuid || "")

        implicitHeight: 64
        radius: Appearance.rounding.normal
        color: "transparent"

        SettingsRow {
            anchors.fill: parent
            iconName: profile.strength > 75 ? "signal_wifi_4_bar" : profile.strength > 50 ? "network_wifi_3_bar" : profile.strength > 25 ? "network_wifi_2_bar" : "signal_wifi_0_bar"
            title: profile.name || profile.ssid
            supportingText: root.savedProfileDetails(profile)
            interactive: !NetworkService.busy
            onClicked: NetworkService.connectProfile(profileRoot.profile)

            trailing: RowLayout {
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    visible: profileRoot.targetBusy
                    text: "progress_activity"
                    iconSize: 19
                    color: Appearance.colors.colPrimary

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 850
                        loops: Animation.Infinite
                        running: profileRoot.targetBusy
                    }

                }

                IconButton {
                    controlSize: 36
                    enabled: !NetworkService.busy
                    iconName: "more_vert"
                    iconSize: 19
                    iconColor: Appearance.colors.colOnLayer2
                    accessibleName: qsTr("网络操作")
                    hoverStateLayerColor: Appearance.colors.colLayer3Hover
                    pressedStateLayerColor: Appearance.colors.colLayer3Active
                    onClicked: profileMenu.open()

                    Menu {
                        id: profileMenu

                        Material.theme: Material.System
                        Material.accent: Appearance.colors.colPrimary

                        MenuItem {
                            text: qsTr("遗忘网络")
                            onTriggered: {
                                root.pendingForgetNetwork = profileRoot.profile;
                                forgetDialog.open();
                            }
                        }

                    }

                }

            }

        }

    }

    component WifiNetworkItem: Rectangle {
        id: itemRoot

        required property var wifiNetwork
        property bool showPassword: false
        readonly property bool networkActive: !!wifiNetwork.active
        readonly property bool networkSecure: !!wifiNetwork.isSecure
        readonly property bool networkKnown: !!wifiNetwork.known
        readonly property bool networkAskingPassword: !!wifiNetwork.askingPassword
        readonly property bool targetBusy: NetworkService.wifiConnectTarget && NetworkService.wifiConnectTarget.ssid === wifiNetwork.ssid
        readonly property real promptHeight: networkAskingPassword ? passwordContent.implicitHeight + Appearance.spacing.medium : 0

        function submitPassword() {
            const password = passwordField.text;
            if (password.length === 0)
                return ;

            passwordField.text = "";
            passwordField.focus = false;
            showPassword = false;
            NetworkService.changePassword(wifiNetwork, password);
        }

        implicitHeight: 64 + promptHeight
        height: implicitHeight
        radius: Appearance.rounding.normal
        clip: true
        color: networkActive || networkAskingPassword ? Appearance.colors.colLayer2 : "transparent"
        onNetworkAskingPasswordChanged: {
            if (!networkAskingPassword) {
                passwordField.text = "";
                passwordField.focus = false;
                showPassword = false;
            }
        }

        SettingsRow {
            height: 64
            iconName: wifiNetwork.strength > 75 ? "signal_wifi_4_bar" : wifiNetwork.strength > 50 ? "network_wifi_3_bar" : wifiNetwork.strength > 25 ? "network_wifi_2_bar" : "signal_wifi_0_bar"
            title: wifiNetwork.ssid
            supportingText: networkActive ? qsTr("已连接 · ") + wifiNetwork.strength + "%" : (networkKnown ? qsTr("已保存 · ") : "") + (networkSecure ? wifiNetwork.security : qsTr("开放网络")) + " · " + wifiNetwork.strength + "%"
            interactive: !NetworkService.busy && !networkAskingPassword
            highlighted: networkActive
            onClicked: NetworkService.connectToWifiNetwork(itemRoot.wifiNetwork)

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }

            trailing: RowLayout {
                spacing: Appearance.spacing.xSmall

                MaterialSymbol {
                    visible: itemRoot.networkSecure && !itemRoot.networkActive
                    text: "lock"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    visible: itemRoot.targetBusy
                    text: "progress_activity"
                    iconSize: 19
                    color: Appearance.colors.colPrimary

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 850
                        loops: Animation.Infinite
                        running: itemRoot.targetBusy
                    }

                }

                IconButton {
                    visible: itemRoot.networkKnown
                    controlSize: 36
                    enabled: !NetworkService.busy
                    iconName: "more_vert"
                    iconSize: 19
                    iconColor: Appearance.colors.colOnLayer2
                    accessibleName: qsTr("网络操作")
                    hoverStateLayerColor: Appearance.colors.colLayer3Hover
                    pressedStateLayerColor: Appearance.colors.colLayer3Active
                    onClicked: networkMenu.open()

                    Menu {
                        id: networkMenu

                        Material.theme: Material.System
                        Material.accent: Appearance.colors.colPrimary

                        MenuItem {
                            visible: itemRoot.networkActive
                            text: qsTr("断开连接")
                            onTriggered: NetworkService.disconnectNetwork(itemRoot.wifiNetwork)
                        }

                        MenuItem {
                            text: qsTr("遗忘网络")
                            onTriggered: {
                                root.pendingForgetNetwork = itemRoot.wifiNetwork;
                                forgetDialog.open();
                            }
                        }

                    }

                }

            }

        }

        Item {
            height: itemRoot.promptHeight
            opacity: itemRoot.networkAskingPassword ? 1 : 0
            clip: true

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 64
            }

            ColumnLayout {
                id: passwordContent

                spacing: Appearance.spacing.small

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: Appearance.spacing.medium
                    rightMargin: Appearance.spacing.medium
                    topMargin: Appearance.spacing.small
                }

                MaterialTextField {
                    id: passwordField

                    Layout.fillWidth: true
                    placeholderText: qsTr("网络密码")
                    echoMode: itemRoot.showPassword ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    enabled: !NetworkService.busy
                    onAccepted: itemRoot.submitPassword()

                    trailingContent: Component {
                        IconButton {
                            anchors.fill: parent
                            enabled: !NetworkService.busy
                            iconName: itemRoot.showPassword ? "visibility_off" : "visibility"
                            iconSize: 20
                            iconColor: Appearance.colors.colOnLayer1
                            accessibleName: itemRoot.showPassword ? qsTr("隐藏密码") : qsTr("显示密码")
                            hoverStateLayerColor: Appearance.colors.colLayer1Hover
                            pressedStateLayerColor: Appearance.colors.colLayer1Active
                            onClicked: itemRoot.showPassword = !itemRoot.showPassword
                        }

                    }

                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Item {
                        Layout.fillWidth: true
                    }

                    ActionButton {
                        text: qsTr("取消")
                        onClicked: NetworkService.cancelPasswordRequest(itemRoot.wifiNetwork)
                    }

                    ActionButton {
                        text: qsTr("连接")
                        filled: true
                        onClicked: itemRoot.submitPassword()
                    }

                }

            }

            Behavior on height {
                ElementMoveAnimation {
                }

            }

            Behavior on opacity {
                ElementMoveAnimation {
                }

            }

        }

        Behavior on height {
            ElementMoveAnimation {
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
            }

        }

    }

}
