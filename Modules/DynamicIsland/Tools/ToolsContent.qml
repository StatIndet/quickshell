import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Common
import qs.Components

Item {
    id: toolsRoot

    ToolsBackend {
        id: toolsBackend

        onRecordCancelled: {
            console.log("用户按下了 ESC，取消了录制选区。")
            toolsRoot.requestSetRecording(false)
        }
    }

    signal requestHideIsland()
    signal requestSetRecording(bool state)
    signal requestShowAudio(string mode)

    property var toolsModel: [
        { icon: "colorize",         tip: "取色器" },
        { icon: "videocam",         tip: "录屏" },
        { icon: "gif",              tip: "录制 GIF" },
        { icon: "crop_free",        tip: "截屏" },
        { icon: "height",           tip: "截长屏" },
        { icon: "document_scanner", tip: "OCR" },
        { icon: "mic",              tip: "录麦克风" },
        { icon: "speaker",          tip: "录系统音" }
    ]

    property int selectedIndex: 0

    focus: visible
    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            forceActiveFocus();
        }
    }

    Keys.onLeftPressed: {
        selectedIndex = (selectedIndex - 1 + toolsModel.length) % toolsModel.length
    }

    Keys.onRightPressed: {
        selectedIndex = (selectedIndex + 1) % toolsModel.length
    }

    Keys.onReturnPressed: triggerSelected()
    Keys.onEnterPressed: triggerSelected()

    function triggerSelected() {
        console.log("触发工具: " + toolsModel[selectedIndex].tip)

        if (selectedIndex === 0) {
            toolsBackend.pickColor()
        } else if (selectedIndex === 1) {
            toolsRoot.requestSetRecording(true)
            toolsBackend.startRecord("video")
        } else if (selectedIndex === 2) {
            toolsRoot.requestSetRecording(true)
            toolsBackend.startRecord("gif")
        } else if (selectedIndex === 3) {
            toolsBackend.takeScreenshot()
        } else if (selectedIndex === 6) {
            toolsRoot.requestShowAudio("mic")
            toolsBackend.startAudio("audio_mic")
        } else if (selectedIndex === 7) {
            toolsRoot.requestShowAudio("sys")
            toolsBackend.startAudio("audio_sys")
        } else {
            console.log("该工具的后端尚未实现！")
        }
    }

    function stopRecording() {
        toolsBackend.stopRecord()
    }
    function stopAudio() {
        toolsBackend.stopAudio()
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: toolsRoot.toolsModel

            Item {
                width: 52
                height: 52

                property bool isSelected: index === toolsRoot.selectedIndex

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: toolsMouse.containsMouse || parent.isSelected
                        ? Appearance.colors.colLayer2Hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MaterialSymbol {
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.icon
                    iconSize: 20
                    color: Appearance.colors.colOnSurface
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.tip
                    font.pixelSize: 9
                    font.family: Sizes.fontFamily
                    color: Appearance.colors.colOnSurfaceVariant
                }

                MouseArea {
                    id: toolsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: toolsRoot.selectedIndex = index

                    onClicked: {
                        toolsRoot.selectedIndex = index
                        toolsRoot.triggerSelected()
                    }
                }
            }
        }
    }
}
