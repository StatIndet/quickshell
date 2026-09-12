import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real value: 0
    property real maximum: 100
    property color progressColor: "#72d572"
    property color trackColor: Qt.rgba(progressColor.r, progressColor.g, progressColor.b, 0.12)
    property real thickness: 10
    property real startAngle: 135
    property real sweepAngle: 270

    readonly property real gaugeRadius: Math.max(0, Math.min(width, height) / 2 - thickness / 2 - 3)
    readonly property real clampedRatio: maximum > 0 ? Math.max(0, Math.min(1, value / maximum)) : 0

    function radians(angle) {
        return angle * Math.PI / 180.0;
    }

    function pointX(angle) {
        return width / 2 + gaugeRadius * Math.cos(radians(angle));
    }

    function pointY(angle) {
        return height / 2 + gaugeRadius * Math.sin(radians(angle));
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.thickness
            strokeColor: root.trackColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.pointX(root.startAngle)
            startY: root.pointY(root.startAngle)

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.gaugeRadius
                radiusY: root.gaugeRadius
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle
            }
        }

        ShapePath {
            strokeWidth: root.clampedRatio > 0 ? root.thickness : 0
            strokeColor: root.clampedRatio > 0 ? root.progressColor : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.pointX(root.startAngle)
            startY: root.pointY(root.startAngle)

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.gaugeRadius
                radiusY: root.gaugeRadius
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle * root.clampedRatio
            }
        }
    }
}
