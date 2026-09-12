import QtQuick
import qs.Common
import qs.Modules.SystemCards

Item {
    id: root

    property bool active: false
    property var highlightRect: null
    property bool validDrop: true
    property bool showGuides: true

    visible: opacity > 0
    opacity: active ? 1 : 0

    Loader {
        anchors.fill: parent
        active: root.active && root.showGuides
        sourceComponent: SystemCardGridGuides {}
    }

    Rectangle {
        visible: root.active && root.highlightRect !== null
        x: root.highlightRect ? Number(root.highlightRect.x) : 0
        y: root.highlightRect ? Number(root.highlightRect.y) : 0
        width: root.highlightRect ? Number(root.highlightRect.width) : 0
        height: root.highlightRect ? Number(root.highlightRect.height) : 0
        radius: Appearance.rounding.extraLarge
        color: Appearance.applyAlpha((root.validDrop ? Appearance.colors.colPrimary :
                                                       Appearance.colors.colError), 0.14)
        border.width: 2
        border.color: Appearance.applyAlpha((root.validDrop ? Appearance.colors.colPrimary :
                                                              Appearance.colors.colError), 0.82)
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }
    }
}
