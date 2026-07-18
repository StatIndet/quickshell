import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common

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
    Material.accent: Appearance.colors.colError
    onClicked: stopRequested()

    background: Item {
        Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 32
            radius: Appearance.rounding.full
            color: root.down
                ? Appearance.colors.colSurfaceContainerHighestActive
                : (root.hovered
                    ? Appearance.colors.colSurfaceContainerHighestHover
                    : "transparent")
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
            opacity: root.stopping ? 1 : (root.enabled ? 1 : 0.38)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: root.down ? 10 : 12
                height: width
                radius: Appearance.rounding.extraSmall
                color: Appearance.colors.colError
                opacity: root.stopping ? 0.16 : 1

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }
            }

            BusyIndicator {
                anchors.centerIn: parent
                width: 22
                height: 22
                running: root.stopping
                visible: running
            }
        }
    }

    contentItem: Item {}

    ToolTip.visible: hovered
    ToolTip.text: stopping ? "正在完成录音" : "停止录音"
    ToolTip.delay: 500
}
