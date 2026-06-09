import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property string currentDesktopId: ""
    property var desktops: []
    property string desktopsRaw: ""
    property string currentRaw: ""

    implicitHeight: 36
    implicitWidth: layout.width + 24

    Component.onCompleted: refreshDesktops()

    function refreshDesktops() {
        desktopListProcess.running = true
        currentDesktopProcess.running = true
    }

    function switchDesktopById(desktopId) {
        switchDesktopProcess.command = ["gdbus", "call", "--session", "--dest", "org.kde.KWin", "--object-path", "/VirtualDesktopManager", "--method", "org.freedesktop.DBus.Properties.Set", "org.kde.KWin.VirtualDesktopManager", "current", "<" + desktopId + ">"]
        switchDesktopProcess.running = true
    }

    function parseDesktopsOutput(text) {
        desktopsRaw = text
        tryParseDesktops()
    }

    function parseCurrentOutput(text) {
        currentRaw = text
        tryParseCurrent()
    }

    function tryParseDesktops() {
        const text = desktopsRaw
        if (!text || text.length === 0) return

        const result = []
        // 匹配 (uint32 N, 'id', 'name') 或 (N, 'id', 'name')
        const structRegex = /\(?(?:uint32\s+)?(\d+),\s*'([^']+)',\s*'([^']+)'\)?/g
        let match
        while ((match = structRegex.exec(text)) !== null) {
            result.push({
                index: parseInt(match[1]),
                id: match[2],
                name: match[3]
            })
        }

        if (result.length > 0) {
            root.desktops = result
        }
    }

    function tryParseCurrent() {
        const text = currentRaw
        if (!text || text.length === 0) return

        // 匹配 ('id',) 或直接的 UUID
        const match = text.match(/'([0-9a-f-]+)'/)
        if (match) {
            root.currentDesktopId = match[1]
        }
    }

    // 获取桌面列表
    Process {
        id: desktopListProcess
        command: ["gdbus", "call", "--session", "--dest", "org.kde.KWin", "--object-path", "/VirtualDesktopManager", "--method", "org.freedesktop.DBus.Properties.Get", "org.kde.KWin.VirtualDesktopManager", "desktops"]

        stdout: StdioCollector {
            onStreamFinished: root.parseDesktopsOutput(this.text)
        }
    }

    // 获取当前桌面
    Process {
        id: currentDesktopProcess
        command: ["gdbus", "call", "--session", "--dest", "org.kde.KWin", "--object-path", "/VirtualDesktopManager", "--method", "org.freedesktop.DBus.Properties.Get", "org.kde.KWin.VirtualDesktopManager", "current"]

        stdout: StdioCollector {
            onStreamFinished: root.parseCurrentOutput(this.text)
        }
    }

    // 切换桌面
    Process {
        id: switchDesktopProcess
    }

    // 定时刷新
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refreshDesktops()
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
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: root.desktops

            delegate: Item {
                id: delegateRoot

                required property var modelData
                readonly property bool active: modelData.id === root.currentDesktopId
                readonly property bool isHovered: mouseArea.containsMouse

                implicitWidth: (active || isHovered) ? 32 : 12
                implicitHeight: 12

                Behavior on implicitWidth {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.implicitWidth
                    height: parent.implicitHeight
                    radius: height / 2

                    color: delegateRoot.active ? Appearance.colors.colPrimary
                         : delegateRoot.isHovered ? Appearance.colors.colLayer2Hover
                         : Appearance.colors.colLayer4

                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchDesktopById(modelData.id)
                }

                PopupToolTip {
                    extraVisibleCondition: mouseArea.containsMouse
                    text: "工作区 " + (modelData.name || (modelData.index + 1).toString())
                }

                PopupToolTip {
                    extraVisibleCondition: mouseArea.containsMouse
                    text: "工作区 " + model.id + (delegateRoot.hasWindows ? "\n窗口: " + model.windowCount : "")
                }
            }
        }
    }
}
