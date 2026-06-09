import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common

Item {
    id: root

    property string windowTitle: "Desktop"
    property string windowAppId: ""

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
        color: Appearance.colors.colLayer0
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
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (WidgetState.windowMenuOpen) {
                WidgetState.windowMenuOpen = false
            } else {
                // 计算菜单位置：指示器下方
                const pos = mapToGlobal(0, height)
                WidgetState.windowMenuX = pos.x
                WidgetState.windowMenuY = pos.y
                WidgetState.windowMenuOpen = true
            }
        }
    }
}
