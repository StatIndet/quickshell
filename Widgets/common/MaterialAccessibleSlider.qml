import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common

Slider {
    id: root

    property color activeTrackColor: Appearance.colors.colPrimary || "#6750a4"
    property color inactiveTrackColor: Appearance.colors.colSecondaryContainer || "#e8def8"
    property color thumbColor: Appearance.colors.colPrimary || "#6750a4"
    property color valueIndicatorColor: Appearance.m3colors.m3scrim || "#000000"
    property color valueIndicatorTextColor: "#ffffff"
    property real trackHeight: 16
    property real pressedTrackHeight: trackHeight
    property real thumbWidth: 8
    property real pressedThumbWidth: 3
    property real thumbHeight: 56
    property real pressedThumbHeight: thumbHeight
    property real trackGap: 48
    property real pressedTrackGap: 30
    property real trackEdgeShrink: 0
    property real pressedTrackEdgeShrink: trackEdgeShrink
    property real stopIndicatorSize: 8
    property real valueIndicatorDiameter: 48
    property real valueIndicatorGap: 8
    property bool showValueIndicator: true
    property var valueFormatter: function(sliderValue) {
        return Math.round(sliderValue).toString();
    }
    property string accessibleName: "Slider"
    property real pressProgress: pressed ? 1 : 0
    property bool keyboardIndicatorActive: false

    readonly property real stateLayerSize: Math.max(40, thumbHeight + 8)
    readonly property real currentTrackHeight: lerp(trackHeight, pressedTrackHeight, pressProgress)
    readonly property real currentThumbWidth: lerp(thumbWidth, pressedThumbWidth, pressProgress)
    readonly property real currentThumbHeight: lerp(thumbHeight, pressedThumbHeight, pressProgress)
    readonly property real currentTrackGap: lerp(trackGap, pressedTrackGap, pressProgress)
    readonly property real currentTrackEdgeShrink: lerp(trackEdgeShrink, pressedTrackEdgeShrink, pressProgress)
    readonly property real valueSpan: Math.max(1, width - stateLayerSize)
    readonly property real thumbCenterX: stateLayerSize / 2 + visualPosition * valueSpan
    readonly property bool valueIndicatorOpen: showValueIndicator && enabled && (pressed || hovered || (activeFocus && keyboardIndicatorActive))
    readonly property color disabledActiveTrackColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)
    readonly property color disabledInactiveTrackColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.12)
    readonly property color disabledThumbColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)

    function lerp(fromValue, toValue, progress) {
        return fromValue + (toValue - fromValue) * progress;
    }

    implicitWidth: 360
    implicitHeight: 72
    leftPadding: 0
    rightPadding: 0
    topPadding: 4
    bottomPadding: 4
    z: valueIndicatorOpen ? 100 : 0
    hoverEnabled: true
    live: true
    focusPolicy: Qt.StrongFocus

    onPressedChanged: {
        if (pressed)
            keyboardIndicatorActive = false;
    }

    onHoveredChanged: {
        if (hovered)
            keyboardIndicatorActive = false;
    }

    Keys.onPressed: event => {
        keyboardIndicatorActive = true;
    }

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.Slider

    Material.theme: Material.System
    Material.accent: root.activeTrackColor
    Material.primary: root.activeTrackColor
    Material.foreground: Appearance.m3colors.m3onSurface
    Material.background: Appearance.m3colors.m3surface

    Behavior on pressProgress {
        NumberAnimation {
            duration: root.pressed ? 110 : 180
            easing.type: Easing.OutCubic
        }
    }

    background: Item {
        id: trackCanvas

        x: 0
        y: 0
        width: root.width
        height: root.height

        readonly property real centerY: root.topPadding + root.availableHeight / 2
        readonly property real trackStartX: root.stateLayerSize / 2 + root.currentTrackEdgeShrink
        readonly property real trackEndX: root.width - root.stateLayerSize / 2 - root.currentTrackEdgeShrink
        readonly property real thumbCenterX: root.thumbCenterX
        readonly property real halfGap: root.currentTrackGap / 2
        readonly property real activeEndX: Math.max(trackStartX, thumbCenterX - halfGap)
        readonly property real inactiveStartX: Math.min(trackEndX, thumbCenterX + halfGap)

        Rectangle {
            id: activeTrack

            x: trackCanvas.trackStartX
            y: trackCanvas.centerY - root.currentTrackHeight / 2
            width: Math.max(0, trackCanvas.activeEndX - x)
            height: root.currentTrackHeight
            radius: height / 2
            visible: width > 0
            color: root.enabled ? root.activeTrackColor : root.disabledActiveTrackColor
        }

        Rectangle {
            id: inactiveTrack

            x: trackCanvas.inactiveStartX
            y: trackCanvas.centerY - root.currentTrackHeight / 2
            width: Math.max(0, trackCanvas.trackEndX - x)
            height: root.currentTrackHeight
            radius: height / 2
            visible: width > 0
            color: root.enabled ? root.inactiveTrackColor : root.disabledInactiveTrackColor
        }

        Rectangle {
            id: stopIndicator

            width: root.stopIndicatorSize
            height: root.stopIndicatorSize
            radius: width / 2
            x: trackCanvas.trackEndX - root.currentTrackHeight / 2 - width / 2
            y: trackCanvas.centerY - height / 2
            scale: root.lerp(1, 0.75, root.pressProgress)
            visible: inactiveTrack.width > root.currentTrackHeight + width
            color: root.enabled ? root.thumbColor : root.disabledThumbColor
        }
    }

    handle: Item {
        id: handleRoot

        x: root.visualPosition * Math.max(1, root.width - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.stateLayerSize
        height: root.stateLayerSize
        z: 100

        Item {
            id: valueIndicator

            readonly property real thumbTop: (handleRoot.height - root.currentThumbHeight) / 2

            width: root.valueIndicatorDiameter
            height: root.valueIndicatorDiameter
            x: Math.max(-handleRoot.x, Math.min(root.width - handleRoot.x - width, (handleRoot.width - width) / 2))
            y: valueIndicator.thumbTop - height - root.valueIndicatorGap + (root.valueIndicatorOpen ? 0 : 10)
            opacity: root.valueIndicatorOpen ? 1 : 0
            scale: root.valueIndicatorOpen ? 1 : 0.72
            transformOrigin: Item.Bottom

            Behavior on opacity {
                NumberAnimation {
                    duration: root.valueIndicatorOpen ? 120 : 170
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: root.valueIndicatorOpen ? 120 : 170
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: root.valueIndicatorOpen ? 120 : 170
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.valueIndicatorColor
            }

            Text {
                id: valueIndicatorLabel

                anchors.centerIn: parent
                width: parent.width - 8
                height: parent.height
                text: root.valueFormatter(root.value)
                color: root.valueIndicatorTextColor
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 14
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 10
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.currentThumbWidth
            height: root.currentThumbHeight
            radius: width / 2
            color: root.enabled ? root.thumbColor : root.disabledThumbColor
        }
    }
}
