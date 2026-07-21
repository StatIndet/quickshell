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

    title: "网络"
    icon: "wifi"
    showBackButton: true
    backAction: () => WidgetState.qsView = "settings"

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "network"
    property bool scanLeaseAcquired: false
    property bool initialLoadAttempted: false
    property bool initialLoading: false
    property bool refreshLoading: false
    property var pendingForgetNetwork: null
    readonly property bool networkUsable: NetworkService.available
        && NetworkService.wifiAvailable
        && NetworkService.wifiEnabled
    readonly property var savedWifiNetworks: NetworkService.savedWifiNetworks
    readonly property var availableWifiNetworks: NetworkService.availableWifiNetworks
    readonly property bool linearLoading: refreshLoading || NetworkService.busy
    readonly property string stateMessage: {
        if (NetworkService.lastError.length > 0)
            return NetworkService.lastError;
        if (!NetworkService.available)
            return "NetworkManager 当前不可用";
        if (!NetworkService.wifiAvailable)
            return "未检测到 Wi-Fi 设备";
        if (!NetworkService.wifiHardwareEnabled)
            return "Wi-Fi 已被硬件开关或 rfkill 阻止";
        if (!NetworkService.wifiEnabled)
            return "Wi-Fi 已关闭";
        return "";
    }

    function beginInitialLoad() {
        if (!root.isActive || !root.networkUsable || root.initialLoadAttempted)
            return;

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
            return;
        initialLoading = false;
        initialLoadTimer.stop();
        refreshLoading = true;
        refreshTimer.restart();
        NetworkService.requestScan();
    }

    function connectivityText() {
        if (NetworkService.captivePortal)
            return "需要登录网络门户";
        if (NetworkService.limitedConnectivity)
            return "网络连接受限";
        if (NetworkService.internetAvailable)
            return "互联网可用";
        if (NetworkService.connected)
            return "已连接，无法确认互联网状态";
        return "当前未连接";
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
        target: NetworkService

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

    headerTools: RowLayout {
        spacing: Appearance.spacing.xSmall

        ToolButton {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            enabled: root.networkUsable && !root.refreshLoading
            hoverEnabled: true
            Accessible.name: "刷新网络列表"
            onClicked: root.requestRefresh()

            background: Rectangle {
                radius: Appearance.rounding.full
                color: parent.down
                    ? Appearance.colors.colLayer2Active
                    : parent.hovered ? Appearance.colors.colLayer2Hover : "transparent"
            }

            contentItem: MaterialSymbol {
                id: refreshIcon
                text: "refresh"
                iconSize: 21
                color: Appearance.colors.colOnLayer2

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.refreshLoading
                }
            }
        }

        StyledSwitch {
            scale: 0.8
            checked: NetworkService.wifiEnabled
            enabled: NetworkService.available
                && NetworkService.wifiAvailable
                && NetworkService.wifiHardwareEnabled
                && !NetworkService.busy
            Accessible.name: "Wi-Fi 开关"
            onToggled: NetworkService.setWifiEnabled(checked)
        }
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

            Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
            Behavior on opacity { ElementMoveAnimation {} }
        }

        SettingsSection {
            Layout.fillWidth: true

            SettingsRow {
                Layout.fillWidth: true
                iconName: NetworkService.activeConnectionType === "ETHERNET"
                    ? "lan"
                    : NetworkService.wifiConnected ? "wifi" : "wifi_off"
                title: NetworkService.activeNetwork
                    ? NetworkService.activeConnection
                    : "未连接"
                supportingText: root.connectivityText()
                highlighted: NetworkService.connected

                trailing: RowLayout {
                    spacing: Appearance.spacing.xSmall

                    Text {
                        visible: NetworkService.wifiConnected
                        text: NetworkService.signalStrength + "%"
                        color: Appearance.colors.colOnLayer1
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: 12
                    }

                    MaterialSymbol {
                        text: NetworkService.internetAvailable
                            ? "language"
                            : NetworkService.captivePortal ? "captive_portal" : "public_off"
                        iconSize: 19
                        color: NetworkService.internetAvailable
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colOnLayer1
                    }
                }
            }

            DialogActionButton {
                Layout.fillWidth: true
                visible: NetworkService.captivePortal
                text: "打开网络门户"
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
                    visible: NetworkService.savedWifiNetworks.length > 0
                    title: "已保存网络"
                    supportingText: NetworkService.savedWifiNetworks.length + " 个网络"

                    Repeater {
                        model: NetworkService.savedWifiNetworks

                        WifiNetworkItem {
                            required property var modelData

                            Layout.fillWidth: true
                            wifiNetwork: modelData
                        }
                    }
                }

                SettingsSection {
                    Layout.fillWidth: true
                    title: "可选网络"
                    supportingText: root.initialLoading
                        ? "正在获取扫描结果"
                        : NetworkService.availableWifiNetworks.length + " 个网络"

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.initialLoading ? 116 : 0
                        visible: root.initialLoading
                        opacity: root.initialLoading ? 1 : 0
                        clip: true

                        Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
                        Behavior on opacity { ElementMoveAnimation {} }

                        Column {
                            anchors.centerIn: parent
                            spacing: Appearance.spacing.small

                            MaterialLoadingIndicator {
                                anchors.horizontalCenter: parent.horizontalCenter
                                running: root.initialLoading
                                accessibleName: "正在查找可选网络"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "正在查找可选网络"
                                color: Appearance.colors.colOnLayer1
                                font.family: Sizes.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }

                    StyledListView {
                        id: availableNetworkList

                        readonly property real baseContentHeight: count * 64
                            + Math.max(0, count - 1) * spacing

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(
                            Sizes.sidebarScrollableListMaxHeight,
                            Math.max(baseContentHeight, contentHeight)
                        )
                        visible: count > 0
                        spacing: Appearance.spacing.xSmall
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        smoothWheelEnabled: interactive
                        model: NetworkService.availableWifiNetworks

                        delegate: WifiNetworkItem {
                            required property var modelData

                            width: ListView.view.width
                            wifiNetwork: modelData
                        }

                        Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: !root.initialLoading
                            && !root.refreshLoading
                            && NetworkService.availableWifiNetworks.length === 0
                        iconName: "search_off"
                        title: "未发现可选网络"
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.spacing.small
                }
            }
        }
    }

    Dialog {
        id: forgetDialog

        modal: true
        width: Math.min(320, root.width - 48)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        padding: Appearance.spacing.medium
        Material.theme: Material.System
        Material.accent: Appearance.colors.colPrimary

        background: Rectangle {
            radius: Appearance.rounding.veryLarge
            color: Appearance.colors.colSurfaceContainerHigh
        }

        header: Text {
            text: "遗忘网络"
            color: Appearance.colors.colOnLayer2
            font.family: Sizes.fontFamily
            font.pixelSize: 18
            font.weight: Font.DemiBold
            leftPadding: Appearance.spacing.medium
            rightPadding: Appearance.spacing.medium
            topPadding: Appearance.spacing.medium
        }

        contentItem: Text {
            text: root.pendingForgetNetwork
                ? "将删除“" + root.pendingForgetNetwork.ssid + "”的已保存连接。"
                : ""
            color: Appearance.colors.colOnLayer1
            font.family: Sizes.fontFamily
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        footer: RowLayout {
            spacing: Appearance.spacing.small

            Item { Layout.fillWidth: true }
            DialogActionButton {
                text: "取消"
                onClicked: {
                    forgetDialog.close();
                    root.pendingForgetNetwork = null;
                }
            }
            DialogActionButton {
                text: "遗忘"
                filled: true
                onClicked: {
                    const target = root.pendingForgetNetwork;
                    forgetDialog.close();
                    root.pendingForgetNetwork = null;
                    if (target)
                        NetworkService.forgetNetwork(target);
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
        readonly property bool targetBusy: NetworkService.wifiConnectTarget
            && NetworkService.wifiConnectTarget.ssid === wifiNetwork.ssid
        readonly property real promptHeight: networkAskingPassword
            ? passwordContent.implicitHeight + Appearance.spacing.medium
            : 0

        implicitHeight: 64 + promptHeight
        height: implicitHeight
        radius: Appearance.rounding.normal
        clip: true
        color: networkActive || networkAskingPassword
            ? Appearance.colors.colLayer2
            : "transparent"

        Behavior on height { ElementMoveAnimation {} }
        Behavior on color { ColorAnimation { duration: Appearance.animation.expressiveFastEffects.duration } }

        onNetworkAskingPasswordChanged: {
            if (!networkAskingPassword) {
                passwordField.text = "";
                passwordField.focus = false;
                showPassword = false;
            }
        }

        SettingsRow {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 64
            iconName: wifiNetwork.strength > 75
                ? "signal_wifi_4_bar"
                : wifiNetwork.strength > 50
                    ? "network_wifi_3_bar"
                    : wifiNetwork.strength > 25 ? "network_wifi_2_bar" : "signal_wifi_0_bar"
            title: wifiNetwork.ssid
            supportingText: networkActive
                ? "已连接 · " + wifiNetwork.strength + "%"
                : (networkKnown ? "已保存 · " : "")
                    + (networkSecure ? wifiNetwork.security : "开放网络")
                    + " · " + wifiNetwork.strength + "%"
            interactive: !NetworkService.busy && !networkAskingPassword
            highlighted: networkActive
            onClicked: NetworkService.connectToWifiNetwork(itemRoot.wifiNetwork)

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

                ToolButton {
                    visible: itemRoot.networkKnown
                    implicitWidth: 36
                    implicitHeight: 36
                    enabled: !NetworkService.busy
                    Accessible.name: "网络操作"
                    onClicked: networkMenu.open()

                    background: Rectangle {
                        radius: Appearance.rounding.full
                        color: parent.down
                            ? Appearance.colors.colLayer3Active
                            : parent.hovered ? Appearance.colors.colLayer3Hover : "transparent"
                    }

                    contentItem: MaterialSymbol {
                        text: "more_vert"
                        iconSize: 19
                        color: Appearance.colors.colOnLayer2
                    }

                    Menu {
                        id: networkMenu

                        Material.theme: Material.System
                        Material.accent: Appearance.colors.colPrimary

                        MenuItem {
                            visible: itemRoot.networkActive
                            text: "断开连接"
                            onTriggered: NetworkService.disconnectNetwork(itemRoot.wifiNetwork)
                        }
                        MenuItem {
                            text: "遗忘网络"
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
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 64
            }
            height: itemRoot.promptHeight
            opacity: itemRoot.networkAskingPassword ? 1 : 0
            clip: true

            Behavior on height { ElementMoveAnimation {} }
            Behavior on opacity { ElementMoveAnimation {} }

            ColumnLayout {
                id: passwordContent

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: Appearance.spacing.medium
                    rightMargin: Appearance.spacing.medium
                    topMargin: Appearance.spacing.small
                }
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.xSmall

                    MaterialTextField {
                        id: passwordField
                        Layout.fillWidth: true
                        placeholderText: "网络密码"
                        echoMode: itemRoot.showPassword ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        enabled: !NetworkService.busy
                        onAccepted: itemRoot.submitPassword()
                    }

                    ToolButton {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Accessible.name: itemRoot.showPassword ? "隐藏密码" : "显示密码"
                        onClicked: itemRoot.showPassword = !itemRoot.showPassword

                        contentItem: MaterialSymbol {
                            text: itemRoot.showPassword ? "visibility_off" : "visibility"
                            iconSize: 20
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    Item { Layout.fillWidth: true }
                    DialogActionButton {
                        text: "取消"
                        onClicked: NetworkService.cancelPasswordRequest(itemRoot.wifiNetwork)
                    }
                    DialogActionButton {
                        text: "连接"
                        filled: true
                        onClicked: itemRoot.submitPassword()
                    }
                }
            }
        }

        function submitPassword() {
            const password = passwordField.text;
            if (password.length === 0)
                return;
            passwordField.text = "";
            passwordField.focus = false;
            showPassword = false;
            NetworkService.changePassword(wifiNetwork, password);
        }
    }
}
