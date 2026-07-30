import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import M3Shapes
import qs.Common

WeatherInsightCard {
    id: root

    property real humidityValue: NaN
    property string humidityText: "--"
    property string dewPointText: "--"
    property color accent: "#6f649b"
    property bool animationEnabled: false
    property bool animationActive: true

    readonly property real dewPointValue: numericTextValue(dewPointText)

    icon: ""
    title: ""
    shapeId: MaterialShape.Square
    shapeColor: Appearance.colors.colWeatherCardSurface

    function humidityIconPath() {
        return "M580,720Q605,720 622.5,702.5Q640,685 640,660Q640,635 622.5,617.5Q605,600 580,600Q555,600 537.5,617.5Q520,635 520,660Q520,685 537.5,702.5Q555,720 580,720ZM378,718L638,458L582,402L322,662L378,718ZM380,520Q405,520 422.5,502.5Q440,485 440,460Q440,435 422.5,417.5Q405,400 380,400Q355,400 337.5,417.5Q320,435 320,460Q320,485 337.5,502.5Q355,520 380,520ZM480,880Q343,880 251.5,786Q160,692 160,552Q160,452 239.5,334.5Q319,217 480,80Q641,217 720.5,334.5Q800,452 800,552Q800,692 708.5,786Q617,880 480,880ZM480,800Q584,800 652,729.5Q720,659 720,552Q720,479 659.5,387Q599,295 480,186Q361,295 300.5,387Q240,479 240,552Q240,659 308,729.5Q376,800 480,800ZM480,480Q480,480 480,480Q480,480 480,480Q480,480 480,480Q480,480 480,480Q480,480 480,480Q480,480 480,480Q480,480 480,480Q480,480 480,480Z"
    }

    function humidityPercentValue() {
        if (isNaN(root.humidityValue)) return NaN
        return root.humidityValue <= 1.0 ? root.humidityValue * 100.0 : root.humidityValue
    }

    function numericTextValue(text) {
        const match = (text || "").match(/[-+]?\d+(?:\.\d+)?/)
        return match ? Number(match[0]) : NaN
    }

    function animatedHumidityText() {
        return isNaN(humidityAnimation.currentValue)
                ? "--"
                : Math.round(humidityAnimation.currentValue) + "%"
    }

    function animatedDewPointText() {
        return isNaN(dewPointAnimation.currentValue)
                ? "--"
                : Math.round(dewPointAnimation.currentValue) + "°"
    }

    WeatherAnimatedValue {
        id: humidityAnimation
        targetValue: root.humidityPercentValue()
        enabled: root.animationEnabled
        active: root.animationActive
    }

    WeatherAnimatedValue {
        id: dewPointAnimation
        targetValue: root.dewPointValue
        enabled: root.animationEnabled
        active: root.animationActive
    }

    function waveBucket() {
        const value = humidityPercentValue()
        if (isNaN(value)) return 50
        if (value <= 20) return 7
        if (value <= 40) return 30
        if (value <= 60) return 50
        if (value <= 80) return 75
        return 90
    }

    function waveSource() {
        return Paths.icon("humidity_percent_" + waveBucket() + ".svg")
    }

    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.topMargin: 16
        spacing: 8
        z: 3

        Item {
            width: 28
            height: 28

            Shape {
                width: 960
                height: 960
                anchors.centerIn: parent
                scale: Math.min(parent.width / width, parent.height / height)
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: Appearance.colors.colOnWeatherCardSurfaceVariant

                    PathSvg {
                        path: root.humidityIconPath()
                    }
                }
            }
        }

        Text {
            text: qsTr("相对湿度")
            color: Appearance.colors.colOnWeatherCardSurfaceVariant
            font.family: "LXGW WenKai GB Screen"
            font.pixelSize: 18
            font.bold: true
        }
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: humidityMask
        }

        Image {
            anchors.fill: parent
            source: root.waveSource()
            fillMode: Image.Stretch
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            sourceSize.width: Math.max(1, Math.round(width * 2))
            sourceSize.height: Math.max(1, Math.round(height * 2))
        }
    }

    MaterialShape {
        id: humidityMask

        anchors.fill: parent
        shape: root.shapeId
        color: "white"
        visible: false
        layer.enabled: true
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 18
        anchors.topMargin: 72
        text: root.animatedHumidityText()
        color: Appearance.colors.colOnWeatherCardSurface
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 58
        font.bold: true
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.bottomMargin: 18
        spacing: 12
        z: 2

        Rectangle {
            width: 52
            height: 52
            radius: 26
            color: Appearance.colors.colPrimaryContainer

            Text {
                anchors.centerIn: parent
                text: root.animatedDewPointText()
                color: Appearance.colors.colOnPrimaryContainer
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                font.bold: true
            }
        }

        Text {
            text: qsTr("露点")
            color: Appearance.colors.colOnWeatherCardSurface
            font.family: "LXGW WenKai GB Screen"
            font.pixelSize: 18
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
