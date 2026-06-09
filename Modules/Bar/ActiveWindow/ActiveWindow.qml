import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common

Item {
    id: root

    property string windowTitle: "Desktop"
    property string windowAppId: ""
    property bool popupOpen: false
    property var windowList: []

    implicitHeight: 36
    implicitWidth: layout.width + 24

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: refreshActiveWindow()

    function refreshActiveWindow() {
        activeWindowProcess.running = true
    }

    function parseActiveWindowOutput(text) {
        if (!text || text.trim().length === 0) {
            root.windowTitle = "Desktop"
            root.windowAppId = ""
            return
        }

        const lines = text.trim().split("\n")
        if (lines.length >= 1) {
            root.windowTitle = lines[0] || "Desktop"
        }
        if (lines.length >= 2) {
            root.windowAppId = lines[1] || ""
        }
    }

    function refreshWindowList() {
        const toplevels = ToplevelManager.toplevels
        const list = []
        for (let i = 0; i < toplevels.count; i++) {
            const tl = toplevels.objectAt(i)
            if (!tl) continue
            list.push({
                toplevel: tl,
                title: tl.title || "未知窗口",
                appId: tl.appId || ""
            })
        }
        root.windowList = list
    }

    function togglePopup() {
        if (root.popupOpen) {
            root.popupOpen = false
        } else {
            root.refreshWindowList()
            root.popupOpen = true
        }
    }

    Connections {
        target: ToplevelManager
        function onToplevelsChanged() {
            if (root.popupOpen)
                root.refreshWindowList()
        }
    }

    // 获取活动窗口信息
    Process {
        id: activeWindowProcess
        command: ["bash", "-c", "kdotool getactivewindow getwindowname 2>/dev/null || echo 'Desktop'"]

        stdout: StdioCollector {
            onStreamFinished: root.parseActiveWindowOutput(this.text)
        }
    }

    // 定时刷新
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refreshActiveWindow()
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: root.popupOpen ? Appearance.colors.colLayer3 : Appearance.colors.colLayer0
        radius: height / 2
        visible: false

        Behavior on color { ColorAnimation { duration: 200 } }
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
            visible: root.windowAppId !== ""

            Image {
                id: appIcon
                anchors.fill: parent
                source: root.windowAppId ? "image://icon/" + root.windowAppId : ""
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                visible: root.windowAppId !== "" && status !== Image.Error
            }

            Text {
                anchors.centerIn: parent
                text: (root.windowAppId || "?").charAt(0).toUpperCase()
                color: Appearance.colors.colPrimary
                font.pixelSize: 13
                font.bold: true
                visible: !appIcon.visible
            }
        }

        Text {
            id: windowTitleText
            text: root.windowTitle

            font.family: "LXGW WenKai GB Screen"
            font.pointSize: 11
            color: Appearance.colors.colOnSurface

            Layout.maximumWidth: 250
            elide: Text.ElideRight
            Layout.alignment: Qt.AlignVCenter
        }

        // Dropdown arrow
        Text {
            text: root.popupOpen ? "expand_less" : "expand_more"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 18
            color: Appearance.colors.colOnSurface
            opacity: 0.6
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePopup()
        z: 10
    }

    // Window list popup
    Rectangle {
        id: popup
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: 320
        height: Math.min(root.windowList.length * 44 + 16, 400)
        radius: 16
        color: Appearance.colors.colLayer1
        visible: root.popupOpen
        z: 100

        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        // Shadow
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.3)
            shadowBlur: 0.6
            shadowVerticalOffset: 4
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0

            Text {
                text: root.windowList.length + " 个窗口"
                font.pixelSize: 12
                color: Appearance.colors.colOnLayer1
                opacity: 0.6
                Layout.leftMargin: 8
                Layout.bottomMargin: 4
                visible: root.windowList.length > 0
            }

            ListView {
                id: windowListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.windowList

                delegate: Rectangle {
                    width: windowListView.width
                    height: 40
                    radius: 10
                    color: delegateMouseArea.pressed ? Appearance.colors.colLayer2Active : delegateMouseArea.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"

                    Behavior on color { ColorAnimation { duration: 140 } }

                    MouseArea {
                        id: delegateMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.toplevel)
                                modelData.toplevel.activate()
                            root.popupOpen = false
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                id: delegateIcon
                                anchors.fill: parent
                                source: modelData.appId ? "image://icon/" + modelData.appId : ""
                                sourceSize.width: 44
                                sourceSize.height: 44
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                visible: modelData.appId !== "" && status !== Image.Error
                            }

                            Text {
                                anchors.centerIn: parent
                                text: (modelData.appId || "?").charAt(0).toUpperCase()
                                color: Appearance.colors.colPrimary
                                font.pixelSize: 14
                                font.bold: true
                                visible: !delegateIcon.visible
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                font.pixelSize: 13
                                font.bold: true
                                color: Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.appId
                                font.pixelSize: 10
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.5
                                elide: Text.ElideRight
                                visible: modelData.appId !== ""
                            }
                        }
                    }
                }
            }
        }

        // Click outside to close
        MouseArea {
            anchors.fill: parent
            z: -1
        }
    }

    // Global click-outside handler
    MouseArea {
        id: closeArea
        parent: root.parent
        anchors.fill: parent
        z: -1
        visible: root.popupOpen
        onPressed: {
            // Check if click is outside the popup and the trigger area
            const pos = mapToItem(root, mouse.x, mouse.y)
            if (pos.x < 0 || pos.x > root.width || pos.y < 0 || pos.y > root.height) {
                const popupPos = mapToItem(popup, mouse.x, mouse.y)
                if (popupPos.x < 0 || popupPos.x > popup.width || popupPos.y < 0 || popupPos.y > popup.height) {
                    root.popupOpen = false
                }
            }
            mouse.accepted = false
        }
    }
}
