import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    implicitWidth: 36
    implicitHeight: 36

    Rectangle {
        id: background

        anchors.fill: parent
        radius: height / 2
        color: mouseArea.containsMouse
            ? Appearance.colors.colPrimary
            : BlurService.backgroundColor(Appearance.colors.colLayer0)

        Behavior on color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }

    MultiEffect {
        anchors.fill: background
        source: background
        shadowEnabled: true
        shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
    }

    Text {
        anchors.centerIn: parent
        text: "apps"
        color: mouseArea.containsMouse
            ? Appearance.colors.colOnPrimary
            : Appearance.colors.colOnSurface
        font.family: Sizes.fontMaterialSymbols
        font.pixelSize: 21
        font.weight: Font.Normal

        Behavior on color {
            ColorAnimation { duration: 160 }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: LauncherService.toggle()
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: qsTr("应用启动器")
    }
}
