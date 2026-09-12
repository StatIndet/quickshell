import QtQuick
import QtQuick.Shapes
import qs.Common
import "./SystemCardGrid.js" as Grid

Shape {
    id: root
    preferredRendererType: Shape.CurveRenderer
    readonly property string gridPath: {
        let path = "";
        for (let x = 0; x <= width; x += Grid.cardGridGuideStep)
            path += "M " + x + " 0 V " + height + " ";
        for (let y = 0; y <= height; y += Grid.cardGridGuideStep)
            path += "M 0 " + y + " H " + width + " ";
        return path;
    }
    ShapePath {
        fillColor: "transparent"
        strokeColor: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.22)
        strokeWidth: 1
        PathSvg {
            path: root.gridPath
        }
    }
}
