import QtQuick
import qs.Common
import qs.Components
import qs.Widgets.common
import "RecordingFormat.js" as RecordingFormat

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
    required property string edge
    property real baseMainWidth: 220
    property real layoutHeight: 42
    property color surfaceColor: Appearance.colors.colLayer0
    property double heldElapsedMs: 0
    readonly property real progress: Math.max(0, Math.min(1, morphProgress))
    readonly property real infoProgress: Math.max(0, Math.min(1, recordingInfoProgress))
    readonly property real actionProgress: Math.max(0, Math.min(1, recordingActionProgress))
    readonly property real processingProgress: Math.max(0, Math.min(1, processingContentProgress))
    readonly property real mainWidth: morphValue(baseMainWidth, 250, 220, 210, 200)
    readonly property real mainHeight: morphValue(layoutHeight, 52, 46, 44, 42)
    readonly property real satelliteDiameter: mainHeight
    readonly property real satelliteWidth: satelliteDiameter
    readonly property real satelliteHeight: satelliteDiameter
    readonly property real satelliteOffset: satelliteMorphValue(-layoutHeight / 2, 40, 38, 38, 38)
    readonly property real satelliteCenterX: mainWidth + satelliteOffset
    readonly property real visualWidth: Math.max(mainWidth, satelliteCenterX + satelliteWidth / 2)
    readonly property real visualHeight: 52
    readonly property real mainY: edge === "top" ? 0 : visualHeight - mainHeight
    readonly property real satelliteY: edge === "top" ? 0 : visualHeight - satelliteHeight
    readonly property color typeContainerColor: Appearance.colors.colTertiaryContainer
    readonly property color typeContentColor: Appearance.colors.colOnTertiaryContainer
    readonly property var blurBackgroundItems: [mainBlurRegion, satelliteBlurRegion]

    signal stopRequested()

    function smoothStep(value) {
        const clamped = Math.max(0, Math.min(1, value));
        return clamped * clamped * (3 - 2 * clamped);
    }

    function interpolate(from, to, value) {
        return from + (to - from) * smoothStep(value);
    }

    function morphValue(idle, peak, neck, split, settled) {
        if (progress <= 0.58)
            return interpolate(idle, peak, progress / 0.58);

        if (progress <= 0.76)
            return interpolate(peak, neck, (progress - 0.58) / 0.18);

        if (progress <= 0.8)
            return interpolate(neck, split, (progress - 0.76) / 0.04);

        return interpolate(split, settled, (progress - 0.8) / 0.2);
    }

    function satelliteMorphValue(idle, peak, neck, split, settled) {
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

    implicitWidth: visualWidth
    implicitHeight: visualHeight
    opacity: active ? 1 : 0
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

    Rectangle {
        id: mainBlurRegion

        x: 0
        y: root.mainY
        width: root.mainWidth
        height: root.mainHeight
        radius: height / 2
        color: "transparent"
        visible: root.active && root.opacity > 0.01
    }

    Rectangle {
        id: satelliteBlurRegion

        x: root.satelliteCenterX - root.satelliteWidth / 2
        y: root.satelliteY
        width: root.satelliteWidth
        height: root.satelliteHeight
        radius: height / 2
        color: "transparent"
        visible: root.active && root.opacity > 0.01
    }

    PillMorphSurface {
        anchors.fill: parent
        mainCenter: Qt.vector2d(root.mainWidth / 2, root.mainY + root.mainHeight / 2)
        mainSize: Qt.vector2d(root.mainWidth, root.mainHeight)
        mainRadius: root.mainHeight / 2
        satelliteCenter: Qt.vector2d(root.satelliteCenterX, root.satelliteY + root.satelliteHeight / 2)
        satelliteSize: Qt.vector2d(root.satelliteWidth, root.satelliteHeight)
        satelliteRadius: root.satelliteHeight / 2
        blendRadius: root.satelliteMorphValue(0, 50, 28, 18, 0)
        surfaceColor: root.surfaceColor
    }

    Row {
        x: (root.mainWidth - width) / 2
        y: root.mainY + (root.mainHeight - height) / 2
        spacing: 10
        opacity: root.infoProgress

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

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 86
            text: RecordingFormat.elapsed(root.heldElapsedMs)
            color: Appearance.colors.colOnLayer0
            font.family: Fonts.numeric
            font.pixelSize: 18
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }

    }

    Row {
        x: (root.mainWidth - width) / 2
        y: root.mainY + (root.mainHeight - height) / 2
        spacing: 10
        opacity: root.processingProgress

        Rectangle {
            width: 30
            height: 30
            radius: width / 2
            color: root.typeContainerColor

            ProcessingSpiralIndicator {
                anchors.centerIn: parent
                running: root.finalizing && root.processingProgress > 0.01
                dotColor: root.typeContentColor
            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("正在处理")
            color: Appearance.colors.colOnLayer0
            font.family: Fonts.ui
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

    }

    Item {
        x: root.satelliteCenterX - root.satelliteWidth / 2
        y: root.satelliteY
        width: root.satelliteWidth
        height: root.satelliteHeight
        opacity: root.actionProgress

        Rectangle {
            anchors.centerIn: parent
            width: 16
            height: 16
            radius: width / 2
            color: Appearance.colors.colError
            opacity: 1

            SequentialAnimation on opacity {
                running: root.recording && root.actionProgress > 0.01
                loops: Animation.Infinite

                NumberAnimation {
                    from: 0.35
                    to: 1
                    duration: 800
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    from: 1
                    to: 0.35
                    duration: 800
                    easing.type: Easing.InOutSine
                }

            }

        }

        MouseArea {
            id: satelliteMouse

            anchors.fill: parent
            enabled: root.recording && root.actionProgress > 0.55
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stopRequested()
        }

        StyledToolTip {
            extraVisibleCondition: satelliteMouse.containsMouse && satelliteMouse.enabled
            text: qsTr("停止录制")
        }

    }

}
