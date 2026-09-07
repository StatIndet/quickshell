import QtQuick
import QtQuick.Effects
import M3Shapes
import qs.Common
import qs.Components
import qs.Services

Item {
    id: root

    readonly property bool dataAvailable: WeatherPlugin.hasValidData
    readonly property string temperature: root.dataAvailable && isFinite(Number(
                                                                             WeatherPlugin.currentTemperatureC))
                                          ? Math.round(UiPreferences.weatherTemperature(
                                                           WeatherPlugin.currentTemperatureC)) + "°" : "--°"
    readonly property string weatherIcon: root.dataAvailable && String(WeatherPlugin.currentIconName
                                                                       || "").length > 0
                                          ? WeatherPlugin.currentIconName : "cloud"

    implicitWidth: backgroundShape.implicitWidth
    implicitHeight: backgroundShape.implicitHeight
    Accessible.name: qsTr("Weather,") + root.temperature + "，" + (root.dataAvailable
                                                                  ? WeatherPlugin.currentWeatherText : qsTr(
                                                                        "Weather unavailable"))

    MaterialShape {
        id: backgroundShape

        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        shape: MaterialShape.Pill
        color: Appearance.colors.colPrimaryContainer
        implicitSize: 200
        layer.enabled: true

        Text {
            text: root.temperature
            color: Appearance.colors.colPrimary
            renderType: Text.NativeRendering

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 20
                rightMargin: 16
            }

            font {
                family: Fonts.expressive
                pixelSize: 80
                weight: Font.Medium
            }
        }

        MaterialSymbol {
            text: root.weatherIcon
            iconSize: 80
            color: Appearance.colors.colOnPrimaryContainer

            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: 16
                bottomMargin: 20
            }
        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.colors.colShadow
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
    }
}
