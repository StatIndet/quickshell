import QtQuick
import QtQuick.Shapes
import M3Shapes
import qs.Common

Item {
    id: root

    property real value: 0
    property string level: "--"
    property int activeIndex: -1
    property string icon: "wb_sunny"
    property string title: qsTr("紫外线指数")
    property bool animationEnabled: false
    property bool animationActive: true

    WeatherAnimatedValue {
        id: valueAnimation
        targetValue: root.value
        enabled: root.animationEnabled
        active: root.animationActive
    }

    function uvIconPath() {
        return "M20,11H23V13H20V11M1,11H4V13H1V11M13,1V4H11V1H13M4.92,3.5L7.05,5.64L5.63,7.05L3.5,4.93L4.92,3.5M16.95,5.63L19.07,3.5L20.5,4.93L18.37,7.05L16.95,5.63M12,6A6,6 0 0,1 18,12C18,14.22 16.79,16.16 15,17.2V19A1,1 0 0,1 14,20H10A1,1 0 0,1 9,19V17.2C7.21,16.16 6,14.22 6,12A6,6 0 0,1 12,6M14,21V22A1,1 0 0,1 13,23H11A1,1 0 0,1 10,22V21H14M11,18H13V15.87C14.73,15.43 16,13.86 16,12A4,4 0 0,0 12,8A4,4 0 0,0 8,12C8,13.86 9.27,15.43 11,15.87V18Z"
    }

    Item {
        id: vectorLayer
        width: 176
        height: 176
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 176 * 0.98

        MaterialShape {
            anchors.fill: parent
            shape: MaterialShape.Cookie12Sided
            color: Appearance.colors.colWeatherCardSurface
        }

        Repeater {
            model: [
                { x: 31, y: 121, color: "#6dd58c" },
                { x: 54, y: 145, color: "#fcc934" },
                { x: 88, y: 155, color: "#fa903e" },
                { x: 120, y: 145, color: "#ee675c" },
                { x: 144, y: 121, color: "#af5cf7" }
            ]

            delegate: Rectangle {
                readonly property bool active: index === root.activeIndex
                width: active ? 16 : 12
                height: width
                radius: width / 2
                x: modelData.x - width / 2
                y: modelData.y - height / 2
                color: modelData.color
                opacity: active ? 1 : 0.15
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.22
        spacing: 6

        Item {
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            Shape {
                width: 24
                height: 24
                anchors.centerIn: parent
                scale: Math.min(parent.width / width, parent.height / height)
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: Appearance.colors.colOnWeatherCardSurfaceVariant

                    PathSvg {
                        path: root.uvIconPath()
                    }
                }
            }
        }

        Text {
            text: root.title
            color: Appearance.colors.colOnWeatherCardSurfaceVariant
            font.family: "Noto Sans CJK SC"
            font.bold: true
            font.pixelSize: 19
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        text: isNaN(valueAnimation.currentValue)
            ? "--"
            : Math.round(valueAnimation.currentValue)
        color: Appearance.colors.colOnWeatherCardSurface
        font.family: "MesloLGM Nerd Font"
        font.bold: true
        font.pixelSize: 62
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: 18
        width: parent.width * 0.40
        text: root.level
        color: Appearance.colors.colOnWeatherCardSurface
        font.family: "Noto Sans CJK SC"
        font.pixelSize: 22
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
