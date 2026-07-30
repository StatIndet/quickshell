import QtQuick
import M3Shapes
import qs.Common

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property color iconColor: Appearance.colors.colOnSurface
    property color titleColor: Appearance.colors.colOnSurface
    property int headerLeftMargin: 18
    property int headerTopMargin: 16
    property int headerSpacing: 6
    property int shapeId: MaterialShape.Square
    property real shapeInset: 0
    property color shapeColor:
        Appearance.colors.colWeatherCardSurface
    default property alias content: contentLayer.data

    radius: 34
    color: "transparent"
    border.width: 0
    clip: true

    MaterialShape {
        anchors {
            fill: parent
            margins: root.shapeInset
        }
        shape: root.shapeId
        color: root.shapeColor
    }

    Item {
        id: contentLayer
        anchors.fill: parent
    }

    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: root.headerLeftMargin
        anchors.topMargin: root.headerTopMargin
        spacing: root.headerSpacing
        visible: root.icon.length > 0 || root.title.length > 0
        z: 2

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.iconColor
            font.family: "Material Symbols Outlined"
            font.pixelSize: 18
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.title.length > 0
            text: root.title
            color: root.titleColor
            font.family: "Noto Sans CJK SC"
            font.pixelSize: 13
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
