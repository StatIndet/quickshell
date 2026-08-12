import QtQuick
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root
    property bool isHovered: mouseArea.containsMouse
    readonly property int buttonSize: Sizes.barControlCircleSize
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

        MaterialSymbol {
            id: icon
            anchors.centerIn: parent
            width: root.isHovered ? 20 : 18
            height: width
            text: "power_settings_new"
            iconSize: root.isHovered ? 18 : 16
            fill: 1
            color: Appearance.colors.colOnError

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached([
            Paths.systemScriptsDir + "/power-menu.sh",
            PersonalizationConfig.powerMenuStyle
        ])
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: qsTr("电源菜单")
    }
}
