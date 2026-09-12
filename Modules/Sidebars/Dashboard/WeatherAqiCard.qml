import QtQuick
import QtQuick.Shapes
import M3Shapes
import qs.Common

Item {
    id: root

    property real aqiValue: NaN
    property string levelText: "--"
    property color accent: "#00e59b"
    property bool animationEnabled: false
    property bool animationActive: true

    readonly property real cardSize: Math.min(width, height)
    readonly property color ink: Appearance.colors.colOnWeatherCardSurface
    readonly property color mutedInk: Appearance.colors.colOnWeatherCardSurfaceVariant
    readonly property color cardFill: Appearance.colors.colWeatherCardSurface
    readonly property color trackTint: Qt.rgba(Qt.darker(accent, 2.9).r, Qt.darker(accent, 2.9).g, Qt.darker(accent,
                                                                                                             2.9).b, 0.58)

    WeatherAnimatedValue {
        id: aqiAnimation
        targetValue: root.aqiValue
        enabled: root.animationEnabled
        active: root.animationActive
    }

    Item {
        id: card
        width: root.cardSize
        height: root.cardSize
        anchors.centerIn: parent

        MaterialShape {
            anchors.fill: parent
            shape: MaterialShape.Circle
            color: root.cardFill
        }

        WeatherArcGauge {
            width: parent.width * 0.93
            height: width
            anchors.centerIn: parent
            value: isNaN(aqiAnimation.currentValue) ? 0 : aqiAnimation.currentValue
            maximum: 250
            progressColor: root.accent
            trackColor: root.trackTint
            thickness: Math.max(12, Math.round(parent.width * 0.042))
            startAngle: 135
            sweepAngle: 270
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(parent.width * 0.17)
            spacing: 8
            z: 2

            Item {
                width: 28
                height: 28

                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        fillColor: root.mutedInk

                        PathSvg {
                            path: "M14,8.5A1.5,1.5 0 0,0 12.5,10A1.5,1.5 0 0,0 14,11.5A1.5,1.5 0 0,0 15.5,10A1.5,1.5 0 0,0 14,8.5M14,12.5A1.5,1.5 0 0,0 12.5,14A1.5,1.5 0 0,0 14,15.5A1.5,1.5 0 0,0 15.5,14A1.5,1.5 0 0,0 14,12.5M10,17A1,1 0 0,0 9,18A1,1 0 0,0 10,19A1,1 0 0,0 11,18A1,1 0 0,0 10,17M10,8.5A1.5,1.5 0 0,0 8.5,10A1.5,1.5 0 0,0 10,11.5A1.5,1.5 0 0,0 11.5,10A1.5,1.5 0 0,0 10,8.5M14,20.5A0.5,0.5 0 0,0 13.5,21A0.5,0.5 0 0,0 14,21.5A0.5,0.5 0 0,0 14.5,21A0.5,0.5 0 0,0 14,20.5M14,17A1,1 0 0,0 13,18A1,1 0 0,0 14,19A1,1 0 0,0 15,18A1,1 0 0,0 14,17M21,13.5A0.5,0.5 0 0,0 20.5,14A0.5,0.5 0 0,0 21,14.5A0.5,0.5 0 0,0 21.5,14A0.5,0.5 0 0,0 21,13.5M18,5A1,1 0 0,0 17,6A1,1 0 0,0 18,7A1,1 0 0,0 19,6A1,1 0 0,0 18,5M18,9A1,1 0 0,0 17,10A1,1 0 0,0 18,11A1,1 0 0,0 19,10A1,1 0 0,0 18,9M18,17A1,1 0 0,0 17,18A1,1 0 0,0 18,19A1,1 0 0,0 19,18A1,1 0 0,0 18,17M18,13A1,1 0 0,0 17,14A1,1 0 0,0 18,15A1,1 0 0,0 19,14A1,1 0 0,0 18,13M10,12.5A1.5,1.5 0 0,0 8.5,14A1.5,1.5 0 0,0 10,15.5A1.5,1.5 0 0,0 11.5,14A1.5,1.5 0 0,0 10,12.5M10,7A1,1 0 0,0 11,6A1,1 0 0,0 10,5A1,1 0 0,0 9,6A1,1 0 0,0 10,7M10,3.5A0.5,0.5 0 0,0 10.5,3A0.5,0.5 0 0,0 10,2.5A0.5,0.5 0 0,0 9.5,3A0.5,0.5 0 0,0 10,3.5M10,20.5A0.5,0.5 0 0,0 9.5,21A0.5,0.5 0 0,0 10,21.5A0.5,0.5 0 0,0 10.5,21A0.5,0.5 0 0,0 10,20.5M3,13.5A0.5,0.5 0 0,0 2.5,14A0.5,0.5 0 0,0 3,14.5A0.5,0.5 0 0,0 3.5,14A0.5,0.5 0 0,0 3,13.5M14,3.5A0.5,0.5 0 0,0 14.5,3A0.5,0.5 0 0,0 14,2.5A0.5,0.5 0 0,0 13.5,3A0.5,0.5 0 0,0 14,3.5M14,7A1,1 0 0,0 15,6A1,1 0 0,0 14,5A1,1 0 0,0 13,6A1,1 0 0,0 14,7M21,10.5A0.5,0.5 0 0,0 21.5,10A0.5,0.5 0 0,0 21,9.5A0.5,0.5 0 0,0 20.5,10A0.5,0.5 0 0,0 21,10.5M6,5A1,1 0 0,0 5,6A1,1 0 0,0 6,7A1,1 0 0,0 7,6A1,1 0 0,0 6,5M3,9.5A0.5,0.5 0 0,0 2.5,10A0.5,0.5 0 0,0 3,10.5A0.5,0.5 0 0,0 3.5,10A0.5,0.5 0 0,0 3,9.5M6,9A1,1 0 0,0 5,10A1,1 0 0,0 6,11A1,1 0 0,0 7,10A1,1 0 0,0 6,9M6,17A1,1 0 0,0 5,18A1,1 0 0,0 6,19A1,1 0 0,0 7,18A1,1 0 0,0 6,17M6,13A1,1 0 0,0 5,14A1,1 0 0,0 6,15A1,1 0 0,0 7,14A1,1 0 0,0 6,13Z"
                        }
                    }
                }
            }

            Text {
                text: qsTr("Air quality")
                color: root.mutedInk
                font.family: Fonts.expressive
                font.pixelSize: 18
                font.bold: true
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -12
            text: isNaN(aqiAnimation.currentValue) ? "--" : Math.round(aqiAnimation.currentValue)
            color: root.ink
            font.family: Fonts.expressive
            font.pixelSize: Math.round(parent.width * 0.29)
            font.weight: Font.Light
            z: 2
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 28
            width: parent.width * 0.42
            horizontalAlignment: Text.AlignHCenter
            text: root.levelText
            color: root.ink
            font.family: Fonts.expressive
            font.pixelSize: 18
            font.bold: true
            elide: Text.ElideRight
            z: 2
        }
    }
}
