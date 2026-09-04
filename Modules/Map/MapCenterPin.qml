import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root

    property color pinColor: "#45BEC6"
    property color pinOutlineColor: "#218C96"

    implicitWidth: 38
    implicitHeight: 48

    Shape {
        id: pin

        anchors.fill: parent
        layer.enabled: true

        ShapePath {
            fillColor: root.pinColor
            strokeColor: root.pinOutlineColor
            strokeWidth: 1.5
            startX: 19
            startY: 44

            PathCubic {
                x: 5
                y: 19
                control1X: 15
                control1Y: 39
                control2X: 5
                control2Y: 30
            }

            PathCubic {
                x: 19
                y: 4
                control1X: 5
                control1Y: 10
                control2X: 11
                control2Y: 4
            }

            PathCubic {
                x: 33
                y: 19
                control1X: 27
                control1Y: 4
                control2X: 33
                control2Y: 10
            }

            PathCubic {
                x: 19
                y: 44
                control1X: 33
                control1Y: 30
                control2X: 23
                control2Y: 39
            }

        }

        ShapePath {
            fillColor: "white"
            strokeColor: "#33000000"
            strokeWidth: 1
            startX: 26
            startY: 18

            PathAngleArc {
                centerX: 19
                centerY: 18
                radiusX: 7
                radiusY: 7
                startAngle: 0
                sweepAngle: 360
            }

        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#66000000"
            shadowBlur: 0.75
            shadowVerticalOffset: 4
            autoPaddingEnabled: true
        }

    }

}
