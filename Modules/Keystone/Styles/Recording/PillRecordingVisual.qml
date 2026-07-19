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
    required property real morphProgress
    required property real recordingInfoProgress
    required property real recordingActionProgress
    required property real processingContentProgress

    property real baseMainWidth: 220
    property real layoutHeight: 42
    property color surfaceColor: Appearance.colors.colLayer0

    readonly property int effectBleed: 18
    readonly property real maxMainWidth: 280
    readonly property real maxRightExtent: 70
    readonly property real maxVisualHeight: 52
    readonly property real mainRightX: effectBleed + maxMainWidth
    readonly property real shapeCenterY: height / 2
    readonly property real normalizedMorphProgress: Math.max(0, Math.min(1, morphProgress))
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
    readonly property real settledMainWidth: baseMainWidth + 12

    // Reference-video keyframes:
    // idle -> maximum connected hull -> narrow neck -> detached -> settled.
    readonly property real mainLayoutWidth: morphValue(
        baseMainWidth, 280, 250, 246, settledMainWidth)
    readonly property real mainVisualHeight: morphValue(layoutHeight, 52, 46, 44, 42)
    readonly property real satelliteWidth: satelliteMorphValue(layoutHeight, 60, 56, 54, 52)
    readonly property real satelliteHeight: satelliteMorphValue(layoutHeight, 50, 46, 44, 42)
    readonly property real satelliteCenterOffset: satelliteMorphValue(
        -layoutHeight / 2,
        40,
        38,
        38,
        38
    )
    readonly property real blendRadius: satelliteMorphValue(0, 50, 28, 18, 0)
    readonly property real mainCenterX: mainRightX - mainLayoutWidth / 2
    readonly property real satelliteCenterX: mainRightX + satelliteCenterOffset
    readonly property real satelliteRightExtent: Math.max(
        0,
        satelliteCenterOffset + satelliteWidth / 2
    )
    readonly property real interactiveRightExtent: normalizedRecordingActionProgress > 0.01
        ? satelliteRightExtent
        : 0
    readonly property real rightOverflow: maxRightExtent + effectBleed
    readonly property color typeContainerColor: recordingType === "gif"
        ? Appearance.colors.colTertiaryContainer
        : Appearance.colors.colErrorContainer
    readonly property color typeContentColor: recordingType === "gif"
        ? Appearance.colors.colOnTertiaryContainer
        : Appearance.colors.colOnErrorContainer

    signal stopRequested()

    width: maxMainWidth + maxRightExtent + effectBleed * 2
    height: maxVisualHeight + effectBleed * 2
    opacity: active ? 1 : 0

    property double heldElapsedMs: 0

    function smoothStep(value) {
        const clamped = Math.max(0, Math.min(1, value));
        return clamped * clamped * (3 - 2 * clamped);
    }

    function interpolate(from, to, progress) {
        return from + (to - from) * smoothStep(progress);
    }

    function morphValue(idle, peak, neck, split, settled) {
        const progress = normalizedMorphProgress;
        if (progress <= 0.58)
            return interpolate(idle, peak, progress / 0.58);
        if (progress <= 0.76)
            return interpolate(peak, neck, (progress - 0.58) / 0.18);
        if (progress <= 0.8)
            return interpolate(neck, split, (progress - 0.76) / 0.04);
        return interpolate(split, settled, (progress - 0.8) / 0.2);
    }

    function satelliteMorphValue(idle, peak, neck, split, settled) {
        const progress = normalizedMorphProgress;
        if (progress <= 0.32)
            return idle;
        if (progress <= 0.58)
            return interpolate(idle, peak, (progress - 0.32) / 0.26);
        if (progress <= 0.76)
            return interpolate(peak, neck, (progress - 0.58) / 0.18);
        if (progress <= 0.8)
            return interpolate(neck, split, (progress - 0.76) / 0.04);
        return interpolate(split, settled, (progress - 0.8) / 0.2);
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

    PillMorphSurface {
        anchors.fill: parent
        mainCenter: Qt.vector2d(root.mainCenterX, root.shapeCenterY)
        mainSize: Qt.vector2d(root.mainLayoutWidth, root.mainVisualHeight)
        mainRadius: root.mainVisualHeight / 2
        satelliteCenter: Qt.vector2d(root.satelliteCenterX, root.shapeCenterY)
        satelliteSize: Qt.vector2d(root.satelliteWidth, root.satelliteHeight)
        satelliteRadius: root.satelliteHeight / 2
        blendRadius: root.blendRadius
        surfaceColor: root.surfaceColor
    }

    Item {
        id: recordingContent

        x: root.mainRightX - root.mainLayoutWidth
        y: root.shapeCenterY - root.layoutHeight / 2
        width: root.mainLayoutWidth
        height: root.layoutHeight
        opacity: root.normalizedRecordingInfoProgress
        scale: 0.94 + 0.06 * root.normalizedRecordingInfoProgress
        transform: Translate {
            y: (1 - root.normalizedRecordingInfoProgress) * -4
        }

        Row {
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 30
                height: 30
                radius: width / 2
                color: root.typeContainerColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.recordingType === "gif" ? "gif_box" : "videocam"
                    iconSize: 18
                    fill: 1
                    color: root.typeContentColor
                }

                Item {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 8
                    height: 8
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

            Text {
                width: 86
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatElapsed(root.heldElapsedMs)
                color: Appearance.colors.colOnLayer0
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 18
                    weight: Font.DemiBold
                }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }
        }
    }

    Item {
        id: processingContent

        x: root.mainRightX - root.mainLayoutWidth
        y: root.shapeCenterY - root.layoutHeight / 2
        width: root.mainLayoutWidth
        height: root.layoutHeight
        opacity: root.normalizedProcessingContentProgress
        scale: 0.94 + 0.06 * root.normalizedProcessingContentProgress
        transform: Translate {
            y: (1 - root.normalizedProcessingContentProgress) * 4
        }

        Row {
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 30
                height: 30
                radius: width / 2
                color: root.typeContainerColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "hourglass_top"
                    iconSize: 18
                    fill: 1
                    color: root.typeContentColor

                    SequentialAnimation on opacity {
                        running: root.finalizing
                            && root.normalizedProcessingContentProgress > 0.01
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 0.45
                            duration: 560
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: 560
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            Text {
                width: 70
                anchors.verticalCenter: parent.verticalCenter
                text: "正在处理"
                color: Appearance.colors.colOnLayer0
                font {
                    family: "LXGW WenKai GB Screen"
                    pixelSize: 15
                    weight: Font.DemiBold
                }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }
        }
    }

    Item {
        id: satelliteButton

        x: root.satelliteCenterX - root.satelliteWidth / 2
        y: root.shapeCenterY - root.satelliteHeight / 2
        width: root.satelliteWidth
        height: root.satelliteHeight
        opacity: root.normalizedRecordingActionProgress
        scale: 0.86 + 0.14 * root.normalizedRecordingActionProgress

        Rectangle {
            anchors.centerIn: parent
            width: 36
            height: 36
            radius: width / 2
            scale: satelliteMouse.pressed ? 0.9 : (satelliteMouse.containsMouse ? 1.04 : 1)
            color: satelliteMouse.pressed
                ? Appearance.colors.colErrorContainerActive
                : (satelliteMouse.containsMouse
                    ? Appearance.colors.colErrorContainerHover
                    : Appearance.colors.colErrorContainer)

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastSpatial.duration
                    easing.type: Appearance.animation.expressiveFastSpatial.type
                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "stop"
            iconSize: 20
            fill: 1
            color: Appearance.colors.colOnErrorContainer
        }

        MouseArea {
            id: satelliteMouse

            anchors.fill: parent
            enabled: root.recording
                && root.normalizedRecordingActionProgress > 0.55
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            Accessible.name: "停止录制"
            Accessible.role: Accessible.Button

            onClicked: root.stopRequested()
        }

        StyledToolTip {
            extraVisibleCondition: satelliteMouse.containsMouse && satelliteMouse.enabled
            text: "停止录制"
        }
    }
}
