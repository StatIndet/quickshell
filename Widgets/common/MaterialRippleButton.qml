import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.Common

Button {
    id: root

    property bool toggled: false
    property string buttonText: ""
    property bool pointingHandCursor: true
    property real buttonRadius: Appearance.rounding.small
    property real buttonRadiusPressed: buttonRadius
    readonly property real buttonEffectiveRadius: root.down ? root.buttonRadiusPressed : root.buttonRadius
    property int rippleDuration: 1200
    property bool rippleEnabled: true
    property var downAction
    property var releaseAction
    property var doubleClickAction
    property var altAction
    property var middleClickAction

    property color colBackground: Appearance.transparentize(Appearance.colors.colLayer1Hover, 1)
    property color colBackgroundHover: Appearance.colors.colLayer1Hover
    property color colBackgroundToggled: Appearance.colors.colPrimary
    property color colBackgroundToggledHover: Appearance.colors.colPrimaryHover
    property color colRipple: Appearance.colors.colLayer1Active
    property color colRippleToggled: Appearance.colors.colPrimaryActive

    readonly property bool pointerHovered: pointerArea.containsMouse
    readonly property color buttonColor: Appearance.transparentize(root.toggled
        ? (root.pointerHovered ? root.colBackgroundToggledHover : root.colBackgroundToggled)
        : (root.pointerHovered ? root.colBackgroundHover : root.colBackground),
        root.enabled ? 0 : 1)
    readonly property color rippleColor: root.toggled ? root.colRippleToggled : root.colRipple

    opacity: root.enabled ? 1 : 0.4
    hoverEnabled: true

    function startRipple(x, y) {
        const stateY = buttonBackground.y;
        rippleAnim.x = x;
        rippleAnim.y = y - stateY;

        const dist = (ox, oy) => ox * ox + oy * oy;
        const stateEndY = stateY + buttonBackground.height;
        rippleAnim.radius = Math.sqrt(Math.max(
            dist(0, stateY),
            dist(0, stateEndY),
            dist(width, stateY),
            dist(width, stateEndY)
        ));

        rippleFadeAnim.complete();
        rippleAnim.restart();
    }

    component RippleAnim: NumberAnimation {
        duration: root.rippleDuration
        easing.type: Appearance.animation.expressiveDefaultSpatial.type
        easing.bezierCurve: Appearance.animationCurves.standardDecel
    }

    background: Rectangle {
        id: buttonBackground

        radius: root.buttonEffectiveRadius
        implicitHeight: 30
        color: root.buttonColor

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: buttonBackground.width
                height: buttonBackground.height
                radius: root.buttonEffectiveRadius
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

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }

            RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.rippleColor }
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

    contentItem: Text {
        text: root.buttonText
        color: Appearance.colors.colOnLayer1
        font.family: Sizes.fontFamily
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.pointingHandCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: event => {
            if (event.button === Qt.RightButton) {
                if (root.altAction)
                    root.altAction(event);
                return;
            }
            if (event.button === Qt.MiddleButton) {
                if (root.middleClickAction)
                    root.middleClickAction(event);
                return;
            }

            root.down = true;
            if (root.downAction)
                root.downAction(event);
            if (root.rippleEnabled)
                root.startRipple(event.x, event.y);
        }

        onReleased: event => {
            root.down = false;
            if (event.button !== Qt.LeftButton)
                return;

            if (root.releaseAction)
                root.releaseAction(event);
            root.click();

            if (root.rippleEnabled)
                rippleFadeAnim.restart();
        }

        onDoubleClicked: event => {
            if (event.button === Qt.LeftButton && root.doubleClickAction)
                root.doubleClickAction(event);
        }

        onCanceled: {
            root.down = false;
            if (root.rippleEnabled)
                rippleFadeAnim.restart();
        }
    }

    RippleAnim {
        id: rippleFadeAnim
        duration: root.rippleDuration * 2
        target: ripple
        property: "opacity"
        to: 0
    }

    SequentialAnimation {
        id: rippleAnim

        property real x
        property real y
        property real radius

        PropertyAction { target: ripple; property: "x"; value: rippleAnim.x }
        PropertyAction { target: ripple; property: "y"; value: rippleAnim.y }
        PropertyAction { target: ripple; property: "opacity"; value: 1 }

        RippleAnim {
            target: ripple
            properties: "implicitWidth,implicitHeight"
            from: 0
            to: rippleAnim.radius * 2
        }
    }
}
