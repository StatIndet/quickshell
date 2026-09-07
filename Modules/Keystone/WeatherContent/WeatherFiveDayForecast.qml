import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components

Item {
    id: root

    property var dailyData: []

    function syncForecast() {
        if (!WeatherPlugin.hasValidData) {
            root.dailyData = [];
            return;
        }
        const nextDaily = [];
        const count = Math.min(5, WeatherPlugin.dailyForecast.count());
        let globalMin = 1000;
        let globalMax = -1000;
        for (let i = 0; i < count; ++i) {
            const item = WeatherPlugin.dailyForecast.get(i);
            const dayPart = item.day || {};
            const minTemp = Number(item.temperatureMinC || 0);
            const maxTemp = Number(item.temperatureMaxC || dayPart.temperatureC || 0);
            if (minTemp < globalMin)
                globalMin = minTemp;

            if (maxTemp > globalMax)
                globalMax = maxTemp;

            const dateObject = item.date ? new Date(item.date + "T00:00:00") : new Date(Number(item.time
                                                                                               || 0) * 1000);
            nextDaily.push({
                               "dayIndex": dateObject.getDay(),
                               "icon": dayPart.iconName || item.iconName || "cloud",
                               "minTemp": Math.round(UiPreferences.weatherTemperature(minTemp)),
                               "maxTemp": Math.round(UiPreferences.weatherTemperature(maxTemp)),
                               "rawMin": minTemp,
                               "rawMax": maxTemp
                           });
        }
        // Calculate offsets
        if (globalMax - globalMin < 1) {
            globalMax += 1;
            globalMin -= 1;
        }
        const range = globalMax - globalMin;
        for (let i = 0; i < nextDaily.length; ++i) {
            nextDaily[i].startRatio = (nextDaily[i].rawMin - globalMin) / range;
            nextDaily[i].widthRatio = (nextDaily[i].rawMax - nextDaily[i].rawMin) / range;
        }
        root.dailyData = nextDaily;
    }

    implicitHeight: layout.implicitHeight
    implicitWidth: 300
    Component.onCompleted: syncForecast()

    Connections {
        function onDataChanged() {
            syncForecast();
        }

        target: WeatherPlugin
    }

    Connections {
        function onWeatherTemperatureUnitChanged() {
            root.syncForecast();
        }

        target: UiPreferences
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 20

        Repeater {
            model: root.dailyData

            delegate: RowLayout {
                property var week: [qsTr("Sun"), qsTr("Mon"), qsTr("Tue"), qsTr("Wed"), qsTr("Thu"), qsTr(
                        "Fri"), qsTr("Sat")]

                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.preferredWidth: 40
                    text: index === 0 ? qsTr("Today") : week[modelData.dayIndex]
                    color: index === 0 ? Appearance.colors.colOnSurface :
                                         Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 16
                    font.weight: index === 0 ? Font.Medium : Font.Normal
                }

                MaterialSymbol {
                    text: modelData.icon
                    iconSize: 26
                    fill: 1
                    color: Appearance.colors.colPrimary
                }

                Text {
                    Layout.preferredWidth: 32
                    text: modelData.minTemp + "°"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.numeric
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignRight
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: Math.min(width, height) / 2
                        color: Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.22)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * modelData.startRatio
                        width: Math.max(parent.height, parent.width * modelData.widthRatio)
                        height: 8
                        radius: Math.min(width, height) / 2

                        gradient: Gradient {
                            orientation: Gradient.Horizontal

                            GradientStop {
                                position: 0
                                color: Appearance.applyAlpha(Appearance.colors.colPrimary, 0.55)
                            }

                            GradientStop {
                                position: 1
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }

                Text {
                    Layout.preferredWidth: 32
                    text: modelData.maxTemp + "°"
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.numeric
                    font.pixelSize: 16
                }
            }
        }
    }
}
