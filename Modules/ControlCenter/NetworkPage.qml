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
    property bool initialLoadAttempted: false
    property bool initialLoading: false
    readonly property var nearbyNetworks: NetworkService.nearbyWifiNetworks.filter(network => {
        return !network.active;
    })
    readonly property var activeNetwork: NetworkService.activeNetwork
    readonly property string activeConnectionKey: activeNetwork ? [activeNetwork.type,
                                                                   activeNetwork.deviceName,
                                                                   activeNetwork.name].join(":") : ""
    readonly property bool runtimeMatchesActive: activeNetwork !== null
                                                 && NetworkService.runtimeDetails.interfaceName === String(
                                                     activeNetwork.deviceName || "")
    readonly property bool multipleWifiDevices: NetworkService.wifiDevices.length > 1

    function beginInitialLoad() {
        if (root.initialLoadAttempted || !NetworkService.available || !NetworkService.wifiAvailable ||
                !NetworkService.wifiEnabled)
            return;

        root.initialLoadAttempted = true;
        root.initialLoading = root.nearbyNetworks.length === 0;
        if (root.initialLoading)
            initialLoadTimer.restart();
    }

    function finishInitialLoad() {
        root.initialLoading = false;
        initialLoadTimer.stop();
    }

    function connectivityException() {
        if (NetworkService.captivePortal)
            return qsTr("Sign-in required");

        if (NetworkService.limitedConnectivity)
            return qsTr("Limited connection");

        if (NetworkService.connected && NetworkService.connectivityKnown && !NetworkService.internetAvailable)
            return qsTr("No internet connection");

        return "";
    }

    function activeWifiDetails() {
        const details = [qsTr("Signal %1%").arg(NetworkService.signalStrength)];
        const exception = root.activeNetwork && root.activeNetwork.type === "wifi"
              ? root.connectivityException() : "";
        if (exception.length > 0)
            details.push(exception);

        return details.join(" · ");
    }

    function nearbyWifiDetails(network) {
        const details = [qsTr("Signal %1%").arg(network.strength)];
        if (root.multipleWifiDevices)
            details.push(network.deviceName);

        return details.join(" · ");
    }

    function profileForTarget(target) {
        if (!target)
            return null;

        let profiles = [];
        if (target.nativeSettings) {
            profiles = target.type === "wired" ? NetworkService.wiredProfiles :
                                                 NetworkService.savedWifiProfiles;
            return profiles.find(profile => {
                return profile.uuid === target.uuid;
            }) || null;
        }
        if (target.type === "wired") {
            const interfaceName = String(target.deviceName || target.name || "");
            profiles = NetworkService.wiredProfiles.filter(profile => {
                return profile.deviceName === interfaceName;
            });
        } else {
            profiles = target.profiles || [];
        }
        if (profiles.length === 0)
            return null;

        const activeUuid = root.runtimeMatchesActive ? String(NetworkService.runtimeDetails.connectionUuid
                                                              || "") : "";
        const activeProfile = profiles.find(profile => {
            return activeUuid.length > 0 && profile.uuid === activeUuid;
        }) || null;
        if (activeProfile)
            return activeProfile;

        return profiles.length === 1 || !target.connected ? profiles[0] : null;
    }

    function wiredDeviceForProfile(profile) {
        if (!profile)
            return null;

        return NetworkService.wiredDevices.find(device => {
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
    onNearbyNetworksChanged: {
        if (root.nearbyNetworks.length > 0)
            root.finishInitialLoad();
    }
    Component.onCompleted: {
        NetworkService.acquireScan("control-center-network");
        root.refreshRuntimeDetails();
        Qt.callLater(root.beginInitialLoad);
    }
    Component.onDestruction: {
        nearbyPassword.text = "";
        root.passwordTarget = null;
        initialLoadTimer.stop();
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

        function onWifiEnabledChanged() {
            if (!NetworkService.wifiEnabled) {
                root.finishInitialLoad();
                root.initialLoadAttempted = false;
                nearbyPassword.text = "";
                root.passwordTarget = null;
            } else {
                Qt.callLater(root.beginInitialLoad);
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

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
            Layout.fillWidth: true
            radius: Metrics.cornerM
            visible: !NetworkService.available || NetworkService.lastError.length > 0
            tone: "error"
            message: NetworkService.lastError.length > 0 ? NetworkService.lastError : qsTr(
                                                               "Network service unavailable")
        }

        SettingsSection {
            Layout.fillWidth: true
            visible: NetworkService.wiredDevices.length > 0
            title: qsTr("Wired connections")
            iconName: "lan"

            Repeater {
                model: NetworkService.wiredProfiles

                SettingsRow {
                    id: wiredRow

                    required property var modelData
                    readonly property var device: root.wiredDeviceForProfile(wiredRow.modelData)
                    readonly property string detailText: {
                        const details = [];
                        const interfaceName = String(wiredRow.modelData.deviceName || "");
                        if (interfaceName.length > 0)
                            details.push(interfaceName);

                        if (!wiredRow.device)
                            return details.join(" · ");

                        if (!wiredRow.device.hasLink) {
                            details.push(qsTr("Network cable unplugged"));
                            return details.join(" · ");
                        }
                        if (wiredRow.device.connected && wiredRow.device.linkSpeed > 0)
                            details.push(qsTr("%1 Mbps").arg(wiredRow.device.linkSpeed));

                        if (wiredRow.device.connected && root.activeNetwork && root.activeNetwork.type
                                === "wired" && root.activeNetwork.deviceName === wiredRow.device.deviceName) {
                            const exception = root.connectivityException();
                            if (exception.length > 0)
                                details.push(exception);
                        }
                        return details.join(" · ");
                    }

                    Layout.fillWidth: true
                    iconName: wiredRow.device && wiredRow.device.connected ? "link" : "link_off"
                    title: wiredRow.modelData.name || wiredRow.modelData.deviceName || qsTr("Wired network")
                    supportingText: wiredRow.detailText
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
                model: NetworkService.wiredDevices.filter(device => {
                    return !NetworkService.wiredProfiles.some(profile => {
                        return profile.deviceName === device.deviceName;
                    });
                })

                SettingsRow {
                    id: unconfiguredWiredRow

                    required property var modelData

                    Layout.fillWidth: true
                    iconName: unconfiguredWiredRow.modelData.connected ? "link" : "link_off"
                    title: unconfiguredWiredRow.modelData.name || qsTr("Wired network")
                    supportingText: unconfiguredWiredRow.modelData.hasLink ? qsTr("No editable connection") :
                                                                             qsTr("Network cable unplugged")
                    highlighted: unconfiguredWiredRow.modelData.connected
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Wi-Fi")
            iconName: "wifi"

            SettingsRow {
                Layout.fillWidth: true
                iconName: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
                title: qsTr("Wi-Fi")
                supportingText: !NetworkService.available ? "" : !NetworkService.wifiAvailable ? qsTr(
                                                                                                     "No wireless adapter detected") :
                                                                                                 !NetworkService.wifiHardwareEnabled
                                                                                                 ? qsTr("Disabled by a hardware switch or rfkill") :
                                                                                                   ""

                trailing: StyledSwitch {
                    checked: NetworkService.wifiEnabled
                    enabled: NetworkService.available && NetworkService.wifiAvailable
                             && NetworkService.wifiHardwareEnabled && !NetworkService.busy
                    onToggled: NetworkService.setWifiEnabled(checked)
                }
            }

            Item {
                id: wifiExpandedRegion

                Layout.fillWidth: true
                Layout.preferredHeight: NetworkService.wifiEnabled ? expandedWifiContent.implicitHeight : 0
                opacity: NetworkService.wifiEnabled ? 1 : 0
                clip: true

                ColumnLayout {
                    id: expandedWifiContent

                    width: parent.width
                    spacing: Metrics.spacingS

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: NetworkService.activeWifi !== null
                        iconName: "wifi"
                        title: NetworkService.activeWifi ? NetworkService.activeWifi.ssid : ""
                        supportingText: root.activeWifiDetails()
                        interactive: root.profileForTarget(NetworkService.activeWifi) !== null
                        highlighted: true
                        onClicked: root.openProfile(NetworkService.activeWifi)

                        trailing: MaterialSymbol {
                            visible: root.profileForTarget(NetworkService.activeWifi) !== null
                            text: "settings"
                            iconSize: Metrics.iconS
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Nearby networks")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.labelLarge.family
                        font.pixelSize: Typography.labelLarge.pixelSize
                        font.weight: Typography.labelLarge.weight
                    }

                    Item {
                        id: nearbyViewport

                        readonly property real rowHeight: Metrics.controlHeightXL + Metrics.spacingS
                        readonly property real rowSpacing: Metrics.spacingXS
                        readonly property real viewportHeight: rowHeight * 5 + rowSpacing * 4

                        Layout.fillWidth: true
                        Layout.preferredHeight: viewportHeight
                        clip: true

                        StyledListView {
                            id: nearbyList

                            anchors.fill: parent
                            visible: !root.initialLoading && count > 0
                            opacity: visible ? 1 : 0
                            model: root.nearbyNetworks
                            spacing: nearbyViewport.rowSpacing
                            boundsBehavior: Flickable.StopAtBounds
                            fasterTouchpadScroll: true
                            showVerticalScrollBar: true
                            animateMovement: true

                            delegate: SettingsRow {
                                id: wifiRow

                                required property var modelData

                                width: ListView.view.width
                                height: nearbyViewport.rowHeight
                                iconName: wifiRow.modelData.strength >= 70 ? "signal_wifi_4_bar" :
                                                                             wifiRow.modelData.strength >= 35
                                                                             ? "network_wifi_2_bar" :
                                                                               "network_wifi_1_bar"
                                title: wifiRow.modelData.ssid
                                supportingText: root.nearbyWifiDetails(wifiRow.modelData)
                                interactive: !NetworkService.busy
                                onClicked: {
                                    if (wifiRow.modelData.isSecure && !wifiRow.modelData.known)
                                        root.passwordTarget = wifiRow.modelData;
                                    else
                                        NetworkService.connectToWifiNetwork(wifiRow.modelData);
                                }

                                trailing: RowLayout {
                                    spacing: Metrics.spacingXS

                                    MaterialSymbol {
                                        visible: wifiRow.modelData.known
                                        text: "bookmark"
                                        iconSize: Metrics.iconS
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }

                                    MaterialSymbol {
                                        visible: wifiRow.modelData.isSecure
                                        text: "lock"
                                        iconSize: Metrics.iconS
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }
                            }

                            Behavior on opacity {
                                ElementMoveAnimation {}
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: root.initialLoading
                            opacity: visible ? 1 : 0
                            spacing: Metrics.spacingS

                            MaterialLoadingIndicator {
                                anchors.horizontalCenter: parent.horizontalCenter
                                running: root.initialLoading
                                accessibleName: qsTr("Searching for nearby networks")
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Searching for nearby networks")
                                color: Appearance.colors.colOnLayer1
                                font.family: Typography.bodyMedium.family
                                font.pixelSize: Typography.bodyMedium.pixelSize
                            }

                            Behavior on opacity {
                                ElementMoveAnimation {}
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: !root.initialLoading && root.nearbyNetworks.length === 0
                            spacing: Metrics.spacingS

                            MaterialSymbol {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "search_off"
                                iconSize: Metrics.iconM
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("No nearby networks found")
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Typography.bodyMedium.family
                                font.pixelSize: Typography.bodyMedium.pixelSize
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.passwordTarget !== null
                        spacing: Metrics.spacingXS

                        OutlinedTextField {
                            id: nearbyPassword

                            Layout.fillWidth: true
                            labelText: root.passwordTarget ? qsTr("Password for %1").arg(
                                                                 root.passwordTarget.ssid) : qsTr("Password")
                            passwordToggle: true
                            errorText: text.length > 0 && text.length < 8 ? qsTr(
                                                                                "Password must be at least 8 characters") :
                                                                            ""
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Item {
                                Layout.fillWidth: true
                            }

                            ActionButton {
                                text: qsTr("Cancel")
                                onClicked: {
                                    nearbyPassword.text = "";
                                    root.passwordTarget = null;
                                }
                            }

                            ActionButton {
                                text: qsTr("Connect")
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
                }

                Behavior on opacity {
                    ElementMoveAnimation {}
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Other settings")
            iconName: "tune"

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "bookmark"
                text: qsTr("Saved networks")
                trailingIconName: "chevron_right"
                onClicked: configWindow.openSavedNetworks()
            }

            SettingsActionRow {
                Layout.fillWidth: true
                iconName: "add"
                text: qsTr("Add network")
                trailingIconName: "chevron_right"
                onClicked: configWindow.openAddNetwork()
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Connection information")
            iconName: root.activeNetwork ? (root.activeNetwork.type === "wired" ? "link" : "wifi") :
                                           "link_off"

            InlineStatusBanner {
                Layout.fillWidth: true
                radius: Metrics.cornerM
                visible: NetworkService.runtimeDetailsError.length > 0
                tone: "error"
                message: NetworkService.runtimeDetailsError
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Interface")
                supportingText: root.activeNetwork ? root.activeNetwork.deviceName : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("IP address")
                supportingText: root.runtimeMatchesActive && NetworkService.runtimeDetails.addresses
                                ? NetworkService.runtimeDetails.addresses.join(", ") : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Gateway")
                supportingText: root.runtimeMatchesActive ? NetworkService.runtimeDetails.gateway || "—" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("DNS")
                supportingText: root.runtimeMatchesActive && NetworkService.runtimeDetails.dns
                                ? NetworkService.runtimeDetails.dns.join(", ") : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("MAC")
                supportingText: root.activeNetwork ? root.activeNetwork.address || "—" : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null && root.activeNetwork.type === "wifi"
                title: qsTr("Security type")
                supportingText: root.activeNetwork ? root.activeNetwork.security || qsTr("Unknown") : "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null && root.activeNetwork.type === "wifi"
                title: qsTr("Frequency")
                supportingText: root.runtimeMatchesActive ? NetworkService.runtimeDetails.frequency || "—" :
                                                            "—"
            }

            SettingsRow {
                Layout.fillWidth: true
                visible: root.activeNetwork !== null && root.activeNetwork.type === "wired"
                title: qsTr("Link speed")
                supportingText: root.activeNetwork && root.activeNetwork.linkSpeed > 0 ? qsTr("%1 Mbps").arg(
                                                                                             root.activeNetwork.linkSpeed) :
                                                                                         "—"
            }
        }
    }

    NetworkConfigWindow {
        id: configWindow

        parentModal: root.parentModal
    }
}
