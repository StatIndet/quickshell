import QtQuick
import Quickshell
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property bool isHovered: mouseArea.containsMouse
    readonly property bool active: WidgetState.qsOpen && WidgetState.qsView === "settings"
    readonly property int buttonSize: 28
    readonly property int hoverButtonSize: 34

    implicitHeight: buttonSize
    implicitWidth: buttonSize

    Rectangle {
        id: background
        anchors.centerIn: parent
        width: root.isHovered ? root.hoverButtonSize : root.buttonSize
        height: width
        radius: height / 2
        color: Appearance.colors.colPrimaryContainer

        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "settings"
            iconSize: root.isHovered ? 20 : 18
            fill: 0
            color: Appearance.colors.colOnPrimaryContainer

            Behavior on iconSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.active) {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "settings";
                WidgetState.qsOpen = true;
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: "设置"
    }
}
