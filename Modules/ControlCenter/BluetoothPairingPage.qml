import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property bool presentationActive: false
    property bool pageReady: false
    property bool discoveryLeaseAcquired: false
    property string pendingAddress: ""

    signal returnRequested()

    function updateDiscoveryLease() {
        const requested = root.pageReady && root.presentationActive && BluetoothService.available && BluetoothService.enabled;
        if (requested && !root.discoveryLeaseAcquired) {
            BluetoothService.acquireDiscovery("control-center-bluetooth-pairing");
            root.discoveryLeaseAcquired = true;
        } else if (!requested && root.discoveryLeaseAcquired) {
            BluetoothService.releaseDiscovery("control-center-bluetooth-pairing");
            root.discoveryLeaseAcquired = false;
        }
    }

    function closeChildWindows() {
        if (root.discoveryLeaseAcquired) {
            BluetoothService.releaseDiscovery("control-center-bluetooth-pairing");
            root.discoveryLeaseAcquired = false;
        }
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2
    onPresentationActiveChanged: root.updateDiscoveryLease()
    Component.onCompleted: {
        root.pageReady = true;
        root.updateDiscoveryLease();
    }
    Component.onDestruction: root.closeChildWindows()

    Connections {
        function onAvailableChanged() {
            root.updateDiscoveryLease();
            if (!BluetoothService.available)
                root.returnRequested();

        }

        function onEnabledChanged() {
            root.updateDiscoveryLease();
            if (!BluetoothService.enabled)
                root.returnRequested();

        }

        function onOperationSucceeded(operation) {
            if (operation === "pair" && root.pendingAddress.length > 0) {
                root.pendingAddress = "";
                root.returnRequested();
            }
        }

        function onOperationFailed(operation, message) {
            if (operation === "pair")
                root.pendingAddress = "";

        }

        target: BluetoothService
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: BluetoothService.lastError.length > 0
            tone: "error"
            message: BluetoothService.lastError
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("附近设备")
            iconName: "bluetooth_searching"

            SettingsRow {
                Layout.fillWidth: true
                iconName: BluetoothService.discovering ? "radar" : "search_off"
                title: BluetoothService.discovering ? qsTr("正在搜索附近设备") : qsTr("等待蓝牙扫描")

                trailing: MaterialLoadingIndicator {
                    visible: BluetoothService.discovering
                    Layout.preferredWidth: visible ? Metrics.controlHeightM : 0
                    Layout.preferredHeight: Metrics.controlHeightM
                    running: visible
                    contained: false
                    accessibleName: qsTr("正在搜索附近蓝牙设备")
                }

            }

            Repeater {
                model: BluetoothService.availableDevices

                SettingsRow {
                    id: availableDeviceRow

                    required property var modelData

                    Layout.fillWidth: true
                    iconName: BluetoothDeviceIcon.iconName(availableDeviceRow.modelData)
                    title: availableDeviceRow.modelData.name
                    supportingText: availableDeviceRow.modelData.pairing ? qsTr("正在配对…") : availableDeviceRow.modelData.address
                    interactive: enabled
                    enabled: !BluetoothService.busy && !availableDeviceRow.modelData.blocked
                    onClicked: {
                        root.pendingAddress = availableDeviceRow.modelData.address;
                        BluetoothService.pairDevice(availableDeviceRow.modelData);
                    }

                    trailing: MaterialLoadingIndicator {
                        visible: availableDeviceRow.modelData.pairing
                        Layout.preferredWidth: visible ? Metrics.controlHeightM : 0
                        Layout.preferredHeight: Metrics.controlHeightM
                        running: visible
                        contained: false
                        accessibleName: qsTr("正在配对 %1").arg(availableDeviceRow.modelData.name)
                    }

                }

            }

            SettingsRow {
                Layout.fillWidth: true
                visible: BluetoothService.availableDevices.length === 0
                iconName: "devices_other"
                title: qsTr("尚未发现附近设备")
            }

        }

    }

}
