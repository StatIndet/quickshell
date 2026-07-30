import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Clavis.Niri 1.0
import qs.Common
import qs.Services

Item {
    id: root

    implicitHeight: 36
    implicitWidth: layout.width + 24

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    readonly property var activeWindow: Niri.focusedWindow
    readonly property string activeTitle: activeWindow.title || qsTr("桌面")
    readonly property string activeIcon: activeWindow.iconPath || ""
    readonly property string activeAppName: activeWindow.appName || activeWindow.appId || ""

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: BlurService.backgroundColor(
            Appearance.colors.colLayer0)
        radius: height / 2
        visible: false
    }

    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        spacing: 10

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            visible: root.activeIcon !== "" || root.activeAppName !== ""

            Image {
                id: appIcon
                anchors.fill: parent
                source: root.activeIcon
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                visible: root.activeIcon !== "" && status !== Image.Error
            }

            Text {
                anchors.centerIn: parent
                text: (root.activeAppName || "?").charAt(0).toUpperCase()
                color: Appearance.colors.colPrimary
                font.pixelSize: 13
                font.bold: true
                visible: !appIcon.visible
            }
        }

        Text {
            id: windowTitle
            text: root.activeTitle

            font.family: "Noto Sans CJK SC"
            font.pointSize: 11
            color: Appearance.colors.colOnSurface

            Layout.maximumWidth: 250
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
