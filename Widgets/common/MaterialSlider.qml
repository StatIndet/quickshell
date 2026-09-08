import QtQuick
import QtQuick.Controls
import qs.Common

Item {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property bool discrete: false
    property bool live: true
    property string accessibleName: qsTr("Slider")
    property string valueSuffix: ""
    property int valueDecimals: 0
    property var valueFormatter: function (sliderValue) {
        return Number(sliderValue).toFixed(root.valueDecimals) + root.valueSuffix;
    }
    property bool showValueIndicator: true

    readonly property bool pressed: control.pressed
    readonly property bool hovered: control.hovered

    readonly property real stateLayerSize: 40
    readonly property real trackInset: stateLayerSize / 2
    readonly property real trackHeight: 16
    readonly property real handleHeight: 44
    readonly property real handleTrackGap: 18
    readonly property real trackCenterY: Math.min(54, Math.max(30, root.height - 12))
    readonly property bool valueIndicatorVisible: root.showValueIndicator && root.enabled && (control.pressed
                                                                                              || control.hovered
                                                                                              || control.visualFocus)

    signal moved(real value)
    signal committed(real value)

    function formattedValue(sliderValue) {
        if (typeof root.valueFormatter === "function")
            return String(root.valueFormatter(sliderValue));
        return Number(sliderValue).toFixed(root.valueDecimals) + root.valueSuffix;
    }

    implicitWidth: 360
    implicitHeight: 78

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.Slider

    Slider {
        id: control

        anchors.fill: parent
        from: root.from
        to: root.to
        stepSize: root.stepSize
        snapMode: root.discrete ? Slider.SnapAlways : Slider.NoSnap
        enabled: root.enabled
        live: root.live
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus

        Binding {
            target: control
            property: "value"
            value: root.value
            when: !control.pressed
        }

        property bool gestureStarted: false

        onPressedChanged: {
            if (pressed) {
                gestureStarted = true;
            } else if (gestureStarted) {
                gestureStarted = false;
                root.committed(control.value);
            }
        }

        onMoved: root.moved(control.value)

        background: Item {
            id: track

            x: control.leftPadding
            y: 0
            width: control.availableWidth
            height: control.height

            readonly property real usableWidth: Math.max(1, width - root.trackInset * 2)
            readonly property real trackStartX: root.trackInset
            readonly property real trackEndX: root.trackInset + usableWidth
            readonly property real handleCenterX: root.trackInset + control.visualPosition * usableWidth
            readonly property real halfGap: root.handleTrackGap / 2
            readonly property real activeEndX: Math.max(trackStartX, handleCenterX - halfGap)
            readonly property real inactiveStartX: Math.min(trackEndX, handleCenterX + halfGap)

            Rectangle {
                id: activeTrack

                x: track.trackStartX
                y: root.trackCenterY - root.trackHeight / 2
                width: Math.max(0, track.activeEndX - x)
                height: root.trackHeight
                radius: height / 2
                visible: width > 0
                color: control.enabled ? Appearance.colors.colPrimary : Appearance.applyAlpha(
                                             Appearance.colors.colOnSurface, 0.38)

                Behavior on width {
                    enabled: !control.pressed
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }

            Rectangle {
                id: inactiveTrack

                x: track.inactiveStartX
                y: root.trackCenterY - root.trackHeight / 2
                width: Math.max(0, track.trackEndX - x)
                height: root.trackHeight
                radius: height / 2
                visible: width > 0
                color: control.enabled ? Appearance.colors.colSecondaryContainer : Appearance.applyAlpha(
                                             Appearance.colors.colOnSurface, 0.12)

                Behavior on x {
                    enabled: !control.pressed
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }

                Behavior on width {
                    enabled: !control.pressed
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }

            Repeater {
                model: root.discrete && root.stepSize > 0 ? Math.floor(Math.abs(root.to - root.from)
                                                                       / root.stepSize) + 1 : 0

                Rectangle {
                    required property int index
                    readonly property real fraction: Math.min(1, index * root.stepSize / Math.abs(root.to
                                                                                                  - root.from))
                    readonly property real centerX: track.trackStartX + (control.mirrored ? 1 - fraction :
                                                                                            fraction)
                                                    * track.usableWidth
                    width: 4
                    height: 4
                    radius: 2
                    x: Math.max(track.trackStartX + root.trackHeight / 2, Math.min(track.trackEndX - root.trackHeight
                                                                                   / 2, centerX)) - width / 2
                    y: root.trackCenterY - height / 2
                    visible: x + width < track.activeEndX || x > track.inactiveStartX
                    color: fraction <= control.position ? Appearance.colors.colOnPrimary :
                                                          Appearance.colors.colOnSecondaryContainer
                    opacity: control.enabled ? 1 : 0.38
                }
            }

            Rectangle {
                id: endStopIndicator

                width: 8
                height: 8
                radius: width / 2
                // Keep the complete circle inside the inactive track cap.
                x: track.trackEndX - root.trackHeight / 2 - width / 2
                y: root.trackCenterY - height / 2
                visible: !root.discrete && inactiveTrack.width >= root.trackHeight
                color: control.enabled ? Appearance.colors.colOnSecondaryContainer : Appearance.applyAlpha(
                                             Appearance.colors.colOnSurface, 0.38)
            }
        }

        handle: Item {
            id: handleRoot

            x: control.leftPadding + root.trackInset + control.visualPosition * Math.max(1, control.availableWidth
                                                                                         - root.trackInset
                                                                                         * 2) - width / 2
            y: root.trackCenterY - height / 2
            width: root.stateLayerSize
            height: root.handleHeight
            z: 100

            Behavior on x {
                enabled: !control.pressed
                NumberAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }

            Item {
                id: valueIndicator

                width: Math.max(40, valueLabel.implicitWidth + 20)
                height: 32
                x: Math.max(-handleRoot.x, Math.min(root.width - handleRoot.x - width, (handleRoot.width
                                                                                        - width) / 2))
                y: -height - 8 + (root.valueIndicatorVisible ? 0 : 8)
                opacity: root.valueIndicatorVisible ? 1 : 0
                scale: root.valueIndicatorVisible ? 1 : 0.82
                transformOrigin: Item.Bottom

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimary
                }

                Text {
                    id: valueLabel

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: root.formattedValue(control.value)
                    color: Appearance.colors.colOnPrimary
                    font.family: Fonts.numeric
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: control.pressed || control.visualFocus ? 2 : 4
                height: parent.height
                radius: width / 2
                color: control.enabled ? Appearance.colors.colPrimary : Appearance.applyAlpha(
                                             Appearance.colors.colOnSurface, 0.38)

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }
        }
    }
}
