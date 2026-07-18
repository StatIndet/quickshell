import QtQuick
import QtQuick.Layouts
import QtQuick.Window 
import qs.Common
import qs.Widgets.common

Item {
    id: toolsRoot

    ToolsBackend {
        id: toolsBackend
    }

    // 预留给外部监听的关闭信号
    signal requestHideKeystone()
    signal requestShowAudio(string mode)

    property var toolsModel: [
        { icon: "colorize",         tip: "取色器" },
        { icon: "videocam",         tip: "录屏" },        
        { icon: "gif",              tip: "录制 GIF" },    
        { icon: "crop_free",        tip: "普通截屏" },
        { icon: "height",           tip: "截长屏" },
        { icon: "document_scanner", tip: "OCR 识别" },
        { icon: "mic",              tip: "录麦克风" },       // 索引 6
        { icon: "speaker",          tip: "录电脑声音" }      // 【新增】：索引 7
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

        toolsRoot.requestHideKeystone()
        
        if (selectedIndex === 0) {
            toolsBackend.pickColor()
        } else if (selectedIndex === 1) { // 录屏
            toolsBackend.startRecord("video")
        } else if (selectedIndex === 2) { // 录制 GIF
            toolsBackend.startRecord("gif")
        } else if (selectedIndex === 3) {
            toolsBackend.takeScreenshot()
        } else if (selectedIndex === 6) { // 录音 - 麦克风
            toolsRoot.requestShowAudio("mic")
            toolsBackend.startAudio("audio_mic")
        } else if (selectedIndex === 7) { // 录音 - 系统声音
            toolsRoot.requestShowAudio("sys")
            toolsBackend.startAudio("audio_sys")
        } else {
            console.log("该工具的后端尚未实现！")
        }
    }

    // 【核心修复】：保留唯一的一个停止录制接口
    function stopRecording() {
        toolsBackend.stopRecord()
    }
    function stopAudio() {
        toolsBackend.stopAudio()
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: toolsRoot.toolsModel

            Rectangle {
                width: 48
                height: 48
                radius: 12
                
                color: (toolsMouse.containsMouse || index === toolsRoot.selectedIndex) 
                    ? Appearance.colors.colLayer2Hover : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: "Material Symbols Rounded" 
                    font.pixelSize: 22
                    color: Appearance.colors.colOnSurface
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

                StyledToolTip {
                    extraVisibleCondition: toolsMouse.containsMouse
                    text: modelData.tip
                }
            }
        }
    }
}
