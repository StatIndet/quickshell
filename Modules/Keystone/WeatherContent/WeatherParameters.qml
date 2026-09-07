import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components

Item {
    id: root

    property string uv: "--"
    property string feelsLike: "--"
    property string humidity: "--"
    property string wind: "--"
    property string pressure: "--"
    property string visibility: "--"

    function syncParams() {
        if (!WeatherPlugin.hasValidData) {
            root.uv = "--";
            root.feelsLike = "--";
            root.humidity = "--";
            root.wind = "--";
            root.pressure = "--";
            root.visibility = "--";
            return;
        }
        root.uv = Math.round(WeatherPlugin.currentUvIndex || 0).toString();
        root.feelsLike = Math.round(UiPreferences.weatherTemperature(WeatherPlugin.currentFeelsLikeC || 0))
                + UiPreferences.weatherTemperatureSymbol();
        root.humidity = Math.round(WeatherPlugin.currentRelativeHumidity || 0) + "%";
        root.wind = Math.round((WeatherPlugin.currentWindSpeedMs || 0) * 3.6) + " km/h";
        root.pressure = Math.round(WeatherPlugin.currentPressureHpa || 0) + " hPa";
        root.visibility = Math.round((WeatherPlugin.currentVisibilityM || 0) / 1000) + " km";
    }

    implicitHeight: grid.implicitHeight
    implicitWidth: 300
    Component.onCompleted: syncParams()

    Connections {
        function onDataChanged() {
            syncParams();
        }

        target: WeatherPlugin
    }

    Connections {
        function onWeatherTemperatureUnitChanged() {
            root.syncData();
        }

        target: UiPreferences
    }

    GridLayout {
        id: grid

        anchors.fill: parent
        columns: 3
        rowSpacing: 40
        columnSpacing: 24

        Repeater {
            model: [
                {
                    "icon": "sunny",
                    "label": qsTr("UV index"),
                    "value": root.uv
                },
                {
                    "icon": "thermostat",
                    "label": qsTr("Feels like"),
                    "value": root.feelsLike
                },
                {
                    "icon": "water_drop",
                    "label": qsTr("Humidity"),
                    "value": root.humidity
                },
                {
                    "icon": "air",
                    "label": qsTr("Wind speed"),
                    "value": root.wind
                },
                {
                    "icon": "compress",
                    "label": qsTr("Pressure"),
                    "value": root.pressure
                },
                {
                    "icon": "visibility",
                    "label": qsTr("Visibility"),
                    "value": root.visibility
                }
            ]

            delegate: ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MaterialSymbol {
                        text: modelData.icon
                        iconSize: 26
                        color: Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.7)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: 16
                        elide: Text.ElideRight
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.value
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.numeric
                    font.pixelSize: 24
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }
        }
    }
}
