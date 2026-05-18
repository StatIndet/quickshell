import QtQuick
import QtQuick.Controls
import qs.Common

ScrollBar {
    id: root

    policy: ScrollBar.AsNeeded
    implicitWidth: orientation === Qt.Vertical ? Appearance.scrollBar.width + leftPadding + rightPadding : Math.max(Appearance.scrollBar.minLength, root.visualSize)
    implicitHeight: orientation === Qt.Horizontal ? Appearance.scrollBar.width + topPadding + bottomPadding : Math.max(Appearance.scrollBar.minLength, root.visualSize)
    topPadding: Appearance.scrollBar.margin
    bottomPadding: Appearance.scrollBar.margin
    leftPadding: orientation === Qt.Horizontal ? Appearance.scrollBar.margin : 0
    rightPadding: orientation === Qt.Horizontal ? Appearance.scrollBar.margin : 0

    background: Item {}

    contentItem: Rectangle {
        implicitWidth: root.orientation === Qt.Vertical ? Appearance.scrollBar.width : Math.max(Appearance.scrollBar.minLength, root.visualSize)
        implicitHeight: root.orientation === Qt.Horizontal ? Appearance.scrollBar.width : Math.max(Appearance.scrollBar.minLength, root.visualSize)
        radius: Appearance.scrollBar.radius
        color: Appearance.scrollBar.thumbColor
        opacity: root.policy === ScrollBar.AlwaysOn || ((root.active || root.hovered || root.pressed) && root.size < 1.0)
                 ? Appearance.scrollBar.activeOpacity
                 : Appearance.scrollBar.inactiveOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }
    }
}
