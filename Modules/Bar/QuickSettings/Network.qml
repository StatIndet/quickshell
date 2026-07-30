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

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

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
                if (NetworkService.activeConnectionType === "ETHERNET") return "󰈀";
                if (!NetworkService.connected) return "󰤭";
                let strength = NetworkService.signalStrength;
                if (strength >= 80) return "󰤨";
                if (strength >= 60) return "󰤥";
                if (strength >= 40) return "󰤢";
                if (strength >= 20) return "󰤟";
                return "󰤯";
            }
        }

        Text {
            id: nameText
            text: NetworkService.activeConnection
            font.bold: true 
            font.pixelSize: 12 
            color: Appearance.colors.colOnPrimaryContainer 
            Layout.alignment: Qt.AlignVCenter
            visible: root.isHovered
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
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
        text: NetworkService.connected
              ? ((NetworkService.activeConnection || qsTr("网络已连接")) + qsTr("\n点击打开网络设置"))
              : qsTr("网络未连接\n点击打开网络设置")
    }
}
