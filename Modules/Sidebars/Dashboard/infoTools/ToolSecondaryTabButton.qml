import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Components
import qs.Widgets.common

TabButton {
    id: root

    required property string buttonText
    required property string buttonIcon

    readonly property int tabMargin: 3
    readonly property color transparentSurface: Appearance.transparentize(
                                                    Appearance.colors.colSurfaceContainer, 1)
    readonly property color hoverSurface: Appearance.applyAlpha(Appearance.colors.colOnSurface, checked ? 0 :
                                                                                                          0.05)

    implicitHeight: 48
    padding: 0
    hoverEnabled: true
    Accessible.name: buttonText

    background: Rectangle {
        id: buttonBackground

        anchors.fill: parent
        anchors.margins: root.tabMargin
        radius: Appearance.rounding.normal
        color: pointerArea.containsMouse ? root.hoverSurface : root.transparentSurface

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }

        RippleEffect {
            id: rippleEffect

            anchors.fill: parent
            color: Appearance.colors.colOnSurface
            shapeRadius: buttonBackground.radius
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
            font.family: Fonts.ui
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
        acceptedButtons: Qt.LeftButton

        onPressed: event => {
            root.click();
            const localPoint = buttonBackground.mapFromItem(pointerArea, event.x, event.y);
            rippleEffect.startAt(localPoint.x, localPoint.y);
        }

        onReleased: rippleEffect.finish()
        onCanceled: rippleEffect.finish()
    }
}
