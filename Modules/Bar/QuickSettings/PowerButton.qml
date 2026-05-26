import QtQuick
import Quickshell
import qs.Common
import qs.Widgets.common

Item {
    id: root
    property bool isHovered: mouseArea.containsMouse
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
        color: Appearance.colors.colError

        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Text {
            id: icon
            anchors.centerIn: parent
            text: "⏻"
            font.pixelSize: root.isHovered ? 16 : 14
            font.bold: true
            color: Appearance.colors.colOnError
            Behavior on font.pixelSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["wlogout", "-p", "layer-shell", "-b", "2"])
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: "电源"
    }
}
