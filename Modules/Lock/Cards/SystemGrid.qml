import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Common
import qs.Services

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: width
    color: Appearance.colors.colLayer2
    radius: Metrics.lockCardRadius
    clip: true

    GridLayout {
        anchors.fill: parent
        anchors.margins: Metrics.lockOuterPadding
        rows: 2
        columns: 2
        rowSpacing: Metrics.spacingL
        columnSpacing: Metrics.spacingL

        ResourceTile {
            icon: "memory"
            value: Number(SystemMonitorService.cpu.usagePercent) / 100
            accent: Appearance.colors.colPrimary
        }

        ResourceTile {
            icon: "thermostat"
            value: Math.min(1, Math.max(0, (Number(SystemMonitorService.cpu.packageTemperatureCelsius) || Number(SystemMonitorService.cpu.temperatureCelsius)) / 90))
            accent: Appearance.colors.colSecondary
        }

        ResourceTile {
            icon: "memory_alt"
            value: Number(SystemMonitorService.memory.usagePercent) / 100
            accent: Appearance.colors.colSecondary
        }

        ResourceTile {
            icon: "hard_disk"
            value: (SystemMonitorService.disks.length > 0 ? Number(SystemMonitorService.disks[0].usagePercent) : 0) / 100
            accent: Appearance.colors.colTertiary
        }

    }

    component ResourceTile: Rectangle {
        id: tile

        property string icon: ""
        property real value: 0
        property real animatedValue: value
        property color accent: Appearance.colors.colPrimary
        readonly property real progressSize: Math.min(width, height)
        readonly property real progressPadding: Math.min(Metrics.lockResourceProgressPadding, progressSize * 0.42)
        readonly property real strokeSize: Math.min(Metrics.lockResourceProgressStroke, progressSize * 0.08)
        readonly property real progressValue: Math.max(1 / 360, Math.min(1, Math.max(0, animatedValue)))
        readonly property real arcRadius: Math.max(1, (progressSize - progressPadding - strokeSize) / 2)
        readonly property real gapAngle: ((Metrics.lockResourceProgressGap + strokeSize) / arcRadius) * (180 / Math.PI)

        Layout.fillWidth: true
        Layout.fillHeight: false
        implicitHeight: width
        color: Appearance.colors.colLayer3
        radius: Metrics.cornerL

        Shape {
            id: circleShape

            anchors.fill: parent
            rotation: -90
            preferredRendererType: Shape.CurveRenderer
            asynchronous: true

            ShapePath {
                strokeColor: Appearance.colors.colLayer4
                strokeWidth: tile.strokeSize
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: tile.progressSize / 2
                    centerY: tile.progressSize / 2
                    radiusX: tile.arcRadius
                    radiusY: tile.arcRadius
                    startAngle: 360 * tile.progressValue + tile.gapAngle
                    sweepAngle: Math.max(-tile.gapAngle, 360 * (1 - tile.progressValue) - tile.gapAngle * 2)
                }

            }

            ShapePath {
                strokeColor: tile.accent
                strokeWidth: tile.strokeSize
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: tile.progressSize / 2
                    centerY: tile.progressSize / 2
                    radiusX: tile.arcRadius
                    radiusY: tile.arcRadius
                    startAngle: 0
                    sweepAngle: 360 * tile.progressValue
                }

            }

        }

        Text {
            anchors.centerIn: parent
            text: tile.icon
            color: tile.accent
            font.family: Fonts.materialSymbolsOutlined
            font.pixelSize: Math.max(Metrics.iconL, tile.arcRadius * Metrics.lockResourceIconScale)
            font.weight: 600
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Behavior on animatedValue {
            NumberAnimation {
                duration: Appearance.animation.standardLarge.duration
                easing.type: Appearance.animation.standardLarge.type
                easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
            }

        }

    }

}
