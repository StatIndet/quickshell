import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
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

    property real mainWidth: 160
    property real mainHeight: 48
    property color surfaceColor: Appearance.colors.colLayer0

    readonly property int effectBleed: 14
    readonly property int satelliteSize: 48
    readonly property int satelliteExtent: 72
    readonly property real mainX: effectBleed + satelliteExtent
    readonly property real mainY: effectBleed
    readonly property real satelliteY: effectBleed + (mainHeight - satelliteSize) / 2
    readonly property real satelliteX: mainX + 6
        + (effectBleed - mainX - 6) * satelliteProgress
    readonly property color typeContainerColor: recordingType === "gif"
        ? Appearance.colors.colTertiaryContainer
        : Appearance.colors.colErrorContainer
    readonly property color typeContentColor: recordingType === "gif"
        ? Appearance.colors.colOnTertiaryContainer
        : Appearance.colors.colOnErrorContainer

    signal stopRequested()

    width: mainWidth + satelliteExtent + effectBleed * 2
    height: Math.max(mainHeight, satelliteSize) + effectBleed * 2
    opacity: active ? 1 : 0

    property real satelliteProgress: recording ? 1 : 0
    property double heldElapsedMs: 0

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

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    Behavior on satelliteProgress {
        NumberAnimation {
            duration: Appearance.animation.expressiveDefaultSpatial.duration
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }
    }

    // CSS-Tricks 的 SVG goo 滤镜在 QML 中的对应实现：
    // 同一容器内的形状 -> GaussianBlur -> alpha threshold -> 叠回清晰形状。
    Item {
        id: rawGooShapes

        anchors.fill: parent
        visible: false

        Rectangle {
            x: root.mainX
            y: root.mainY
            width: root.mainWidth
            height: root.mainHeight
            radius: height / 2
            color: "white"
            antialiasing: true
        }

        Rectangle {
            x: root.satelliteX
            y: root.satelliteY
            width: root.satelliteSize
            height: root.satelliteSize
            radius: width / 2
            color: "white"
            antialiasing: true
        }
    }

    GaussianBlur {
        id: blurredGooShapes

        anchors.fill: parent
        source: rawGooShapes
        radius: 10
        samples: 21
        visible: false
        cached: false
    }

    Rectangle {
        id: gooColorField

        anchors.fill: parent
        color: root.surfaceColor
        visible: false
    }

    ThresholdMask {
        anchors.fill: parent
        source: gooColorField
        maskSource: blurredGooShapes
        threshold: 0.51
        spread: 0.025
        cached: false
    }

    Rectangle {
        x: root.mainX
        y: root.mainY
        width: root.mainWidth
        height: root.mainHeight
        radius: height / 2
        color: root.surfaceColor
        antialiasing: true
    }

    Rectangle {
        id: satelliteShadowSource

        x: root.satelliteX
        y: root.satelliteY
        width: root.satelliteSize
        height: root.satelliteSize
        radius: width / 2
        color: "black"
        opacity: Math.min(1, root.satelliteProgress * 1.7)
        visible: false
    }

    DropShadow {
        anchors.fill: satelliteShadowSource
        source: satelliteShadowSource
        horizontalOffset: 0
        verticalOffset: 4
        radius: 10
        samples: 21
        color: Appearance.colors.colShadow
        opacity: Math.min(1, root.satelliteProgress * 1.7)
        cached: false
    }

    Rectangle {
        id: satelliteSurface

        x: root.satelliteX
        y: root.satelliteY
        width: root.satelliteSize
        height: root.satelliteSize
        radius: width / 2
        color: root.surfaceColor
        opacity: Math.min(1, root.satelliteProgress * 1.7)
        scale: satelliteMouse.pressed ? 0.9 : (satelliteMouse.containsMouse ? 1.04 : 1)
        antialiasing: true

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 36
            height: 36
            radius: width / 2
            color: satelliteMouse.pressed
                ? Appearance.colors.colErrorContainerActive
                : (satelliteMouse.containsMouse
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
            enabled: root.recording && root.satelliteProgress > 0.6
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

    Item {
        x: root.mainX
        y: root.mainY
        width: root.mainWidth
        height: root.mainHeight

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
                    text: root.finalizing
                        ? "hourglass_top"
                        : (root.recordingType === "gif" ? "gif_box" : "videocam")
                    iconSize: 18
                    fill: 1
                    color: root.typeContentColor

                    SequentialAnimation on opacity {
                        running: root.finalizing
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

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 8
                    height: 8
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

            Text {
                width: root.finalizing ? 70 : 86
                anchors.verticalCenter: parent.verticalCenter
                text: root.finalizing
                    ? "正在处理"
                    : root.formatElapsed(root.heldElapsedMs)
                color: Appearance.colors.colOnLayer0
                font {
                    family: root.finalizing
                        ? "LXGW WenKai GB Screen"
                        : "JetBrainsMono Nerd Font"
                    pixelSize: root.finalizing ? 15 : 18
                    weight: Font.DemiBold
                }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }
        }
    }
}
