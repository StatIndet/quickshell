import QtQuick
import Quickshell
import qs.Common
import qs.Widgets.common

Rectangle {
    id: root
    property bool isHovered: mouseArea.containsMouse

    color: Appearance.colors.colSecondaryContainer 
    radius: height / 2
    implicitHeight: isHovered ? 34 : 28
    implicitWidth: isHovered ? 34 : 28

    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true 
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            WidgetState.leftSidebarView = "info";
            WidgetState.leftSidebarOpen = true;
        }
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "\uf0f3"
        font.family: "Font Awesome 6 Free Solid"
        font.pixelSize: root.isHovered ? 14 : 12
        color: Appearance.colors.colOnSecondaryContainer 
        Behavior on font.pixelSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: "通知"
    }
}
