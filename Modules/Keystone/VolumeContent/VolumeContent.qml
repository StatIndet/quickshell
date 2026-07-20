import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components

Item {
    id: root

    property string mode: "volume"
    property var audioNode: null
    property real externalValue: 0
    property bool externalMuted: false
    property string iconName: ""
    signal moved(real value)
    signal iconActivated()

    readonly property bool usesAudioNode: audioNode !== null && audioNode !== undefined
    readonly property real controlValue: usesAudioNode ? audioNode.volume : externalValue
    readonly property bool isMuted: usesAudioNode ? audioNode.muted : externalMuted
    readonly property real displayVolume: root.isMuted ? 0.0 : root.controlValue
    readonly property string effectiveIconName: {
        if (root.iconName.length > 0)
            return root.iconName;
        if (root.mode === "brightness")
            return "brightness_medium";
        if (root.mode === "mic")
            return root.isMuted || root.displayVolume <= 0 ? "mic_off" : "mic";
        return root.isMuted || root.displayVolume <= 0 ? "volume_off" : "volume_up";
    }

    readonly property bool isInteractionActive: hoverArea.containsMouse || dragArea.pressed

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton 
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 16

        MaterialSymbol {
            id: sliderIcon

            text: root.effectiveIconName
            iconSize: 24
            fill: root.isMuted ? 1 : 0
            color: Appearance.colors.colOnLayer0
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -10 
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.usesAudioNode)
                        root.audioNode.muted = !root.audioNode.muted;
                    else
                        root.iconActivated();
                }
            }
        }

        Item {
            id: track

            Layout.fillWidth: true
            Layout.preferredHeight: 6 
            Layout.alignment: Qt.AlignVCenter

            readonly property real progress: Math.max(0, Math.min(1, root.displayVolume))
            readonly property real gapWidth: 10
            readonly property real splitX: progress * width
            readonly property real leftWidth: Math.max(0, splitX - gapWidth / 2)
            readonly property real rightX: Math.min(width, splitX + gapWidth / 2)
            readonly property real rightWidth: Math.max(0, width - rightX)

            Rectangle {
                id: fillRect
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: track.leftWidth
                height: parent.height
                radius: 3
                color: Appearance.colors.colOnLayer0
                
                Behavior on width { 
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuint } 
                }
            }

            Rectangle {
                id: restRect
                x: track.rightX
                anchors.verticalCenter: parent.verticalCenter
                width: track.rightWidth
                height: parent.height
                radius: 3
                color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.22)

                Behavior on x {
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuint }
                }

                Behavior on width {
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuint }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.margins: -10 
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function setVol(mouseX) {
                    let p = mouseX / width
                    if (p < 0) p = 0
                    if (p > 1) p = 1

                    if (root.usesAudioNode) {
                        root.audioNode.volume = p
                        if (root.isMuted)
                            root.audioNode.muted = false
                    } else {
                        root.moved(p)
                    }
                }

                onPressed: (mouse) => setVol(mouse.x)
                onPositionChanged: (mouse) => setVol(mouse.x)
            }
        }

        Text {
            text: Math.round(root.displayVolume * 100)
            color: Appearance.colors.colOnLayer0
            font.pixelSize: 15
            font.bold: true
            font.family: "JetBrainsMono Nerd Font" 
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: 32 
            horizontalAlignment: Text.AlignRight
        }
    }
}
