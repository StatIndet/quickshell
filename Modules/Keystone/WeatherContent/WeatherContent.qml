import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Clavis.Weather 1.0
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    width: 960
    height: 570

    property bool active: false
    property real latitude: 0
    property real longitude: 0
    property string locationName: qsTr("天气")
    property string currentTemp: "--"
    property string currentIcon: "cloud"
    property string currentDesc: "--"
    property string feelsLike: "--"
    property string humidity: "--"
    property string windSpeed: "--"
    property string pressure: "--"
    property bool isHourly: true
    property var hourlyData: []
    property var dailyData: []

    readonly property bool hasWeather: WeatherPlugin.hasValidData

    Material.theme: Appearance.m3colors.darkmode ? Material.Dark : Material.Light
    Material.accent: Appearance.colors.colPrimary

    component MetricTile: Rectangle {
        property string iconName: ""
        property string label: ""
        property string value: "--"
        property color containerColor: Appearance.colors.colPrimary
        property color contentColor: Appearance.colors.colOnPrimary
        property color accentColor: Appearance.colors.colOnPrimary

        implicitHeight: 32
        radius: Appearance.rounding.small
        color: containerColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 4

            MaterialSymbol {
                text: parent.parent.iconName
                iconSize: 15
                color: parent.parent.accentColor
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: -2

                Text {
                    Layout.fillWidth: true
                    text: parent.parent.parent.label
                    color: Appearance.applyAlpha(
                        parent.parent.parent.contentColor,
                        0.72
                    )
                    font.family: Sizes.fontFamily
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: parent.parent.parent.value
                    color: parent.parent.parent.contentColor
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
        }
    }

    function validNumber(value) {
        return value !== undefined && value !== null && !isNaN(Number(value))
    }

    function hasCoordinates() {
        return root.hasWeather
            && root.validNumber(root.latitude)
            && root.validNumber(root.longitude)
    }

    function cssColor(colorValue, alphaMultiplier) {
        const alpha = alphaMultiplier === undefined
            ? colorValue.a
            : colorValue.a * alphaMultiplier
        return "rgba("
            + Math.round(colorValue.r * 255) + ","
            + Math.round(colorValue.g * 255) + ","
            + Math.round(colorValue.b * 255) + ","
            + Math.max(0, Math.min(1, alpha)).toFixed(3) + ")"
    }

    function updatedText() {
        if (WeatherPlugin.loading)
            return root.hasWeather ? qsTr("正在刷新") : qsTr("正在定位")
        if (WeatherPlugin.status === "stale")
            return qsTr("数据可能已过期")
        if (WeatherPlugin.status === "partial")
            return qsTr("部分数据已更新")
        if (WeatherPlugin.status === "error")
            return qsTr("更新失败")
        if (WeatherPlugin.lastUpdated) {
            const updated = new Date(WeatherPlugin.lastUpdated)
            if (!isNaN(updated.getTime()))
                return qsTr("更新于 %1").arg(Qt.formatDateTime(updated, "hh:mm"))
        }
        return qsTr("实时天气")
    }

    function weatherErrorText() {
        return WeatherPlugin.errorMessage || qsTr("天气数据不可用")
    }

    function hourlyTemperatureBound(findMaximum) {
        if (!root.hourlyData || root.hourlyData.length === 0)
            return 0

        let bound = Number(root.hourlyData[0].temp)
        for (let index = 1; index < root.hourlyData.length; ++index) {
            const value = Number(root.hourlyData[index].temp)
            bound = findMaximum ? Math.max(bound, value) : Math.min(bound, value)
        }
        return bound
    }

    function hourlyPointY(temperature, top, bottom) {
        let minimum = root.hourlyTemperatureBound(false)
        let maximum = root.hourlyTemperatureBound(true)
        if (Math.abs(maximum - minimum) < 0.1) {
            maximum += 1
            minimum -= 1
        }
        const normalized = (Number(temperature) - minimum) / (maximum - minimum)
        return bottom - normalized * (bottom - top)
    }

    function fetchData() {
        if (WeatherPlugin.loading)
            return

        WeatherPlugin.refresh()
        if (weatherMapLoader.status === Loader.Ready
            && weatherMapLoader.item) {
            weatherMapLoader.item.refreshMap()
        }
    }

    function syncWeatherData() {
        if (!WeatherPlugin.hasValidData) {
            root.locationName = WeatherPlugin.locationName || qsTr("天气")
            root.currentTemp = "--"
            root.currentIcon = "cloud"
            root.currentDesc = "--"
            root.feelsLike = "--"
            root.humidity = "--"
            root.windSpeed = "--"
            root.pressure = "--"
            root.hourlyData = []
            root.dailyData = []
            return
        }

        root.latitude = Number(WeatherPlugin.latitude)
        root.longitude = Number(WeatherPlugin.longitude)
        root.locationName = WeatherPlugin.locationName || qsTr("未知")
        root.currentTemp = Math.round(WeatherPlugin.currentTemperatureC) + "°"
        root.currentIcon = WeatherPlugin.currentIconName || "cloud"
        root.currentDesc = WeatherPlugin.currentWeatherText || qsTr("未知")
        root.feelsLike = Math.round(WeatherPlugin.currentFeelsLikeC) + "°C"
        root.humidity = Math.round(WeatherPlugin.currentRelativeHumidity) + "%"
        root.windSpeed = Math.round(WeatherPlugin.currentWindSpeedMs * 3.6) + " km/h"
        root.pressure = Math.round(WeatherPlugin.currentPressureHpa) + " hPa"

        const nextHourly = []
        const hourlyCount = Math.min(8, WeatherPlugin.hourlyForecast.count())
        for (let hourIndex = 0; hourIndex < hourlyCount; ++hourIndex) {
            const item = WeatherPlugin.hourlyForecast.get(hourIndex)
            const timeObject = new Date(Number(item.time || 0) * 1000)
            nextHourly.push({
                time: Qt.formatDateTime(timeObject, "hh:00"),
                temp: Math.round(Number(item.temperatureC || 0)),
                icon: item.iconName || "cloud",
                description: item.weatherText || qsTr("未知"),
                isDaylight: item.isDaylight === undefined ? true : item.isDaylight
            })
        }
        root.hourlyData = nextHourly

        const nextDaily = []
        const dailyCount = Math.min(5, WeatherPlugin.dailyForecast.count())
        for (let dayIndex = 0; dayIndex < dailyCount; ++dayIndex) {
            const item = WeatherPlugin.dailyForecast.get(dayIndex)
            const dateObject = item.date
                ? new Date(item.date + "T00:00:00")
                : new Date(Number(item.time || 0) * 1000)
            const dayPart = item.day || ({})
            nextDaily.push({
                day: dayIndex === 0 ? qsTr("今天") : Qt.formatDate(dateObject, "ddd"),
                date: Qt.formatDate(dateObject, "MMM d"),
                icon: dayPart.iconName || item.iconName || "cloud",
                description: dayPart.weatherText || item.weatherText || qsTr("未知"),
                maxTemp: Math.round(
                    Number(item.temperatureMaxC || dayPart.temperatureC || 0)
                ) + "°",
                minTemp: Math.round(Number(item.temperatureMinC || 0)) + "°"
            })
        }
        root.dailyData = nextDaily

    }

    Component.onCompleted: {
        root.syncWeatherData()
        if (!WeatherPlugin.hasValidData && !WeatherPlugin.loading)
            WeatherPlugin.refresh()
    }

    Connections {
        target: WeatherPlugin

        function onDataChanged() {
            root.syncWeatherData()
        }
    }

    Timer {
        interval: 1800000
        running: root.active
        repeat: true
        onTriggered: {
            if (!WeatherPlugin.loading)
                WeatherPlugin.refresh()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        // Left Column (Master)
        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            spacing: 16

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.hasWeather ? 0 : 1

                // Normal Weather Content
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: 24

                        WeatherCurrent {
                            Layout.fillWidth: true
                            onRefreshRequested: root.fetchData()
                        }
                        
                        WeatherFiveDayForecast { Layout.fillWidth: true }

                        WeatherAQIIndicator { Layout.fillWidth: true }
                        WeatherSunriseSunset { Layout.fillWidth: true }
                    }
                }

                // Error / Loading State
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        BusyIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            running: WeatherPlugin.loading
                            visible: running
                            Material.accent: Appearance.colors.colPrimary
                        }

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "cloud_off"
                            iconSize: 38
                            color: Appearance.colors.colError
                            visible: !WeatherPlugin.loading
                        }

                        Text {
                            Layout.fillWidth: true
                            text: WeatherPlugin.loading
                                ? qsTr("正在加载天气")
                                : qsTr("天气不可用")
                            color: Appearance.colors.colOnSurface
                            font.family: Sizes.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            text: WeatherPlugin.loading
                                ? qsTr("正在查找本地天气预报…")
                                : root.weatherErrorText()
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Right Column (Stack 1, 2, 3)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Map Area (Stack 1)
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 500
                Layout.preferredWidth: 500
                Layout.minimumHeight: 292
                Layout.preferredHeight: 292
                radius: Appearance.rounding.large
                color: Appearance.colors.colSurfaceContainerHigh
                clip: true

                Loader {
                    id: weatherMapLoader
                    anchors.fill: parent
                    active: root.active
                    asynchronous: true
                    source: active ? Qt.resolvedUrl("WeatherMapCard.qml") : ""
                }

                Binding {
                    target: weatherMapLoader.item
                    property: "latitude"
                    value: root.latitude
                    when: weatherMapLoader.status === Loader.Ready
                }

                Binding {
                    target: weatherMapLoader.item
                    property: "longitude"
                    value: root.longitude
                    when: weatherMapLoader.status === Loader.Ready
                }

                Binding {
                    target: weatherMapLoader.item
                    property: "locationAvailable"
                    value: root.hasCoordinates()
                    when: weatherMapLoader.status === Loader.Ready
                }

                Binding {
                    target: weatherMapLoader.item
                    property: "active"
                    value: root.active && root.visible
                    when: weatherMapLoader.status === Loader.Ready
                }
            }

            Item { Layout.fillHeight: true }
            
            // Parameters (Stack 2)
            WeatherParameters {
                Layout.fillWidth: true
                visible: root.hasWeather
            }
        }
    }
}
