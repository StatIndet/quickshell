import QtQuick
import qs.Common

Item {
    id: root

    required property string text
    property bool shown: false
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property alias font: tooltipText.font
    readonly property QtObject revealAnimation: Appearance.animation.expressiveEffects

    implicitWidth: tooltipText.implicitWidth + root.horizontalPadding * 2
    implicitHeight: tooltipText.implicitHeight + root.verticalPadding * 2

    readonly property bool isVisible: backgroundRectangle.implicitHeight > 0

    Rectangle {
        id: backgroundRectangle

        anchors {
            bottom: root.bottom
            horizontalCenter: root.horizontalCenter
        }

        color: Appearance.colors.colTooltip
        radius: 8
        opacity: root.shown ? 1 : 0
        implicitWidth: root.shown ? tooltipText.implicitWidth + root.horizontalPadding * 2 : 0
        implicitHeight: root.shown ? tooltipText.implicitHeight + root.verticalPadding * 2 : 0
        clip: true

        Behavior on implicitWidth {
            NumberAnimation {
                alwaysRunToEnd: true
                duration: root.revealAnimation.duration
                easing.type: root.revealAnimation.type
                easing.bezierCurve: root.revealAnimation.bezierCurve
            }
        }

        Behavior on implicitHeight {
            NumberAnimation {
                alwaysRunToEnd: true
                duration: root.revealAnimation.duration
                easing.type: root.revealAnimation.type
                easing.bezierCurve: root.revealAnimation.bezierCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                alwaysRunToEnd: true
                duration: root.revealAnimation.duration
                easing.type: root.revealAnimation.type
                easing.bezierCurve: root.revealAnimation.bezierCurve
            }
        }

        Text {
            id: tooltipText

            anchors.centerIn: parent
            text: root.text
            color: Appearance.colors.colOnTooltip
            wrapMode: Text.Wrap
            font.family: Sizes.fontFamily
            font.pixelSize: 12
            font.hintingPreference: Font.PreferNoHinting
        }
    }
}
