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
    required property real recordingInfoProgress
    required property real recordingActionProgress
    required property real processingContentProgress

    property double heldElapsedMs: 0
    property real entryProgress: active ? 1 : 0
    readonly property real normalizedRecordingInfoProgress: Math.max(
        0,
        Math.min(1, recordingInfoProgress)
    )
    readonly property real normalizedRecordingActionProgress: Math.max(
        0,
        Math.min(1, recordingActionProgress)
    )
    readonly property real normalizedProcessingContentProgress: Math.max(
        0,
        Math.min(1, processingContentProgress)
    )
    readonly property real sessionContentProgress: Math.min(
        1,
        normalizedRecordingInfoProgress + normalizedProcessingContentProgress
    )

    readonly property color typeColor: recordingType === "gif"
        ? Appearance.colors.colTertiary
        : Appearance.colors.colError

    component SessionTypeIndicator: Row {
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

    SessionTypeIndicator {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.sessionContentProgress
        scale: 0.96 + 0.04 * root.sessionContentProgress
    }

    Item {
        id: recordingContent

        anchors.fill: parent
        opacity: root.normalizedRecordingInfoProgress
        scale: 0.96 + 0.04 * root.normalizedRecordingInfoProgress
        transform: Translate {
            y: (1 - root.normalizedRecordingInfoProgress) * -4
        }

        ToolButton {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            opacity: root.normalizedRecordingActionProgress
            enabled: root.recording
                && root.normalizedRecordingActionProgress > 0.55
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
                text: "close"
                iconSize: 20
                fill: 1
                color: Appearance.colors.colOnErrorContainer
            }

            StyledToolTip {
                extraVisibleCondition: closeButton.hovered && closeButton.enabled
                text: "停止录制"
            }
        }

        Item {
            anchors.left: parent.left
            anchors.leftMargin: 78
            anchors.right: closeButton.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            height: 32

            Text {
                anchors.fill: parent
                text: root.formatElapsed(root.heldElapsedMs)
                color: Appearance.colors.colOnLayer0
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 18
                    weight: Font.DemiBold
                }
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }

            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 7
                height: 7
                opacity: root.recording ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Appearance.colors.colError

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
    }

    Item {
        id: processingContent

        anchors.fill: parent
        opacity: root.normalizedProcessingContentProgress
        scale: 0.96 + 0.04 * root.normalizedProcessingContentProgress
        transform: Translate {
            y: (1 - root.normalizedProcessingContentProgress) * 4
        }

        Item {
            id: processingIndicator

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48

            Rectangle {
                anchors.centerIn: parent
                width: 36
                height: 36
                radius: width / 2
                color: Appearance.colors.colErrorContainer
                opacity: 0.38
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "hourglass_top"
                iconSize: 20
                fill: 1
                color: Appearance.colors.colOnErrorContainer

                SequentialAnimation on opacity {
                    running: root.finalizing
                        && root.normalizedProcessingContentProgress > 0.01
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
        }

        Item {
            anchors.left: parent.left
            anchors.leftMargin: 78
            anchors.right: processingIndicator.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            height: 32

            Text {
                anchors.fill: parent
                text: "正在处理"
                color: Appearance.colors.colOnLayer0
                font {
                    family: "LXGW WenKai GB Screen"
                    pixelSize: 14
                    weight: Font.DemiBold
                }
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }
        }
    }
}
