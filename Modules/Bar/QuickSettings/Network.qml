import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Services
import qs.Common
import qs.Widgets.common

Rectangle {
    id: root
    
    property bool isHovered: mouseArea.containsMouse
    
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
            font.family: "JetBrainsMono Nerd Font" 
            font.pixelSize: 14 
            Layout.alignment: Qt.AlignVCenter
            color: Appearance.colors.colOnPrimaryContainer 
            text: {
                if (Network.activeConnectionType === "ETHERNET") return "󰈀";
                if (!Network.connected) return "󰤭"; 
                let strength = Network.signalStrength; 
                if (strength >= 80) return "󰤨";
                if (strength >= 60) return "󰤥";
                if (strength >= 40) return "󰤢";
                if (strength >= 20) return "󰤟";
                return "󰤯";
            }
        }

        Text {
            id: nameText
            text: Network.activeConnection 
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
            if (WidgetState.qsOpen && WidgetState.qsView === "network") {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "network";
                WidgetState.qsOpen = true;
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: Network.connected
              ? ((Network.activeConnection || "网络已连接") + "\n点击打开网络设置")
              : "网络未连接\n点击打开网络设置"
    }
}
