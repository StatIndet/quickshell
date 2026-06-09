import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets.common

import "../../../Common/functions/IconResolver.js" as IconResolver

WidgetPanel {
    id: root
    title: "窗口"
    icon: "widgets"
    closeAction: () => WidgetState.qsOpen = false

    property var windowList: []
    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "windows"

    onIsActiveChanged: {
        if (isActive)
            root.refreshWindowList()
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

    // Also refresh when window list might have changed (poll every 3s when open)
    Timer {
        interval: 3000
        running: root.isActive
        repeat: true
        onTriggered: root.refreshWindowList()
    }

    Text {
        text: root.windowList.length + " 个窗口"
        font.pixelSize: 12
        color: Appearance.colors.colOnLayer1
        opacity: 0.6
        visible: root.windowList.length > 0
    }

    StyledListView {
        id: windowListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 4
        model: root.windowList
        visible: root.windowList.length > 0

        delegate: Rectangle {
            width: windowListView.width
            height: 52
            radius: 12
            color: delegateMouseArea.pressed ? Appearance.colors.colLayer2Active : delegateMouseArea.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"

            Behavior on color { ColorAnimation { duration: 140 } }

            MouseArea {
                id: delegateMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.wid) {
                        Quickshell.execDetached(["kdotool", "windowactivate", modelData.wid])
                    }
                    WidgetState.qsOpen = false
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        id: delegateIcon
                        anchors.fill: parent
                        source: modelData.appId ? IconResolver.resolveIcon(modelData.appId) : ""
                        sourceSize.width: 56
                        sourceSize.height: 56
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: modelData.appId !== "" && status !== Image.Error
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (modelData.appId || "?").charAt(0).toUpperCase()
                        color: Appearance.colors.colPrimary
                        font.pixelSize: 16
                        font.bold: true
                        visible: !delegateIcon.visible
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        font.pixelSize: 14
                        font.bold: true
                        color: Appearance.colors.colOnLayer2
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.appId
                        font.pixelSize: 11
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
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.windowList.length === 0
        spacing: 12

        Item { Layout.fillHeight: true }

        Text {
            text: "window"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 48
            color: Appearance.colors.colOnLayer1
            opacity: 0.3
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: "没有打开的窗口"
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer1
            opacity: 0.5
            Layout.alignment: Qt.AlignHCenter
        }

        Item { Layout.fillHeight: true }
    }
}
