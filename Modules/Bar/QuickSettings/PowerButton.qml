import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root
    property bool isHovered: mouseArea.containsMouse
    readonly property int buttonSize: 28
    readonly property var battery: SystemMonitorService.battery
    readonly property bool batteryAvailable:
        battery.present === true
        && isFinite(Number(battery.chargePercent))
    readonly property real batteryLevel: batteryAvailable
        ? Math.max(0, Math.min(1, Number(battery.chargePercent) / 100))
        : 0

    implicitHeight: buttonSize
    implicitWidth: buttonSize

    Item {
        id: buttonFace
        anchors.centerIn: parent
        width: root.buttonSize
        height: width
        scale: root.isHovered ? 1.14 : 1

        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: background
            anchors.centerIn: parent
            width: 21
            height: width
            radius: height / 2
            color: Appearance.colors.colError
        }

        Canvas {
            id: batteryRing
            anchors.fill: parent
            antialiasing: true

            property real displayedLevel: root.batteryLevel
            // Use a solid outline track so the complete enclosure stays
            // visible against both light and dark quick-settings surfaces.
            property color trackColor: Appearance.colors.colOutlineVariant
            property color progressColor: Appearance.colors.colPrimary

            Behavior on displayedLevel {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            onPaint: {
                const context = getContext("2d")
                context.reset()

                const center = width / 2
                const lineWidth = 2.4
                const radius = center - lineWidth / 2 - 0.4
                const startAngle = -Math.PI / 2

                context.lineWidth = lineWidth
                context.lineCap = "round"
                context.strokeStyle = trackColor
                context.beginPath()
                // Slight overlap removes the Canvas seam at the 3 o'clock
                // point, which otherwise looks like a one-pixel break.
                context.arc(center, center, radius, -0.01, Math.PI * 2 + 0.01)
                context.stroke()

                if (root.batteryAvailable && displayedLevel > 0) {
                    context.strokeStyle = progressColor
                    context.beginPath()
                    context.arc(center, center, radius,
                                startAngle,
                                startAngle + Math.PI * 2 * displayedLevel)
                    context.stroke()
                }
            }

            onDisplayedLevelChanged: requestPaint()
            onTrackColorChanged: requestPaint()
            onProgressColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Component.onCompleted: requestPaint()
        }

        Text {
            id: icon
            anchors.centerIn: parent
            text: "power_settings_new"
            font.family: Sizes.fontMaterialSymbols
            font.pixelSize: 18
            font.weight: Font.Normal
            color: Appearance.colors.colOnError
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached([
            Paths.systemScriptsDir + "/power-menu.sh",
            PersonalizationConfig.powerMenuStyle
        ])
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: root.batteryAvailable
            ? qsTr("电量: ") + Math.round(root.batteryLevel * 100) + "%\n"
                + qsTr("点击打开电源菜单")
            : qsTr("电源菜单")
    }
}
