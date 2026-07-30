import QtQuick
import QtQuick.Shapes
import M3Shapes
import qs.Common

Item {
    id: root

    property real visibilityMeters: NaN
    property bool animationEnabled: false
    property bool animationActive: true

    WeatherAnimatedValue {
        id: visibilityAnimation
        targetValue: root.visibilityMeters
        enabled: root.animationEnabled
        active: root.animationActive
    }

    function eyeIconPath() {
        return "M12,9A3,3 0 0,1 15,12A3,3 0 0,1 12,15A3,3 0 0,1 9,12A3,3 0 0,1 12,9M12,4.5C17,4.5 21.27,7.61 23,12C21.27,16.39 17,19.5 12,19.5C7,19.5 2.73,16.39 1,12C2.73,7.61 7,4.5 12,4.5M3.18,12C4.83,15.36 8.24,17.5 12,17.5C15.76,17.5 19.17,15.36 20.82,12C19.17,8.64 15.76,6.5 12,6.5C8.24,6.5 4.83,8.64 3.18,12Z"
    }

    function valueNumberText() {
        const value = visibilityAnimation.currentValue
        if (isNaN(value)) return "--"
        if (root.visibilityMeters >= 1000) {
            const km = value / 1000
            return km < 100 ? km.toFixed(1) : Math.round(km).toString()
        }
        return Math.round(value).toString()
    }

    function valueUnitText() {
        if (isNaN(root.visibilityMeters)) return ""
        return root.visibilityMeters >= 1000 ? qsTr("公里") : qsTr("米")
    }

    function descriptionText() {
        if (isNaN(root.visibilityMeters)) return "--"
        if (root.visibilityMeters < 1000) return qsTr("极差")
        if (root.visibilityMeters < 4000) return qsTr("差")
        if (root.visibilityMeters < 10000) return qsTr("中")
        if (root.visibilityMeters < 20000) return qsTr("良")
        if (root.visibilityMeters < 40000) return qsTr("清")
        return qsTr("优")
    }

    MaterialShape {
        width: root.width * 0.93
        height: width
        anchors.centerIn: parent
        shape: MaterialShape.Cookie12Sided
        color: Appearance.applyAlpha(
            Appearance.colors.colWeatherCardSurface,
            0.38
        )
        rotation: -8
    }

    MaterialShape {
        width: root.width * 0.89
        height: width
        anchors.centerIn: parent
        shape: MaterialShape.Cookie12Sided
        color: Appearance.applyAlpha(
            Appearance.colors.colWeatherCardSurface,
            0.64
        )
    }

    MaterialShape {
        width: root.width * 0.85
        height: width
        anchors.centerIn: parent
        shape: MaterialShape.Cookie12Sided
        color: Appearance.colors.colWeatherCardSurface
        rotation: 8
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.18
        spacing: 6

        Item {
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter

            Shape {
                width: 24
                height: 24
                anchors.centerIn: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: Appearance.colors.colOnWeatherCardSurfaceVariant

                    PathSvg {
                        path: root.eyeIconPath()
                    }
                }
            }
        }

        Text {
            text: qsTr("能见度")
            color: Appearance.colors.colOnWeatherCardSurfaceVariant
            font.family: "LXGW WenKai GB Screen"
            font.pixelSize: 19
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        spacing: 4

        Text {
            text: root.valueNumberText()
            color: Appearance.colors.colOnWeatherCardSurface
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(root.width * 0.24)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.valueUnitText()
            color: Appearance.colors.colOnWeatherCardSurface
            font.family: "LXGW WenKai GB Screen"
            font.pixelSize: Math.round(root.width * 0.12)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 6
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: root.height * 0.12
        width: parent.width * 0.36
        text: root.descriptionText()
        color: Appearance.colors.colOnWeatherCardSurface
        font.family: "LXGW WenKai GB Screen"
        font.pixelSize: 22
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
