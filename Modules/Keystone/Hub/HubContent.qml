import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Components
import qs.Modules.Keystone.CloudUploadContent
import qs.Modules.Keystone.DashboardContent
import qs.Modules.Keystone.WeatherContent

Item {
    id: root

    property var screen: null
    property int currentIndex: 0
    property bool dragActive: false
    readonly property var dashboardKeyholeGlassItems: dashboardContent.keyholeGlassItems
    readonly property real dashboardKeyholeCenterOffset: dashboardContent.keyholeCenterOffset

    signal closeRequested
    signal avatarEditRequested

    function cycleTab(step) {
        const count = tabBar.children.length;
        if (count > 0)
            root.currentIndex = ((root.currentIndex + step) % count + count) % count;
    }

    function finishCloudUploadDrop(addedCount) {
        cloudUploadContent.finishDrop(addedCount);
    }

    implicitWidth: currentIndex === 0 ? dashboardContent.implicitWidth : 960
    implicitHeight: 100 + (currentIndex === 0 ? 520 : currentIndex === 1 ? 480 : weatherContent.height)

    Shortcut {
        enabled: root.visible
        sequence: "Tab"
        onActivated: root.cycleTab(1)
    }

    Shortcut {
        enabled: root.visible
        sequence: "Shift+Tab"
        onActivated: root.cycleTab(-1)
    }

    RowLayout {
        id: tabBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        anchors.margins: 10
        spacing: 15

        TabBtn {
            icon: "dashboard"
            title: qsTr("Dashboard")
            index: 0
        }

        TabBtn {
            icon: "cloud_upload"
            title: qsTr("Upload")
            index: 1
        }

        TabBtn {
            icon: "sunny"
            title: qsTr("Weather")
            index: 2
        }
    }

    component TabBtn: Item {
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
                color: parent.parent.active ? Appearance.colors.colOnLayer0 : Appearance.applyAlpha(
                                                  Appearance.colors.colOnLayer0, 0.5)
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            Text {
                text: parent.parent.title
                font.pixelSize: 13
                font.bold: parent.parent.active
                color: parent.parent.active ? Appearance.colors.colOnLayer0 : Appearance.applyAlpha(
                                                  Appearance.colors.colOnLayer0, 0.5)
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.active ? 40 : 0
            height: 3
            radius: 1.5
            color: Appearance.colors.colPrimary
            opacity: parent.active ? 1 : 0

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutBack
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentIndex = parent.index
        }
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10

        DashboardContent {
            id: dashboardContent

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            screen: root.screen
            visible: root.currentIndex === 0
            opacity: visible ? 1 : 0
            onCloseRequested: root.closeRequested()
            onAvatarEditRequested: root.avatarEditRequested()

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }

        CloudUploadContent {
            id: cloudUploadContent

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.95
            height: 480
            dragActive: root.dragActive
            visible: root.currentIndex === 1
            opacity: visible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }

        WeatherContent {
            id: weatherContent

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.currentIndex === 2 && root.visible
            visible: root.currentIndex === 2
            opacity: visible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }
    }
}
