import QtQuick
import QtQuick.Shapes
import M3Shapes
import qs.Common

WeatherInsightCard {
    id: root

    property string valueText: "--"
    property string descriptionText: ""
    property bool animationEnabled: false
    property bool animationActive: true

    readonly property var parsedValue: parseValueText(valueText)
    readonly property string displayValue: parsedValue.number
    readonly property string displayUnit: localizedUnit(parsedValue.unit)
    readonly property string footerText: normalizedDescription(descriptionText)
    readonly property color ink: Appearance.colors.colOnWeatherCardSurface
    readonly property color mutedInk: Appearance.colors.colOnWeatherCardSurfaceVariant
    readonly property real valueNumberSize: Math.round(width * 0.28)
    readonly property real valueUnitSize: Math.round(width * 0.12)
    readonly property real numericValue: displayValue === "--" ? NaN : Number(displayValue)

    icon: ""
    title: ""
    shapeId: MaterialShape.Square
    radius: 42
    shapeColor: Appearance.colors.colWeatherCardSurface

    function parseValueText(text) {
        const source = (text || "").trim()
        if (source.length === 0 || source === "--")
            return { number: "--", unit: "" }

        const match = source.match(/^([-+]?\d+(?:\.\d+)?)\s*([A-Za-z\u4e00-\u9fa5%°/]+)?$/)
        if (!match)
            return { number: source, unit: "" }

        return {
            number: match[1],
            unit: match[2] || ""
        }
    }

    function localizedUnit(unit) {
        if (unit === "mm")
            return qsTr("毫米")
        if (unit === "cm")
            return qsTr("厘米")
        return unit
    }

    function normalizedDescription(text) {
        let label = (text || "").trim()
        if (label.length === 0)
            return ""
        label = label.replace(qsTr("降雨总量"), qsTr("降水"))
        label = label.replace(qsTr("总降水"), qsTr("降水"))
        label = label.replace(qsTr("总量"), "")
        return label
    }

    function animatedValueText() {
        if (isNaN(amountAnimation.currentValue))
            return "--"

        const decimalIndex = root.displayValue.indexOf(".")
        const decimals = decimalIndex >= 0 ? root.displayValue.length - decimalIndex - 1 : 0
        return Number(amountAnimation.currentValue).toFixed(decimals)
    }

    WeatherAnimatedValue {
        id: amountAnimation
        targetValue: root.numericValue
        enabled: root.animationEnabled
        active: root.animationActive
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 28
        spacing: 8

        Item {
            width: 30
            height: 30

            Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: root.mutedInk

                    PathSvg {
                        path: "M6,14.03A1,1 0 0,1 7,15.03C7,15.58 6.55,16.03 6,16.03C3.24,16.03 1,13.79 1,11.03C1,8.27 3.24,6.03 6,6.03C7,3.68 9.3,2.03 12,2.03C15.43,2.03 18.24,4.69 18.5,8.06L19,8.03A4,4 0 0,1 23,12.03C23,14.23 21.21,16.03 19,16.03H18C17.45,16.03 17,15.58 17,15.03C17,14.47 17.45,14.03 18,14.03H19A2,2 0 0,0 21,12.03A2,2 0 0,0 19,10.03H17V9.03C17,6.27 14.76,4.03 12,4.03C9.5,4.03 7.45,5.84 7.06,8.21C6.73,8.09 6.37,8.03 6,8.03A3,3 0 0,0 3,11.03A3,3 0 0,0 6,14.03M12,14.15C12.18,14.39 12.37,14.66 12.56,14.94C13,15.56 14,17.03 14,18C14,19.11 13.1,20 12,20A2,2 0 0,1 10,18C10,17.03 11,15.56 11.44,14.94C11.63,14.66 11.82,14.4 12,14.15M12,11.03L11.5,11.59C11.5,11.59 10.65,12.55 9.79,13.81C8.93,15.06 8,16.56 8,18A4,4 0 0,0 12,22A4,4 0 0,0 16,18C16,16.56 15.07,15.06 14.21,13.81C13.35,12.55 12.5,11.59 12.5,11.59"
                    }
                }
            }
        }

        Text {
            text: qsTr("降水量")
            color: root.mutedInk
            font.pixelSize: 18
            font.bold: true
        }
    }

    Item {
        id: valueBlock
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 68
        height: Math.round(root.height * 0.40)

        Item {
            width: valueNumber.implicitWidth + (valueUnit.visible ? 6 + valueUnit.implicitWidth : 0)
            height: Math.max(valueNumber.implicitHeight, valueUnit.visible ? valueUnit.implicitHeight + 8 : 0)
            anchors.centerIn: parent

            Text {
                id: valueNumber
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: root.animatedValueText()
                color: root.ink
                font.pixelSize: root.valueNumberSize
                font.weight: Font.Light
                lineHeight: 0.9
            }

            Text {
                id: valueUnit
                anchors.left: valueNumber.right
                anchors.leftMargin: 6
                anchors.bottom: valueNumber.bottom
                anchors.bottomMargin: 4
                visible: root.displayUnit.length > 0
                text: root.displayUnit
                color: root.ink
                font.pixelSize: root.valueUnitSize
                font.weight: Font.Normal
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 36
        text: root.footerText
        color: root.ink
        font.pixelSize: 16
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
