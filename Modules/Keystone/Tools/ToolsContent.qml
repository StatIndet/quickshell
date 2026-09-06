import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Common
import qs.Widgets.common

Item {
    id: toolsRoot

    property bool vertical: false
    property string edge: "top"
    property string popupEdge: edge
    readonly property int buttonSize: 48
    readonly property int buttonSpacing: 40
    readonly property int buttonsExtent: 480
    readonly property int crossExtent: 72
    property var toolsModel: [
        {
            "action": "color-picker",
            "icon": "colorize",
            "tip": qsTr("取色器")
        },
        {
            "action": "record-video",
            "icon": "videocam",
            "tip": qsTr("录屏")
        },
        {
            "action": "record-gif",
            "icon": "gif",
            "tip": qsTr("录制 GIF")
        },
        {
            "action": "audio-mic",
            "icon": "mic",
            "tip": qsTr("录麦克风")
        },
        {
            "action": "audio-system",
            "icon": "speaker",
            "tip": qsTr("录电脑声音")
        }
    ]
    property int selectedIndex: 0

    signal requestHideKeystone

    function triggerSelected() {
        const tool = toolsModel[selectedIndex];
        if (!tool)
            return;

        toolsRoot.requestHideKeystone();
        switch (tool.action) {
        case "color-picker":
            toolsBackend.pickColor();
            break;
        case "record-video":
            toolsBackend.startRecord("video");
            break;
        case "record-gif":
            toolsBackend.startRecord("gif");
            break;
        case "audio-mic":
            toolsBackend.startAudio("mic");
            break;
        case "audio-system":
            toolsBackend.startAudio("system");
            break;
        default:
            console.warn("[Tools] backend unavailable", tool.action);
        }
    }

    function stopRecording() {
        toolsBackend.stopRecord();
    }

    function stopAudio() {
        toolsBackend.stopAudio();
    }

    implicitWidth: vertical ? crossExtent : buttonsExtent
    implicitHeight: vertical ? buttonsExtent : crossExtent
    property bool keyboardActive: visible
    enabled: keyboardActive
    focus: keyboardActive
    onKeyboardActiveChanged: {
        if (keyboardActive) {
            selectedIndex = 0;
            forceActiveFocus();
        }
    }
    Keys.onLeftPressed: {
        selectedIndex = (selectedIndex - 1 + toolsModel.length) % toolsModel.length;
    }
    Keys.onRightPressed: {
        selectedIndex = (selectedIndex + 1) % toolsModel.length;
    }
    Keys.onUpPressed: {
        if (toolsRoot.vertical)
            selectedIndex = (selectedIndex - 1 + toolsModel.length) % toolsModel.length;
    }
    Keys.onDownPressed: {
        if (toolsRoot.vertical)
            selectedIndex = (selectedIndex + 1) % toolsModel.length;
    }
    Keys.onReturnPressed: triggerSelected()
    Keys.onEnterPressed: triggerSelected()

    ToolsBackend {
        id: toolsBackend
    }

    Grid {
        anchors.centerIn: parent
        spacing: toolsRoot.buttonSpacing
        columns: toolsRoot.vertical ? 1 : toolsRoot.toolsModel.length

        Repeater {
            model: toolsRoot.toolsModel

            IconButton {
                controlSize: toolsRoot.buttonSize
                iconName: modelData.icon
                iconSize: 22
                iconColor: Appearance.colors.colOnSurface
                selectedIconColor: Appearance.colors.colOnSurface
                accessibleName: modelData.tip
                selected: index === toolsRoot.selectedIndex
                selectedContainerColor: Appearance.colors.colLayer2Hover
                selectedHoverStateLayerColor: Appearance.colors.colLayer2Hover
                selectedPressedStateLayerColor: Appearance.colors.colLayer2Active
                hoverStateLayerColor: Appearance.colors.colLayer2Hover
                pressedStateLayerColor: Appearance.colors.colLayer2Active
                onPointerHoveredChanged: {
                    if (pointerHovered)
                        toolsRoot.selectedIndex = index;
                }
                onClicked: {
                    toolsRoot.selectedIndex = index;
                    toolsRoot.triggerSelected();
                }
            }
        }
    }
}
