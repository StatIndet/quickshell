import QtQuick
import QtQuick.Shapes
import M3Shapes
import qs.Common

Item {
    id: root

    property real pressureValue: NaN
    property string valueText: "--"
    property string unitText: "hPa"
    property color accent: "#7ed0ff"
    property bool animationEnabled: false
    property bool animationActive: true

    readonly property real cardSize: Math.min(width, height)
    readonly property color ink: Appearance.colors.colOnWeatherCardSurface
    readonly property color mutedInk: Appearance.colors.colOnWeatherCardSurfaceVariant
    readonly property color cardFill: Appearance.colors.colWeatherCardSurface
    readonly property color trackTint: Qt.rgba(Qt.darker(accent, 3.1).r, Qt.darker(accent, 3.1).g, Qt.darker(accent, 3.1).b, 0.58)

    WeatherAnimatedValue {
        id: pressureAnimation
        targetValue: root.pressureValue
        enabled: root.animationEnabled
        active: root.animationActive
    }

    WeatherAnimatedValue {
        id: gaugeAnimation
        targetValue: isNaN(root.pressureValue)
                     ? NaN
                     : Math.max(0, Math.min(100, root.pressureValue - 963))
        enabled: root.animationEnabled
        active: root.animationActive
    }

    function gaugeIconPath() {
        return "M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M12,4A8,8 0 0,1 20,12C20,14.4 19,16.5 17.3,18C15.9,16.7 14,16 12,16C10,16 8.2,16.7 6.7,18C5,16.5 4,14.4 4,12A8,8 0 0,1 12,4M14,5.89C13.62,5.9 13.26,6.15 13.1,6.54L11.81,9.77L11.71,10C11,10.13 10.41,10.6 10.14,11.26C9.73,12.29 10.23,13.45 11.26,13.86C12.29,14.27 13.45,13.77 13.86,12.74C14.12,12.08 14,11.32 13.57,10.76L13.67,10.5L14.96,7.29L14.97,7.26C15.17,6.75 14.92,6.17 14.41,5.96C14.28,5.91 14.15,5.89 14,5.89M10,6A1,1 0 0,0 9,7A1,1 0 0,0 10,8A1,1 0 0,0 11,7A1,1 0 0,0 10,6M7,9A1,1 0 0,0 6,10A1,1 0 0,0 7,11A1,1 0 0,0 8,10A1,1 0 0,0 7,9M17,9A1,1 0 0,0 16,10A1,1 0 0,0 17,11A1,1 0 0,0 18,10A1,1 0 0,0 17,9Z"
    }

    function formattedPressureText() {
        if (isNaN(pressureAnimation.currentValue)) return root.valueText || "--"
        return Number(pressureAnimation.currentValue).toLocaleString(Qt.locale(), "f", 1)
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
            value: isNaN(gaugeAnimation.currentValue) ? 0 : gaugeAnimation.currentValue
            maximum: 100
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
                            path: root.gaugeIconPath()
                        }
                    }
                }
            }

            Text {
                text: qsTr("气压")
                color: root.mutedInk
                font.family: "LXGW WenKai GB Screen"
                font.pixelSize: 18
                font.bold: true
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -4
            text: root.formattedPressureText()
            color: root.ink
            font.family: "sans-serif"
            font.pixelSize: Math.round(parent.width * 0.21)
            font.weight: Font.Light
            z: 2
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 20
            text: root.unitText
            color: root.ink
            font.family: "LXGW WenKai GB Screen"
            font.pixelSize: 18
            font.bold: true
            z: 2
        }
    }
}
