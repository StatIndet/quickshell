import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root
    property bool isHovered: mouseArea.containsMouse
    readonly property int buttonSize: 28

    implicitHeight: buttonSize
    implicitWidth: buttonSize

    Rectangle {
        id: background
        anchors.centerIn: parent
        width: root.buttonSize
        height: width
        radius: height / 2
        color: Appearance.colors.colError
        scale: root.isHovered ? 1.14 : 1

        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Text {
            id: icon
            anchors.centerIn: parent
            text: "power_settings_new"
            font.family: Sizes.fontMaterialSymbols
            font.pixelSize: 18
            font.weight: Font.Normal
            color: Appearance.colors.colOnError
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
