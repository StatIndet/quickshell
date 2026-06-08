import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common

import qs.Modules.DynamicIsland.OverviewContent
import qs.Modules.DynamicIsland.Media
import qs.Modules.DynamicIsland.WallpaperContent
import qs.Modules.DynamicIsland.WeatherContent
import qs.Modules.DynamicIsland.Tools

Item {
    id: root
    signal closeRequested()
    signal requestSetRecording(bool state)
    signal requestShowAudio(string mode)

    property var player: null
    property int currentIndex: 0
    
    Shortcut {
        sequence: "Tab"
        onActivated: root.currentIndex = (root.currentIndex + 1) % 5
    }

    Shortcut {
        sequence: "Shift+Tab"
        onActivated: root.currentIndex = (root.currentIndex + 4) % 5
    }
    
    // 【恢复 860 总宽】
    implicitWidth: currentIndex === 0 ? 860 :
                   currentIndex === 2 ? 960 :
                   currentIndex === 4 ? 480 :
                   760
    Behavior on implicitWidth { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    implicitHeight: 80 + 20 + (
        currentIndex === 0 ? 520 :
        currentIndex === 1 ? 480 :
        currentIndex === 2 ? 300 :
        currentIndex === 4 ? 72 :
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
                Text {
                    text: parent.parent.icon
                    font.family: "Font Awesome 6 Free Solid"
                    font.pixelSize: 20
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

        TabBtn { icon: ""; title: "Overview"; index: 0 }
        TabBtn { icon: ""; title: "Media"; index: 1 }
        TabBtn { icon: ""; title: "Wallpapers"; index: 2 }
        TabBtn { icon: ""; title: "Weather"; index: 3 }
        TabBtn { icon: ""; title: "Tools"; index: 4 }
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10 

        OverviewContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 0
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onCloseRequested: root.closeRequested()
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

        ToolsContent {
            anchors.top: parent.top
            anchors.topMargin: 5
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 4
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onRequestHideIsland: root.closeRequested()
            onRequestSetRecording: (state) => root.requestSetRecording(state)
            onRequestShowAudio: (mode) => root.requestShowAudio(mode)
        }
    }
}
