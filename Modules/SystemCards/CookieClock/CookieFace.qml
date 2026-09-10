import QtQuick
import M3Shapes

// Geometry adapted from end-4/dots-hyprland's ii Cookie Clock (GPL-3.0).
// The external M3Shapes module owns every cookie contour, including the
// arbitrary-side fallback.
MaterialShape {
    id: root

    property int sides: 14
    property color fillColor: "transparent"
    readonly property bool genericShape: root.sides !== 0 && root.sides !== 1 && root.sides !== 4
                                         && root.sides !== 6 && root.sides !== 7 && root.sides !== 9 && root.sides
                                         !== 12
    readonly property int genericPoints: Math.max(3, root.sides)
    readonly property real genericCornerRadius: (root.sides < 17 ? 1.5 : 1.1) / Math.max(root.sides, 1)

    anchors.fill: parent
    shape: {
        switch (root.sides) {
        case 0:
        case 1:
            return MaterialShape.Circle;
        case 4:
            return MaterialShape.Cookie4Sided;
        case 6:
            return MaterialShape.Cookie6Sided;
        case 7:
            return MaterialShape.Cookie7Sided;
        case 9:
            return MaterialShape.Cookie9Sided;
        case 12:
            return MaterialShape.Cookie12Sided;
        default:
            return MaterialShape.Custom;
        }
    }
    customShape: root.genericShape ? shapeFactory.star(root.genericPoints, 0.8, root.genericCornerRadius, 0) :
                                     shapeFactory.regularPolygon(3)
    rotation: root.genericShape ? 30 : 0
    color: root.fillColor

    // The installed M3Shapes module exposes Q_INVOKABLE factories on an
    // instance rather than on the QML type object.
    MaterialShape {
        id: shapeFactory

        visible: false
    }
}
