import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Components

import "../../Common/functions/IconResolver.js" as IconResolver

PanelWindow {
    id: root

    visible: WidgetState.windowMenuOpen
    color: "transparent"
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-window-menu"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property var windowList: []

    onVisibleChanged: {
        if (visible) {
            refreshWindowList()
            pollTimer.start()
        } else {
            pollTimer.stop()
        }
    }

    function refreshWindowList() {
        windowListProcess.running = true
    }

    Process {
        id: windowListProcess
        command: ["bash", "-c", `
kdotool search "." 2>/dev/null | while read wid; do
  name=$(kdotool getwindowname "$wid" 2>/dev/null)
  cls=$(kdotool getwindowclassname "$wid" 2>/dev/null)
  [ -n "$name" ] && echo "$wid|$name|$cls"
done
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const rawText = text.trim()
                if (rawText.length === 0) {
                    root.windowList = []
                    return
                }
                const newList = []
                const lines = rawText.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("|")
                    if (parts.length >= 2 && parts[1].trim().length > 0) {
                        newList.push({
                            wid: parts[0] || "",
                            title: parts[1] || "未知窗口",
                            appId: parts[2] || ""
                        })
                    }
                }
                root.windowList = newList
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 3000
        running: false
        repeat: true
        onTriggered: root.refreshWindowList()
    }

    mask: Region { item: menuSurface }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        z: -1
        onClicked: WidgetState.windowMenuOpen = false
    }

    Item {
        id: menuSurface
        x: Math.max(10, WidgetState.windowMenuX)
        y: Math.max(10, WidgetState.windowMenuY)
        width: 320
        height: menuBg.height + 20

        Rectangle {
            id: menuBg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            radius: 18
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            implicitHeight: contentCol.implicitHeight + 16

            // Click inside doesn't close
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: contentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 4

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "widgets"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: Appearance.colors.colOnLayer0
                    }

                    Text {
                        text: "窗口列表"
                        font.family: "LXGW WenKai GB Screen"
                        font.pixelSize: 14
                        font.bold: true
                        color: Appearance.colors.colOnLayer0
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.windowList.length + " 个"
                        font.pixelSize: 11
                        color: Appearance.colors.colSubtext
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
                }

                // Window list
                Repeater {
                    model: root.windowList

                    Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        height: 48
                        radius: 12
                        color: itemMouse.pressed
                            ? Appearance.colors.colLayer2Active
                            : itemMouse.containsMouse
                                ? Appearance.colors.colLayer2Hover
                                : "transparent"

                        Behavior on color { ColorAnimation { duration: 140 } }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.wid)
                                    Quickshell.execDetached(["kdotool", "windowactivate", modelData.wid])
                                WidgetState.windowMenuOpen = false
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    id: delegateIcon
                                    anchors.fill: parent
                                    source: modelData.appId ? IconResolver.resolveIcon(modelData.appId) : ""
                                    sourceSize.width: 48
                                    sourceSize.height: 48
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
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.family: "LXGW WenKai GB Screen"
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

                // Empty state
                Text {
                    visible: root.windowList.length === 0
                    text: "没有打开的窗口"
                    font.pixelSize: 13
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                    Layout.bottomMargin: 16
                }
            }
        }
    }
}
