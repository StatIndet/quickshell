import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    property var screen: null

    implicitHeight: 28
    implicitWidth: isHovered ? (layout.width + 20) : 28
    radius: height / 2
    color: Appearance.colors.colPrimaryContainer

    Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6
        width: isHovered ? implicitWidth : iconText.implicitWidth

        Text {
            id: iconText
            font.family: "Material Symbols Outlined"
            font.pixelSize: 16
            Layout.alignment: Qt.AlignVCenter
            color: Appearance.colors.colOnPrimaryContainer
            text: {
                if (!BluetoothService.available) return "bluetooth_disabled";
                if (BluetoothService.connected) return "bluetooth_connected";
                if (BluetoothService.enabled) return "bluetooth";
                return "bluetooth_disabled";
            }
        }

        Text {
            id: nameText
            text: {
                if (!BluetoothService.available) return "不可用";
                if (BluetoothService.connected) return BluetoothService.connectedName || "已连接";
                if (BluetoothService.enabled) return "蓝牙";
                return "关闭";
            }
            font.bold: true
            font.pixelSize: 12
            color: Appearance.colors.colOnPrimaryContainer
            Layout.alignment: Qt.AlignVCenter
            visible: root.isHovered
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.screen && root.screen.name)
                WidgetState.qsScreenName = root.screen.name;
            if (WidgetState.qsOpen && WidgetState.qsView === "bluetooth") {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "bluetooth";
                WidgetState.qsOpen = true;
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: BluetoothService.connected
              ? ((BluetoothService.connectedName || "蓝牙已连接") + "\n点击打开蓝牙设置")
              : BluetoothService.enabled
                ? "蓝牙已开启\n点击打开蓝牙设置"
                : "蓝牙已关闭\n点击打开蓝牙设置"
    }
}
