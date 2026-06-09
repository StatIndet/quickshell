import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

WidgetPanel {
    id: root
    title: "蓝牙"
    icon: "bluetooth"
    closeAction: () => WidgetState.qsOpen = false

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "bluetooth"
    property string mdFont: "Material Symbols Outlined"

    onIsActiveChanged: {
        if (isActive)
            BluetoothService.refreshDevices();
    }

    headerTools: RowLayout {
        spacing: 12

        Rectangle {
            id: mainSwitch
            width: 44; height: 24; radius: 12
            color: BluetoothService.enabled ? Appearance.colors.colPrimary : "transparent"
            border.width: BluetoothService.enabled ? 0 : 2
            border.color: Appearance.colors.colOutline
            Behavior on color { ColorAnimation { duration: 250 } }

            Rectangle {
                width: BluetoothService.enabled ? 16 : 12
                height: BluetoothService.enabled ? 16 : 12
                radius: width / 2
                x: BluetoothService.enabled ? parent.width - width - 4 : 6
                anchors.verticalCenter: parent.verticalCenter
                color: BluetoothService.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colOutline

                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                Text {
                    anchors.centerIn: parent
                    text: "check"
                    font.family: root.mdFont
                    font.pixelSize: 12
                    font.bold: true
                    color: Appearance.colors.colPrimary
                    opacity: BluetoothService.enabled ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.toggle()
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        // Scanning indicator
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 0
        }

        // Connected devices
        Text {
            visible: connectedDevices.count > 0
            text: "已连接"
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer1
            font.bold: true
        }

        StyledListView {
            id: connectedDevices
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            visible: BluetoothService.enabled && count > 0
            clip: true
            spacing: 4
            model: BluetoothService.devices.filter(d => d.connected)
            interactive: false

            delegate: BluetoothDeviceItem {
                width: ListView.view.width
            }
        }

        // Paired devices
        Text {
            visible: pairedDevices.count > 0
            text: "已配对"
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer1
            font.bold: true
            Layout.topMargin: connectedDevices.count > 0 ? 8 : 0
        }

        StyledListView {
            id: pairedDevices
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            visible: BluetoothService.enabled && count > 0
            clip: true
            spacing: 4
            model: BluetoothService.devices.filter(d => d.paired && !d.connected)
            interactive: false

            delegate: BluetoothDeviceItem {
                width: ListView.view.width
            }
        }

        // Available devices
        Text {
            visible: availableDevices.count > 0
            text: "可用设备"
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer1
            font.bold: true
            Layout.topMargin: (connectedDevices.count > 0 || pairedDevices.count > 0) ? 8 : 0
        }

        StyledListView {
            id: availableDevices
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            visible: BluetoothService.enabled && count > 0
            clip: true
            spacing: 4
            model: BluetoothService.devices.filter(d => !d.paired)
            interactive: false

            delegate: BluetoothDeviceItem {
                width: ListView.view.width
            }
        }

        // Empty state
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !BluetoothService.enabled || BluetoothService.devices.length === 0
            spacing: 12

            Item { Layout.fillHeight: true }

            Text {
                text: BluetoothService.enabled ? "searching" : "bluetooth_disabled"
                font.family: root.mdFont
                font.pixelSize: 48
                color: Appearance.colors.colOnLayer1
                opacity: 0.3
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: BluetoothService.enabled ? "正在搜索设备..." : "蓝牙已关闭"
                font.pixelSize: 14
                color: Appearance.colors.colOnLayer1
                opacity: 0.5
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    component BluetoothDeviceItem: Rectangle {
        id: itemRoot

        required property var modelData
        readonly property string deviceName: modelData ? modelData.name : "未知设备"
        readonly property string deviceMac: modelData ? modelData.mac : ""
        readonly property bool deviceConnected: modelData ? modelData.connected : false
        readonly property bool deviceTrusted: modelData ? modelData.trusted : false
        readonly property bool devicePaired: modelData ? modelData.paired : false

        height: deviceRow.implicitHeight + 24
        radius: 10
        clip: true
        color: {
            if (itemRoot.deviceConnected)
                return Appearance.colors.colLayer3;
            if (deviceMouseArea.pressed)
                return Appearance.colors.colLayer2Active;
            if (deviceMouseArea.containsMouse)
                return Appearance.colors.colLayer2Hover;
            return "transparent";
        }

        Behavior on color { ColorAnimation { duration: 140 } }

        MouseArea {
            id: deviceMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (itemRoot.deviceConnected)
                    BluetoothService.disconnectDevice(itemRoot.deviceMac);
                else if (itemRoot.devicePaired)
                    BluetoothService.connectDevice(itemRoot.deviceMac);
                else
                    BluetoothService.pairDevice(itemRoot.deviceMac);
            }
        }

        RowLayout {
            id: deviceRow
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 14
                rightMargin: 14
                topMargin: 12
            }
            spacing: 12

            Text {
                text: itemRoot.deviceConnected ? "bluetooth_connected" : "bluetooth"
                font.family: root.mdFont
                font.pixelSize: 24
                color: itemRoot.deviceConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: itemRoot.deviceName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: 14
                    color: itemRoot.deviceConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (itemRoot.deviceConnected) return "已连接";
                        if (itemRoot.devicePaired) return "已配对";
                        return itemRoot.deviceMac;
                    }
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
            }

            Text {
                text: {
                    if (itemRoot.deviceConnected) return "link_off";
                    if (itemRoot.devicePaired) return "link";
                    return "add";
                }
                font.family: root.mdFont
                font.pixelSize: 20
                color: itemRoot.deviceConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (itemRoot.deviceConnected)
                            BluetoothService.disconnectDevice(itemRoot.deviceMac);
                        else if (itemRoot.devicePaired)
                            BluetoothService.connectDevice(itemRoot.deviceMac);
                        else
                            BluetoothService.pairDevice(itemRoot.deviceMac);
                    }
                }
            }
        }
    }
}
