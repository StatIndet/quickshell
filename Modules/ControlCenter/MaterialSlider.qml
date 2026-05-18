import QtQuick
import QtQuick.Controls
import qs.Common

Item {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property bool enabled: true
    property string valueSuffix: ""

    readonly property int stateLayerSize: 40
    readonly property int trackInset: stateLayerSize / 2
    readonly property int trackHeight: 16
    readonly property int handleHeight: 44
    readonly property int handleTrackGap: 20
    readonly property int trackCenterY: 54
    readonly property bool valueIndicatorVisible: control.pressed || control.hovered || control.activeFocus

    signal moved(real value)

    implicitHeight: 78

    Slider {
        id: control

        anchors.fill: parent
        from: root.from
        to: root.to
        stepSize: root.stepSize
        enabled: root.enabled
        hoverEnabled: true
        live: true

        Binding {
            target: control
            property: "value"
            value: root.value
            when: !control.pressed
        }

        onMoved: root.moved(value)

        background: Item {
            id: track

            x: control.leftPadding
            y: root.trackCenterY - root.trackHeight / 2
            width: control.availableWidth
            height: root.trackHeight

            readonly property real usableWidth: Math.max(1, width - root.trackInset * 2)
            readonly property real handleCenterX: root.trackInset + control.visualPosition * usableWidth
            readonly property real halfGap: root.handleTrackGap / 2
            readonly property real activeEndX: Math.max(root.trackInset, handleCenterX - halfGap)
            readonly property real inactiveStartX: Math.min(root.trackInset + usableWidth, handleCenterX + halfGap)

            Rectangle {
                id: activeTrack

                x: root.trackInset
                width: Math.max(0, track.activeEndX - x)
                height: parent.height
                radius: height / 2
                visible: width > 0
                color: control.enabled ? Appearance.colors.colPrimary : Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)

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
                width: Math.max(0, root.trackInset + track.usableWidth - x)
                height: parent.height
                radius: height / 2
                visible: width > 0
                color: control.enabled ? Appearance.colors.colSecondaryContainer : Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.12)

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

            Rectangle {
                id: endStopIndicator

                width: 8
                height: 8
                radius: 4
                x: root.trackInset + track.usableWidth - width / 2
                y: (parent.height - height) / 2
                visible: inactiveTrack.width > root.trackHeight
                color: control.enabled ? Appearance.colors.colOnSecondaryContainer : Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }
        }

        handle: Item {
            id: handleRoot

            x: control.leftPadding + root.trackInset + control.visualPosition * Math.max(1, control.availableWidth - root.trackInset * 2) - width / 2
            y: root.trackCenterY - height / 2
            width: root.stateLayerSize
            height: root.handleHeight

            readonly property real nubWidth: control.pressed || control.activeFocus ? 2 : 4

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

                width: Math.max(36, valueLabel.implicitWidth + 18)
                height: 34
                x: Math.max(-handleRoot.x, Math.min(control.width - handleRoot.x - width, (handleRoot.width - width) / 2))
                y: -42
                opacity: root.valueIndicatorVisible ? 1 : 0
                scale: root.valueIndicatorVisible ? 1 : 0.72
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
                    id: indicatorCone

                    width: 12
                    height: 12
                    radius: 2
                    x: (parent.width - width) / 2
                    y: parent.height - 12
                    rotation: 45
                    color: Appearance.colors.colPrimary
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 28
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimary

                    Text {
                        id: valueLabel

                        anchors.centerIn: parent
                        text: Math.round(control.value) + root.valueSuffix
                        color: Appearance.colors.colOnPrimary
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: handleRoot.nubWidth
                height: parent.height
                radius: width / 2
                color: control.enabled ? Appearance.colors.colPrimary : Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)

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
