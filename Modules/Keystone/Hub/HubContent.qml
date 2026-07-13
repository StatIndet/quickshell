import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Components

import qs.Modules.Keystone.DashboardContent
import qs.Modules.Keystone.Media
import qs.Modules.Keystone.WallpaperContent
import qs.Modules.Keystone.WeatherContent

Item {
    id: root
    signal closeRequested()
    signal avatarEditRequested()
    
    property var player: null
    property int currentIndex: 0
    
    Shortcut {
        sequence: "Tab"
        onActivated: root.currentIndex = (root.currentIndex + 1) % 4
    }

    Shortcut {
        sequence: "Shift+Tab"
        onActivated: root.currentIndex = (root.currentIndex + 3) % 4
    }
    
    // 【恢复 860 总宽】
    implicitWidth: currentIndex === 0 ? 860 : 
                   currentIndex === 2 ? 960 : 
                   760
    Behavior on implicitWidth { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    
    implicitHeight: 80 + 20 + (
        currentIndex === 0 ? 520 : 
        currentIndex === 1 ? 480 : 
        currentIndex === 2 ? 300 : 
        540             
    )
    Behavior on implicitHeight { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    RowLayout {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        anchors.margins: 10
        spacing: 15

        component TabBtn : Item {
            property string icon: ""
            property string title: ""
            property int index: 0
            property bool active: root.currentIndex === index
            
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: parent.parent.icon
                    iconSize: 22
                    fill: parent.parent.active ? 1 : 0
                    color: parent.parent.active
                           ? Appearance.colors.colOnLayer0
                           : Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.50)
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: parent.parent.title
                    font.pixelSize: 13
                    font.bold: parent.parent.active
                    color: parent.parent.active
                           ? Appearance.colors.colOnLayer0
                           : Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.50)
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.active ? 40 : 0
                height: 3
                radius: 1.5
                color: Appearance.colors.colPrimary
                opacity: parent.active ? 1.0 : 0.0
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentIndex = parent.index
            }
        }

        TabBtn { icon: "dashboard"; title: "Dashboard"; index: 0 }
        TabBtn { icon: "queue_music"; title: "Media"; index: 1 }
        TabBtn { icon: "wallpaper"; title: "Wallpapers"; index: 2 }
        TabBtn { icon: "sunny"; title: "Weather"; index: 3 }
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10 

        DashboardContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 0
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onCloseRequested: root.closeRequested()
            onAvatarEditRequested: root.avatarEditRequested()
        }

        Media {
            player: root.player
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 1
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        WallpaperContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.95 
            height: 300
            visible: root.currentIndex === 2
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onWallpaperChanged: root.closeRequested()
        }

        WeatherContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 3
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
    }
}
