import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components

TabButton {
    id: root

    required property string buttonText
    required property string buttonIcon

    readonly property int rippleDuration: 1200
    readonly property color transparentSurface: Appearance.transparentize(Appearance.colors.colSurfaceContainer, 1)
    readonly property color hoverSurface: Appearance.applyAlpha(Appearance.colors.colOnSurface, checked ? 0 : 0.05)
    readonly property color rippleColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.05)

    implicitHeight: 48
    padding: 0
    hoverEnabled: true
    Accessible.name: buttonText

    function clearRipple() {
        rippleAnimation.stop();
        rippleFadeAnimation.stop();
        ripple.opacity = 0;
        ripple.implicitWidth = 0;
        ripple.implicitHeight = 0;
    }

    function startRipple(x, y) {
        root.clearRipple();
        const localY = y - buttonBackground.y;
        const distance = (offsetX, offsetY) => offsetX * offsetX + offsetY * offsetY;
        const bottom = buttonBackground.y + buttonBackground.height;

        rippleAnimation.originX = x;
        rippleAnimation.originY = localY;
        rippleAnimation.radius = Math.sqrt(Math.max(
            distance(0, buttonBackground.y),
            distance(0, bottom),
            distance(root.width, buttonBackground.y),
            distance(root.width, bottom)
        ));
        rippleAnimation.restart();
    }

    background: Rectangle {
        id: buttonBackground

        anchors.fill: parent
        anchors.margins: 3
        radius: Appearance.rounding.normal
        color: pointerArea.containsMouse ? root.hoverSurface : root.transparentSurface

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: buttonBackground.width
                height: buttonBackground.height
                radius: buttonBackground.radius
            }
        }

        Item {
            id: ripple

            property real implicitWidth: 0
            property real implicitHeight: 0

            width: implicitWidth
            height: implicitHeight
            opacity: 0
            visible: width > 0 && height > 0

            RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: root.rippleColor }
                    GradientStop { position: 0.3; color: root.rippleColor }
                    GradientStop { position: 0.5; color: Appearance.applyAlpha(root.rippleColor, 0) }
                }
            }

            transform: Translate {
                x: -ripple.width / 2
                y: -ripple.height / 2
            }
        }
    }

    contentItem: Row {
        anchors.centerIn: parent
        spacing: 5

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: root.buttonIcon
            iconSize: 21
            fill: root.checked ? 1 : 0
            color: root.checked ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.buttonText
            color: root.checked ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
            font.family: Sizes.fontFamily
            font.pixelSize: 13

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }
    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: event => {
            root.click();
            root.startRipple(event.x, event.y);
        }

        onReleased: rippleFadeAnimation.restart()
        onCanceled: rippleFadeAnimation.restart()
    }

    NumberAnimation {
        id: rippleFadeAnimation

        target: ripple
        property: "opacity"
        to: 0
        duration: root.rippleDuration * 2
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: rippleAnimation

        property real originX: 0
        property real originY: 0
        property real radius: 0

        PropertyAction { target: ripple; property: "x"; value: rippleAnimation.originX }
        PropertyAction { target: ripple; property: "y"; value: rippleAnimation.originY }
        PropertyAction { target: ripple; property: "opacity"; value: 1 }

        ParallelAnimation {
            NumberAnimation {
                target: ripple
                properties: "implicitWidth,implicitHeight"
                from: 0
                to: rippleAnimation.radius * 2
                duration: root.rippleDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
