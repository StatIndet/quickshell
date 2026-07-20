import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common
import qs.Components
import qs.Widgets.common

RoundButton {
    id: root

    property bool stopping: false
    property bool canStop: true
    signal stopRequested()

    width: 44
    height: 44
    padding: 0
    enabled: canStop && !stopping
    hoverEnabled: true
    display: AbstractButton.IconOnly
    scale: down ? 0.9 : (hovered ? 1.04 : 1)
    Material.accent: Appearance.colors.colOnErrorContainer
    onClicked: stopRequested()

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animation.expressiveFastSpatial.duration
            easing.type: Appearance.animation.expressiveFastSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
        }
    }

    background: Item {
        Rectangle {
            anchors.centerIn: parent
            width: 36
            height: 36
            radius: Appearance.rounding.full
            color: root.down
                ? Appearance.colors.colErrorContainerActive
                : (root.hovered
                    ? Appearance.colors.colErrorContainerHover
                    : Appearance.colors.colErrorContainer)
            opacity: root.stopping ? 0.55 : (root.enabled ? 1 : 0.38)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveEffects.duration
                    easing.type: Appearance.animation.expressiveEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                }
            }
        }
    }

    contentItem: Item {
        MaterialSymbol {
            anchors.centerIn: parent
            text: "stop"
            iconSize: 20
            fill: 1
            color: Appearance.colors.colOnErrorContainer
            visible: !root.stopping
        }

        BusyIndicator {
            anchors.centerIn: parent
            width: 22
            height: 22
            running: root.stopping
            visible: running
        }
    }

    StyledToolTip {
        extraVisibleCondition: root.hovered
        text: root.stopping ? "正在完成录音" : "停止录音"
    }
}
