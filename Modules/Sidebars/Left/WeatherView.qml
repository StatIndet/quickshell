import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Widgets.common
import Clavis.Weather 1.0

Item {
    id: root


    property int contentMargin: 16
    property int headerHeight: 62
    property bool lightHeaderPalette: currentIsNight()
    property color headerInk: lightHeaderPalette ? Qt.rgba(0.96, 0.98, 1.0, 0.94) : Qt.rgba(0.09, 0.14, 0.20, 0.88)
    property color headerInkMuted: lightHeaderPalette ? Qt.rgba(0.87, 0.91, 0.98, 0.76) : Qt.rgba(0.20, 0.28, 0.38, 0.62)
    property color headerErrorInk: lightHeaderPalette ? Qt.rgba(1.0, 0.79, 0.82, 0.96) : Qt.rgba(0.62, 0.14, 0.18, 0.88)
    property real currentEpoch: Math.floor(Date.now() / 1000)

    function validNumber(value) {
        return value !== undefined && value !== null && !isNaN(value)
    }

    function fmtTemp(value) {
        return validNumber(value) ? Math.round(value) + "°" : "--"
    }

    function fmtTempPlain(value) {
        return validNumber(value) ? Math.round(value).toString() : "--"
    }

    function fmtTime(epoch) {
        if (!epoch) return "--"
        return Qt.formatDateTime(new Date(epoch * 1000), "hh:mm")
    }

    function fmtSpeed(ms) {
        return validNumber(ms) ? ms.toFixed(1) + " m/s" : "--"
    }

    function fmtPercent(value) {
        return validNumber(value) ? Math.round(value) + "%" : "--"
    }

    function fmtDistance(meters) {
        return validNumber(meters) ? (meters / 1000).toFixed(1) + " km" : "--"
    }

    function currentHour() {
        return new Date(root.currentEpoch * 1000).getHours()
    }

    function updatedText() {
        if (WeatherPlugin.loading) return "正在刷新"
        if (WeatherPlugin.status === "fresh" || WeatherPlugin.status === "partial") {
            const date = new Date(WeatherPlugin.lastUpdated)
            return "更新于 " + Qt.formatDateTime(date, "hh:mm")
        }
        if (WeatherPlugin.status === "stale") return "数据较旧"
        if (WeatherPlugin.status === "error") return "更新失败"
        return "待更新"
    }

    function dayLabel(index, epoch) {
        if (index === 0) return "Today"
        if (index === 1) return "Tomorrow"
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "ddd") : "--"
    }

    function uvLevel(value) {
        if (!validNumber(value)) return "--"
        if (value < 3) return "低"
        if (value < 6) return "中"
        if (value < 8) return "高"
        if (value < 11) return "很高"
        return "极高"
    }

    function uvIndexBucket(value) {
        if (!validNumber(value)) return -1
        if (value < 3) return 0
        if (value < 6) return 1
        if (value < 8) return 2
        if (value < 11) return 3
        return 4
    }

    function windAccent(ms) {
        if (!validNumber(ms)) return "#4d8d7b"
        if (ms < 4) return "#72d572"
        if (ms < 6) return "#ffca28"
        if (ms < 8) return "#ffa726"
        if (ms < 10) return "#e52f35"
        if (ms < 12) return "#99004c"
        return "#7e0023"
    }

    function directionLabel(degree) {
        if (!validNumber(degree)) return "--"
        const normalized = ((degree % 360) + 360) % 360
        if (normalized < 22.5 || normalized >= 337.5) return "N"
        if (normalized < 67.5) return "NE"
        if (normalized < 112.5) return "E"
        if (normalized < 157.5) return "SE"
        if (normalized < 202.5) return "S"
        if (normalized < 247.5) return "SW"
        if (normalized < 292.5) return "W"
        return "NW"
    }

    function activeHalfDay() {
        const day = today()
        const hour = currentHour()
        if (hour < 5) return day.night || ({})
        if (hour < 17) return day.day || ({})
        return day.night || ({})
    }

    function precipitationValueText() {
        const half = activeHalfDay()
        const snow = validNumber(half.snowCm) ? half.snowCm : 0
        const rain = validNumber(half.rainMm) ? half.rainMm : 0
        const total = validNumber(half.precipitationMm) ? half.precipitationMm : NaN
        if (snow > 0 && rain <= 0) return snow.toFixed(1) + " cm"
        return validNumber(total) ? total.toFixed(1) + " mm" : "--"
    }

    function precipitationDescriptionText() {
        const half = activeHalfDay()
        const snow = validNumber(half.snowCm) ? half.snowCm : 0
        const rain = validNumber(half.rainMm) ? half.rainMm : 0
        const hour = currentHour()
        const isDay = hour >= 5 && hour < 17
        if (snow > 0 && rain <= 0) return isDay ? "白天降雪总量" : "夜间降雪总量"
        if (rain > 0 && snow <= 0) return isDay ? "白天降雨总量" : "夜间降雨总量"
        if (snow > 0 && rain > 0) return isDay ? "白天总降水" : "夜间总降水"
        return isDay ? "白天总降水" : "夜间总降水"
    }

    function humidityWaveAccent() {
        return "#625985"
    }

    function visibilityDescription(meters) {
        if (!validNumber(meters)) return "--"
        const km = meters / 1000
        if (km >= 16) return "Crystal clear"
        if (km >= 10) return "Clear"
        if (km >= 6) return "Good"
        if (km >= 3) return "Hazy"
        if (km >= 1) return "Low"
        return "Dense"
    }

    function aqiThresholds() {
        return [0, 20, 50, 100, 150, 250]
    }

    function pollutantIndex(value, thresholds) {
        if (!validNumber(value)) return NaN
        let level = -1
        for (let i = 0; i < thresholds.length; ++i) {
            if (value >= thresholds[i]) level = i
        }
        if (level < 0) return NaN
        const aqi = aqiThresholds()
        if (level < thresholds.length - 1) {
            const bpLo = thresholds[level]
            const bpHi = thresholds[level + 1]
            const inLo = aqi[level]
            const inHi = aqi[level + 1]
            return Math.round(((inHi - inLo) / (bpHi - bpLo)) * (value - bpLo) + inLo)
        }
        return Math.round((value * aqi[aqi.length - 1]) / thresholds[thresholds.length - 1])
    }

    function aqiLevelIndex(value) {
        if (!validNumber(value)) return -1
        const thresholds = aqiThresholds()
        let level = 0
        for (let i = 0; i < thresholds.length; ++i) {
            if (value >= thresholds[i]) level = i
        }
        return Math.min(level, 5)
    }

    function aqiPalette(level) {
        const colors = ["#00e59b", "#ffc302", "#ff712b", "#f62a55", "#c72eaa", "#9930ff"]
        return colors[Math.max(0, Math.min(colors.length - 1, level))]
    }

    function aqiLevelName(level) {
        const names = ["优", "良", "差", "不健康", "很不健康", "危险"]
        if (level < 0 || level >= names.length) return "--"
        return names[level]
    }

    function aqiSummary() {
        const air = WeatherPlugin.currentAirQuality || ({})
        const values = [
            pollutantIndex(air.ozone, [0, 50, 100, 160, 240, 480]),
            pollutantIndex(air.nitrogenDioxide, [0, 10, 25, 200, 400, 1000]),
            pollutantIndex(air.pm10, [0, 15, 45, 80, 160, 400]),
            pollutantIndex(air.pm25, [0, 5, 15, 30, 60, 150])
        ].filter(validNumber)
        if (values.length === 0) return ({ value: NaN, level: "--", color: "#00e59b" })
        const value = Math.max.apply(Math, values)
        const level = aqiLevelIndex(value)
        return ({ value: value, level: aqiLevelName(level), color: aqiPalette(level) })
    }

    function pressureValueText(value) {
        return validNumber(value) ? Number(value).toLocaleString(Qt.locale(), "f", 1) : "--"
    }

    function today() {
        return WeatherPlugin.dailyForecast.count() > 0 ? WeatherPlugin.dailyForecast.get(0) : ({})
    }

    function currentIsNight() {
        const day = today()
        const sunrise = day.sunrise || 0
        const sunset = day.sunset || 0
        if (sunrise > 0 && sunset > 0) {
            const now = Math.floor(root.currentEpoch)
            return now < sunrise || now >= sunset
        }

        const current = WeatherPlugin.current()
        if (current && current.isDaylight !== undefined) return !current.isDaylight

        const nextHour = WeatherPlugin.hourlyForecast.count() > 0 ? WeatherPlugin.hourlyForecast.get(0) : ({})
        if (nextHour && nextHour.isDaylight !== undefined) return !nextHour.isDaylight

        const name = (WeatherPlugin.currentIconName || "").toLowerCase()
        if (name.indexOf("night") >= 0 || name.indexOf("_night") >= 0) return true
        if (name.indexOf("day") >= 0 || name.indexOf("_day") >= 0) return false

        return false
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: root.currentEpoch = Math.floor(Date.now() / 1000)
    }

    Rectangle {
        id: weatherPanel
        anchors.fill: parent
        radius: 30
        clip: true
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Appearance.colors.colLayer0Border.r, Appearance.colors.colLayer0Border.g, Appearance.colors.colLayer0Border.b, 0.34)
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: weatherPanel.width
                height: weatherPanel.height
                radius: weatherPanel.radius
            }
        }

        WeatherBackground {
            anchors.fill: parent
            weatherCode: WeatherPlugin.currentWeatherCode
            iconName: WeatherPlugin.currentIconName
            windSpeedMs: WeatherPlugin.currentWindSpeedMs
            windGustsMs: WeatherPlugin.currentWindGustsMs
            night: root.currentIsNight()
            rainBounceY: flick.y + dailyForecastCard.y - flick.contentY
            scrollProgress: Math.max(0, Math.min(1, flick.contentY / 340))
            animate: root.visible
        }

        Rectangle {
            id: fixedHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.headerHeight + root.contentMargin
            color: "transparent"
            border.width: 0

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: root.contentMargin
                anchors.rightMargin: root.contentMargin
                anchors.topMargin: root.contentMargin
                height: root.headerHeight
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        Text {
                            text: "location_on"
                            color: root.headerInkMuted
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 19
                            Layout.preferredWidth: 20
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: WeatherPlugin.locationName || "Weather"
                            color: root.headerInk
                            font.family: "LXGW WenKai GB Screen"
                            font.pixelSize: 19
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ToolButton {
                        id: editButton
                        implicitWidth: 38
                        implicitHeight: 38
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: locationPicker.open()

                        background: Rectangle {
                            radius: width / 2
                            color: editButton.down
                                   ? Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.18)
                                   : editButton.hovered
                                     ? Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.10)
                                     : "transparent"
                        }

                        contentItem: Text {
                            text: "edit"
                            color: root.headerInk
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    ToolButton {
                        id: refreshButton
                        implicitWidth: 38
                        implicitHeight: 38
                        Layout.alignment: Qt.AlignVCenter
                        enabled: !WeatherPlugin.loading
                        opacity: enabled ? 1 : 0.45
                        onClicked: WeatherPlugin.refresh()

                        background: Rectangle {
                            radius: width / 2
                            color: refreshButton.down
                                   ? Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.18)
                                   : refreshButton.hovered
                                     ? Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.10)
                                     : "transparent"
                        }

                        contentItem: Text {
                            text: "refresh"
                            color: root.headerInk
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        text: "schedule"
                        color: WeatherPlugin.status === "stale" || WeatherPlugin.status === "error"
                               ? root.headerErrorInk
                               : root.headerInkMuted
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 19
                        Layout.preferredWidth: 20
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        text: updatedText()
                        color: WeatherPlugin.status === "stale" || WeatherPlugin.status === "error"
                               ? root.headerErrorInk
                               : root.headerInk
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Flickable {
            id: flick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: fixedHeader.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.contentMargin
            anchors.rightMargin: root.contentMargin
            anchors.bottomMargin: root.contentMargin
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 4

            Column {
                id: contentColumn
                width: flick.width
                spacing: 14

                Item {
                    width: parent.width
                    height: Math.max(220, flick.height - 452 - 286 - contentColumn.spacing * 2)

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            width: parent.width
                            text: WeatherPlugin.currentWeatherText || "Unknown"
                            color: Appearance.colors.colOnLayer0
                            font.family: "LXGW WenKai GB Screen"
                            font.pixelSize: 26
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Item {
                            id: currentVisual
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tempText.implicitWidth + weatherHeroIcon.width - 18
                            height: Math.max(tempText.implicitHeight, weatherHeroIcon.height + 12)

                            Text {
                                id: tempText
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: fmtTempPlain(WeatherPlugin.currentTemperatureC)
                                color: Appearance.colors.colOnLayer0
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 132
                                font.bold: true
                                font.letterSpacing: 0
                            }

                            MeteoIcon {
                                id: weatherHeroIcon
                                width: 108
                                height: 108
                                anchors.right: parent.right
                                anchors.top: parent.top
                                weatherCode: WeatherPlugin.currentWeatherCode
                                iconName: WeatherPlugin.currentIconName
                                night: root.currentIsNight()
                            }
                        }

                        Text {
                            width: parent.width
                            text: "体感温度: " + fmtTemp(WeatherPlugin.currentFeelsLikeC)
                            color: Appearance.colors.colOnLayer0
                            font.family: "LXGW WenKai GB Screen"
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: "最高 " + fmtTemp(today().temperatureMaxC)
                                  + " · 最低 " + fmtTemp(today().temperatureMinC)
                            color: Appearance.colors.colOnLayer0
                            font.family: "LXGW WenKai GB Screen"
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                DailyForecastTrendCard {
                    id: dailyForecastCard
                    width: parent.width
                    height: 452
                    sourceModel: WeatherPlugin.dailyTrendForecast
                }

                HourlyForecastTrendCard {
                    width: parent.width
                    height: 286
                    sourceModel: WeatherPlugin.hourlyForecast
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    WeatherPrecipitationCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        valueText: precipitationValueText()
                        descriptionText: precipitationDescriptionText()
                    }

                    WeatherWindCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        directionDegrees: WeatherPlugin.currentWindDirection
                        valueText: fmtSpeed(WeatherPlugin.currentWindSpeedMs)
                        detailText: "阵风 " + fmtSpeed(WeatherPlugin.currentWindGustsMs) + " · " + directionLabel(WeatherPlugin.currentWindDirection)
                        accent: windAccent(WeatherPlugin.currentWindSpeedMs)
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    WeatherAqiCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        aqiValue: aqiSummary().value
                        levelText: aqiSummary().level
                        accent: aqiSummary().color
                    }

                    WeatherPollenCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        pollenMap: today().pollen || ({})
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    WeatherHumidityCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        humidityValue: WeatherPlugin.currentRelativeHumidity
                        humidityText: fmtPercent(WeatherPlugin.currentRelativeHumidity)
                        dewPointText: fmtTemp(WeatherPlugin.currentDewPointC)
                        accent: humidityWaveAccent()
                    }

                    WeatherUvCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        value: WeatherPlugin.currentUvIndex
                        level: uvLevel(WeatherPlugin.currentUvIndex)
                        activeIndex: uvIndexBucket(WeatherPlugin.currentUvIndex)
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    WeatherVisibilityCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        visibilityMeters: WeatherPlugin.currentVisibilityM
                    }

                    WeatherPressureCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        pressureValue: WeatherPlugin.currentPressureHpa
                        valueText: pressureValueText(WeatherPlugin.currentPressureHpa)
                        unitText: "hPa"
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    WeatherAstroCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        moon: false
                        riseText: fmtTime(today().sunrise)
                        setText: fmtTime(today().sunset)
                        riseEpoch: today().sunrise || 0
                        setEpoch: today().sunset || 0
                        currentEpoch: root.currentEpoch
                    }

                    WeatherAstroCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        moon: true
                        riseText: fmtTime(today().moonrise)
                        setText: fmtTime(today().moonset)
                        riseEpoch: today().moonrise || 0
                        setEpoch: today().moonset || 0
                        currentEpoch: root.currentEpoch
                        phaseAngle: today().moonPhaseAngle || 0
                    }
                }

                Item {
                    width: 1
                    height: 8
                }
            }
        }
    }

    component SectionCard: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        default property alias content: contentLayer.data

        radius: 26
        color: Qt.rgba(Appearance.colors.colLayer2.r, Appearance.colors.colLayer2.g, Appearance.colors.colLayer2.b, 0.78)
        border.width: 1
        border.color: Qt.rgba(Appearance.colors.colLayer0Border.r, Appearance.colors.colLayer0Border.g, Appearance.colors.colLayer0Border.b, 0.55)

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.topMargin: 16
            spacing: 8

            Text {
                text: card.icon
                color: Appearance.colors.colOnLayer0
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: card.title
                color: Appearance.colors.colOnLayer0
                font.family: "LXGW WenKai GB Screen"
                font.bold: true
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            id: contentLayer
            anchors.fill: parent
            anchors.margins: 14
        }
    }

    // 地点搜索弹窗
    Popup {
        id: locationPicker
        anchors.centerIn: Overlay.overlay
        width: 320
        height: 400
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string searchText: ""
        property var searchResults: []
        property bool searching: false

        onOpened: {
            searchField.text = ""
            searchText = ""
            searchResults = []
            searchField.forceFocus()
        }

        function searchLocation(query) {
            if (!query || query.trim().length === 0) {
                searchResults = []
                return
            }
            searching = true
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    searching = false
                    if (xhr.status === 200) {
                        try {
                            var data = JSON.parse(xhr.responseText)
                            searchResults = data.results || []
                        } catch (e) {
                            searchResults = []
                        }
                    } else {
                        searchResults = []
                    }
                }
            }
            xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(query) + "&count=8&language=zh")
            xhr.send()
        }

        function selectLocation(item) {
            var name = item.name
            if (item.admin1) name += ", " + item.admin1
            if (item.country) name += ", " + item.country
            WeatherPlugin.setManualLocation(item.latitude, item.longitude, name)
            locationPicker.close()
        }

        background: Rectangle {
            radius: 12
            color: Appearance.colors.colLayer0
            border.color: Appearance.colors.colLayer0Border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 12

            Text {
                text: "设置天气地区"
                font.family: "LXGW WenKai GB Screen"
                font.pixelSize: 16
                font.bold: true
                color: Appearance.colors.colOnLayer0
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 8
                    color: Appearance.colors.colLayer1
                    border.color: searchField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                    border.width: searchField.activeFocus ? 2 : 1


                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 10
                        font.family: "LXGW WenKai GB Screen"
                        font.pixelSize: 14
                        color: Appearance.colors.colOnLayer0
                        clip: true
                        selectByMouse: true
                        selectionColor: Appearance.colors.colPrimary

                        property string placeholderText: "输入城市名称..."

                        function forceFocus() {
                            forceActiveFocus()
                        }

                        onTextChanged: {
                            locationPicker.searchText = text
                            searchDebounce.restart()
                        }

                        Keys.onReturnPressed: locationPicker.searchLocation(text)
                        Keys.onEnterPressed: locationPicker.searchLocation(text)

                        Text {
                            anchors.fill: parent
                            anchors.verticalCenter: parent.verticalCenter
                            text: searchField.placeholderText
                            font: searchField.font
                            color: Appearance.colors.colOnLayer1
                            visible: !searchField.text && !searchField.activeFocus

                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                ToolButton {
                    implicitWidth: 40
                    implicitHeight: 40
                    enabled: locationPicker.searchText.length > 0 && !locationPicker.searching
                    onClicked: locationPicker.searchLocation(locationPicker.searchText)

                    background: Rectangle {
                        radius: 8
                        color: parent.down ? Appearance.colors.colPrimary
                             : parent.hovered ? Appearance.colors.colLayer1
                             : "transparent"
                    }

                    contentItem: Text {
                        text: "search"
                        color: Appearance.colors.colOnLayer0
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 22
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // 搜索状态
            Text {
                text: locationPicker.searching ? "搜索中..." : (locationPicker.searchResults.length === 0 && locationPicker.searchText.length > 0 ? "未找到结果" : "")
                font.family: "LXGW WenKai GB Screen"
                font.pixelSize: 12
                color: Appearance.colors.colOnLayer1
                Layout.fillWidth: true
                visible: text.length > 0
            }

            // 当前位置
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 8
                color: Appearance.colors.colLayer1
                visible: WeatherPlugin.hasManualLocation

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: "当前: " + WeatherPlugin.locationName
                        font.family: "LXGW WenKai GB Screen"
                        font.pixelSize: 12
                        color: Appearance.colors.colOnLayer1
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "恢复默认"
                        font.family: "LXGW WenKai GB Screen"
                        font.pixelSize: 12
                        color: Appearance.colors.colPrimary

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                WeatherPlugin.clearManualLocation()
                                locationPicker.close()
                            }
                        }
                    }
                }
            }

            // 搜索结果列表
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: locationPicker.searchResults

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 48
                    radius: 8
                    color: resultMouseArea.containsMouse ? Appearance.colors.colLayer1 : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: "location_on"
                            color: Appearance.colors.colPrimary
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.name || ""
                                font.family: "LXGW WenKai GB Screen"
                                font.pixelSize: 14
                                color: Appearance.colors.colOnLayer0
                            }

                            Text {
                                text: [modelData.admin1, modelData.country].filter(function(v) { return v }).join(", ")
                                font.family: "LXGW WenKai GB Screen"
                                font.pixelSize: 11
                                color: Appearance.colors.colOnLayer1
                                visible: text.length > 0
                            }
                        }
                    }

                    MouseArea {
                        id: resultMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: locationPicker.selectLocation(modelData)
                    }
                }
            }
        }

        Timer {
            id: searchDebounce
            interval: 500
            running: false
            repeat: false
            onTriggered: locationPicker.searchLocation(locationPicker.searchText)
        }
    }

}
