import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    required property bool active
    required property bool recording
    required property bool finalizing
    required property string recordingType
    required property double elapsedMs

    property double heldElapsedMs: 0
    property real entryProgress: active ? 1 : 0

    readonly property color typeColor: recordingType === "gif"
        ? Appearance.colors.colTertiary
        : Appearance.colors.colError

    signal stopRequested()

    opacity: entryProgress
    transform: Translate {
        y: (1 - root.entryProgress) * -6
    }

    function formatElapsed(milliseconds) {
        const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000));
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        const twoDigits = value => String(value).padStart(2, "0");

        return hours > 0
            ? twoDigits(hours) + ":" + twoDigits(minutes) + ":" + twoDigits(seconds)
            : twoDigits(minutes) + ":" + twoDigits(seconds);
    }

    onElapsedMsChanged: {
        if (recording)
            heldElapsedMs = elapsedMs;
    }

    onRecordingChanged: {
        if (recording)
            heldElapsedMs = elapsedMs;
        else if (!finalizing && !active)
            heldElapsedMs = 0;
    }

    Behavior on entryProgress {
        NumberAnimation {
            duration: Appearance.animation.expressiveDefaultSpatial.duration
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }
    }

    ToolButton {
        id: closeButton

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: 48
        enabled: root.recording
        hoverEnabled: true
        scale: down ? 0.9 : (hovered ? 1.04 : 1)

        Accessible.name: "停止录制"
        Accessible.role: Accessible.Button

        onClicked: root.stopRequested()

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        background: Item {
            Rectangle {
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: width / 2
                color: closeButton.down
                    ? Appearance.colors.colErrorContainerActive
                    : (closeButton.hovered
                        ? Appearance.colors.colErrorContainerHover
                        : Appearance.colors.colErrorContainer)
                opacity: closeButton.enabled ? 1 : 0.38

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }
        }

        contentItem: MaterialSymbol {
            text: root.finalizing ? "hourglass_top" : "close"
            iconSize: 20
            fill: 1
            color: Appearance.colors.colOnErrorContainer
            opacity: closeButton.enabled ? 1 : 0.38

            SequentialAnimation on opacity {
                running: root.finalizing
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.25
                    duration: 560
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.6
                    duration: 560
                    easing.type: Easing.InOutSine
                }
            }
        }

        StyledToolTip {
            extraVisibleCondition: closeButton.hovered && closeButton.enabled
            text: "停止录制"
        }
    }

    Row {
        anchors.left: closeButton.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: root.recordingType === "gif" ? "gif_box" : "videocam"
            iconSize: 18
            fill: 1
            color: root.typeColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.recordingType === "gif" ? "GIF" : "REC"
            color: Appearance.colors.colOnSurfaceVariant
            font {
                family: "JetBrainsMono Nerd Font"
                pixelSize: 11
                weight: Font.DemiBold
                letterSpacing: 0.8
            }
            renderType: Text.NativeRendering
        }
    }

    Item {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: root.finalizing ? 68 : 86
        height: 32

        Text {
            anchors.fill: parent
            text: root.finalizing
                ? "正在处理"
                : root.formatElapsed(root.heldElapsedMs)
            color: Appearance.colors.colOnLayer0
            font {
                family: root.finalizing
                    ? "LXGW WenKai GB Screen"
                    : "JetBrainsMono Nerd Font"
                pixelSize: root.finalizing ? 14 : 18
                weight: Font.DemiBold
            }
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 7
            height: 7
            radius: width / 2
            color: Appearance.colors.colError
            visible: root.recording

            SequentialAnimation on opacity {
                running: root.recording
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.35
                    duration: 720
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 720
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
