import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property string deviceAddress: ""
    property string deviceAdapterId: ""
    property bool pageReady: false
    readonly property var device: BluetoothService.devices.find((candidate) => {
        return candidate.address === root.deviceAddress && (root.deviceAdapterId.length === 0 || candidate.adapterId === root.deviceAdapterId);
    }) || null
    readonly property string pageTitle: root.device ? root.device.name : qsTr("蓝牙设备")
    readonly property bool deviceChanging: root.device && (root.device.connecting || root.device.disconnecting || root.device.pairing)

    signal returnRequested()

    function statusText() {
        if (!root.device)
            return "";

        if (root.device.blocked)
            return qsTr("已阻止");

        if (root.device.connecting)
            return qsTr("正在连接…");

        if (root.device.disconnecting)
            return qsTr("正在断开连接…");

        if (root.device.connected)
            return root.device.batteryAvailable ? qsTr("已连接 · %1%").arg(root.device.batteryLevel) : qsTr("已连接");

        return qsTr("已保存");
    }

    function ensureDeviceAvailable() {
        if (root.pageReady && !root.device)
            root.returnRequested();

    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2
    onDeviceChanged: root.ensureDeviceAvailable()
    Component.onCompleted: {
        root.pageReady = true;
        root.ensureDeviceAvailable();
    }

    Connections {
        function onEnabledChanged() {
            if (!BluetoothService.enabled)
                root.returnRequested();

        }

        function onOperationSucceeded(operation) {
            if (operation === "forget")
                root.returnRequested();

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

            SettingsRow {
                Layout.fillWidth: true
                iconName: BluetoothDeviceIcon.iconName(root.device)
                title: root.statusText()
                highlighted: root.device ? root.device.connected : false

                trailing: ActionButton {
                    visible: root.device !== null
                    enabled: root.device && BluetoothService.enabled && !BluetoothService.busy && !root.deviceChanging && (!root.device.blocked || root.device.connected)
                    filled: root.device ? !root.device.connected : false
                    iconName: root.device && root.device.connected ? "link_off" : "link"
                    text: root.device && root.device.connected ? qsTr("断开连接") : qsTr("连接")
                    onClicked: {
                        if (!root.device)
                            return ;

                        if (root.device.connected)
                            BluetoothService.disconnectDevice(root.device);
                        else
                            BluetoothService.connectDevice(root.device);
                    }
                }

            }

            SettingsActionRow {
                Layout.fillWidth: true
                enabled: root.device !== null && !BluetoothService.busy
                iconName: "delete"
                text: qsTr("遗忘设备")
                trailingIconName: ""
                onClicked: forgetDialog.open()
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("连接", "Bluetooth settings section")
            iconName: "link"

            SettingsRow {
                Layout.fillWidth: true
                iconName: "verified_user"
                title: qsTr("受信任设备")

                trailing: StyledSwitch {
                    checked: root.device ? root.device.trusted : false
                    enabled: root.device !== null && !BluetoothService.busy
                    Accessible.name: qsTr("受信任设备")
                    onToggled: {
                        if (root.device)
                            BluetoothService.setDeviceTrusted(root.device, checked);

                    }
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "block"
                title: qsTr("阻止设备")

                trailing: StyledSwitch {
                    checked: root.device ? root.device.blocked : false
                    enabled: root.device !== null && !BluetoothService.busy
                    Accessible.name: qsTr("阻止设备")
                    onToggled: {
                        if (root.device)
                            BluetoothService.setDeviceBlocked(root.device, checked);

                    }
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "power_settings_new"
                title: qsTr("允许唤醒")

                trailing: StyledSwitch {
                    checked: root.device ? root.device.wakeAllowed : false
                    enabled: root.device !== null && !BluetoothService.busy
                    Accessible.name: qsTr("允许设备唤醒系统")
                    onToggled: {
                        if (root.device)
                            BluetoothService.setDeviceWakeAllowed(root.device, checked);

                    }
                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("设备信息")
            iconName: "info"

            SettingsRow {
                Layout.fillWidth: true
                iconName: "battery_full"
                title: qsTr("电池")
                supportingText: root.device && root.device.batteryAvailable ? qsTr("%1%").arg(root.device.batteryLevel) : qsTr("不可用")

                trailing: ThinReadOnlySlider {
                    visible: root.device && root.device.batteryAvailable
                    Layout.preferredWidth: visible ? Math.min(180, Math.max(80, root.width * 0.28)) : 0
                    value: root.device && root.device.batteryAvailable ? root.device.battery : 0
                    Accessible.name: root.device && root.device.batteryAvailable ? qsTr("设备电量 %1%").arg(root.device.batteryLevel) : qsTr("设备电量不可用")
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "fingerprint"
                title: qsTr("地址")
                supportingText: root.device ? root.device.address : ""
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "settings_bluetooth"
                title: qsTr("适配器")
                supportingText: root.device ? root.device.adapterId : ""
            }

        }

    }

    MaterialDialog {
        id: forgetDialog

        anchors.centerIn: Overlay.overlay
        width: Math.min(420, root.width - Metrics.spacingL * 2)
        dialogTitle: root.device ? qsTr("遗忘“%1”？").arg(root.device.name) : qsTr("遗忘设备？")
        messageText: qsTr("这会删除该设备保存的蓝牙配对信息。")

        actionsComponent: Component {
            RowLayout {
                spacing: Metrics.spacingS

                Item {
                    Layout.fillWidth: true
                }

                ActionButton {
                    text: qsTr("取消")
                    onClicked: forgetDialog.close()
                }

                ActionButton {
                    enabled: root.device !== null && !BluetoothService.busy
                    text: qsTr("遗忘")
                    onClicked: {
                        const target = root.device;
                        forgetDialog.close();
                        if (target)
                            BluetoothService.forgetDevice(target);

                    }
                }

            }

        }

    }

}
