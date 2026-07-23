import QtQuick
import QtQuick.Shapes
import qs.Common

Item {
    id: root

    property int implicitSize: 30
    property int lineWidth: 2
    property real value: 0
    property color primaryColor: Appearance.colors.colOnSecondaryContainer
    property color trackColor: Appearance.colors.colSecondaryContainer
    property real gapAngle: 20
    property bool enableAnimation: true
    property int animationDuration: 800

    property real degree: Math.max(0, Math.min(1, value)) * 360
    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real arcRadius: Math.min(width, height) / 2 - lineWidth

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    Behavior on degree {
        enabled: root.enableAnimation
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: -90 - root.gapAngle
                sweepAngle: -(360 - root.degree - 2 * root.gapAngle)
            }
        }

        ShapePath {
            strokeColor: root.primaryColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: -90
                sweepAngle: root.degree
            }
        }
    }
}
