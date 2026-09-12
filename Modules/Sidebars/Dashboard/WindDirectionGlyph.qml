import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color glyphColor: "#72d572"
    property real directionDegrees: 0

    implicitWidth: 42
    implicitHeight: 42

    Item {
        width: 176
        height: 176
        anchors.centerIn: parent
        scale: Math.min(root.width / width, root.height / height)
        rotation: root.directionDegrees
        transformOrigin: Item.Center

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: root.glyphColor

                PathSvg {
                    path: "M108.04,151.24C99.97,168.05 76.03,168.05 67.96,151.24L27.21,66.3C18.79,48.75 35.4,29.63 53.96,35.5L81.29,44.15C85.66,45.54 90.34,45.54 94.71,44.15L122.04,35.5C140.6,29.63 157.21,48.75 148.79,66.3L108.04,151.24Z"
                }
            }
        }
    }
}
