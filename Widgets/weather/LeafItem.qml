import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property int leafId: -1
    property color leafColor: "#76993E"
    property real leafScale: 1.0
    property real x0: -100
    property real y0: 0
    property real x1: 0
    property real y1: 0
    property real x2: 0
    property real y2: 0
    property real startRotation: 0
    property real endRotation: 0
    property int duration: 2000
    property real progress: 0

    signal finished(int leafId)

    readonly property real positionX: {
        const t = progress
        const inverse = 1 - t
        return inverse * inverse * x0 + 2 * inverse * t * x1 + t * t * x2
    }
    readonly property real positionY: {
        const t = progress
        const inverse = 1 - t
        return inverse * inverse * y0 + 2 * inverse * t * y1 + t * t * y2
    }

    width: 46
    height: 28
    x: positionX - width * 0.5
    y: positionY - height * 0.5
    scale: leafScale
    rotation: startRotation + (endRotation - startRotation) * progress
    opacity: 0.88
    transformOrigin: Item.Center

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        transform: Translate {
            x: -41.9
            y: -33.8
        }

        ShapePath {
            strokeWidth: 0
            fillColor: root.leafColor
            PathSvg {
                path: "M41.9,56.3l0.1-2.5c0,0,4.6-1.2,5.6-2.2c1-1,3.6-13,12-15.6c9.7-3.1,19.9-2,26.1-2.1c2.7,0-10,23.9-20.5,25c-7.5,0.8-17.2-5.1-17.2-5.1L41.9,56.3z"
            }
        }
    }

    NumberAnimation on progress {
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.Linear
        running: true
        onFinished: root.finished(root.leafId)
    }
}
