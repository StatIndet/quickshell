import QtQuick
import QtQuick.Controls
import qs.Common

Menu {
    id: root

    popupType: Popup.Item
    width: 240
    padding: 8
    margins: 8
    overlap: 0
    modal: false
    dim: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        radius: Appearance.rounding.small
        color: Appearance.m3colors.m3surfaceContainerHigh
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Easing.OutCubic
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Easing.InCubic
        }
    }
}
