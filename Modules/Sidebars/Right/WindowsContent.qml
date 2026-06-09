import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets.common

WidgetPanel {
    id: root
    title: "窗口"
    icon: "widgets"
    closeAction: () => WidgetState.qsOpen = false

    property var windowList: []

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

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "windows"
    onIsActiveChanged: {
        if (isActive)
            root.refreshWindowList()
    }

    Connections {
        target: ToplevelManager
        function onToplevelsChanged() {
            if (root.isActive)
                root.refreshWindowList()
        }
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
                    if (modelData.toplevel)
                        modelData.toplevel.activate()
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
                        source: modelData.appId ? "image://icon/" + modelData.appId : ""
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
