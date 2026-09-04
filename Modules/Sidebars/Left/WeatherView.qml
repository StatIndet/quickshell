import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Widgets.common
import qs.Widgets.weather
import qs.Services

Item {
    id: root

    property bool foreground: false
    property bool presentationActive: false
    property var weatherSourceOverride: null
    readonly property var weatherSource: weatherSourceOverride || WeatherPlugin
    readonly property bool weatherAnimationActive: weatherBackground.animationTimerRunning
    readonly property int weatherTargetFps: weatherBackground.targetFps
    readonly property int weatherFrameInterval: weatherBackground.sceneFrameInterval
    readonly property string weatherSceneType: weatherBackground.weatherType
    readonly property int weatherSimulationFrameCount: weatherBackground.simulationFrameCount
    readonly property int weatherPaintCount: weatherBackground.paintCount
    readonly property real effectiveDpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    property int contentMargin: 16
    property int headerHeight: 62
    property bool lightHeaderPalette: currentIsNight()
    property color headerInk: lightHeaderPalette ? Qt.rgba(0.96, 0.98, 1, 0.94) : Qt.rgba(0.09, 0.14, 0.2, 0.88)
    property color headerInkMuted: lightHeaderPalette ? Qt.rgba(0.87, 0.91, 0.98, 0.76) : Qt.rgba(0.2, 0.28, 0.38, 0.62)
    property color headerErrorInk: lightHeaderPalette ? Qt.rgba(1, 0.79, 0.82, 0.96) : Qt.rgba(0.62, 0.14, 0.18, 0.88)
    property real currentEpoch: Math.floor(Date.now() / 1000)

    function validNumber(value) {
        return value !== undefined && value !== null && !isNaN(value);
    }

    function modelCount(model) {
        if (!model)
            return 0;

        return typeof model.count === "function" ? model.count() : Number(model.count || 0);
    }

    function fmtTemp(value) {
        return validNumber(value) ? Math.round(UiPreferences.weatherTemperature(value)) + "°" : "--";
    }

    function fmtTempPlain(value) {
        return validNumber(value) ? Math.round(UiPreferences.weatherTemperature(value)).toString() : "--";
    }

    function fmtTime(epoch) {
        if (!epoch)
            return "--";

        return UiPreferences.shortTime(new Date(epoch * 1000));
    }

    function fmtSpeed(ms) {
        return validNumber(ms) ? ms.toFixed(1) + " m/s" : "--";
    }

    function fmtPercent(value) {
        return validNumber(value) ? Math.round(value) + "%" : "--";
    }

    function fmtDistance(meters) {
        return validNumber(meters) ? (meters / 1000).toFixed(1) + " km" : "--";
    }

    function currentHour() {
        return new Date(root.currentEpoch * 1000).getHours();
    }

    function updatedText() {
        if (root.weatherSource.loading)
            return qsTr("正在刷新");

        if (root.weatherSource.status === "fresh" || root.weatherSource.status === "partial") {
            const date = new Date(root.weatherSource.lastUpdated);
            return qsTr("更新于 ") + UiPreferences.shortTime(date);
        }
        if (root.weatherSource.status === "stale")
            return qsTr("数据较旧");

        if (root.weatherSource.status === "error")
            return qsTr("更新失败");

        return qsTr("待更新");
    }

    function dayLabel(index, epoch) {
        if (index === 0)
            return qsTr("今天");

        if (index === 1)
            return qsTr("明天");

        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "ddd") : "--";
    }

    function uvLevel(value) {
        if (!validNumber(value))
            return "--";

        if (value < 3)
            return qsTr("低");

        if (value < 6)
            return qsTr("中");

        if (value < 8)
            return qsTr("高");

        if (value < 11)
            return qsTr("很高");

        return qsTr("极高");
    }

    function uvIndexBucket(value) {
        if (!validNumber(value))
            return -1;

        if (value < 3)
            return 0;

        if (value < 6)
            return 1;

        if (value < 8)
            return 2;

        if (value < 11)
            return 3;

        return 4;
    }

    function windAccent(ms) {
        if (!validNumber(ms))
            return "#4d8d7b";

        if (ms < 4)
            return "#72d572";

        if (ms < 6)
            return "#ffca28";

        if (ms < 8)
            return "#ffa726";

        if (ms < 10)
            return "#e52f35";

        if (ms < 12)
            return "#99004c";

        return "#7e0023";
    }

    function directionLabel(degree) {
        if (!validNumber(degree))
            return "--";

        const normalized = ((degree % 360) + 360) % 360;
        if (normalized < 22.5 || normalized >= 337.5)
            return "N";

        if (normalized < 67.5)
            return "NE";

        if (normalized < 112.5)
            return "E";

        if (normalized < 157.5)
            return "SE";

        if (normalized < 202.5)
            return "S";

        if (normalized < 247.5)
            return "SW";

        if (normalized < 292.5)
            return "W";

        return "NW";
    }

    function activeHalfDay() {
        const day = today();
        const hour = currentHour();
        if (hour < 5)
            return day.night || ({
        });

        if (hour < 17)
            return day.day || ({
        });

        return day.night || ({
        });
    }

    function precipitationValueText() {
        const half = activeHalfDay();
        const snow = validNumber(half.snowCm) ? half.snowCm : 0;
        const rain = validNumber(half.rainMm) ? half.rainMm : 0;
        const total = validNumber(half.precipitationMm) ? half.precipitationMm : NaN;
        if (snow > 0 && rain <= 0)
            return snow.toFixed(1) + " cm";

        return validNumber(total) ? total.toFixed(1) + " mm" : "--";
    }

    function precipitationDescriptionText() {
        const half = activeHalfDay();
        const snow = validNumber(half.snowCm) ? half.snowCm : 0;
        const rain = validNumber(half.rainMm) ? half.rainMm : 0;
        const hour = currentHour();
        const isDay = hour >= 5 && hour < 17;
        if (snow > 0 && rain <= 0)
            return isDay ? qsTr("白天降雪总量") : qsTr("夜间降雪总量");

        if (rain > 0 && snow <= 0)
            return isDay ? qsTr("白天降雨总量") : qsTr("夜间降雨总量");

        if (snow > 0 && rain > 0)
            return isDay ? qsTr("白天总降水") : qsTr("夜间总降水");

        return isDay ? qsTr("白天总降水") : qsTr("夜间总降水");
    }

    function humidityWaveAccent() {
        return "#625985";
    }

    function visibilityDescription(meters) {
        if (!validNumber(meters))
            return "--";

        const km = meters / 1000;
        if (km >= 16)
            return qsTr("极清晰");

        if (km >= 10)
            return qsTr("清晰");

        if (km >= 6)
            return qsTr("良好");

        if (km >= 3)
            return qsTr("朦胧");

        if (km >= 1)
            return qsTr("较低");

        return qsTr("浓雾");
    }

    function aqiThresholds() {
        return [0, 20, 50, 100, 150, 250];
    }

    function pollutantIndex(value, thresholds) {
        if (!validNumber(value))
            return NaN;

        let level = -1;
        for (let i = 0; i < thresholds.length; ++i) {
            if (value >= thresholds[i])
                level = i;

        }
        if (level < 0)
            return NaN;

        const aqi = aqiThresholds();
        if (level < thresholds.length - 1) {
            const bpLo = thresholds[level];
            const bpHi = thresholds[level + 1];
            const inLo = aqi[level];
            const inHi = aqi[level + 1];
            return Math.round(((inHi - inLo) / (bpHi - bpLo)) * (value - bpLo) + inLo);
        }
        return Math.round((value * aqi[aqi.length - 1]) / thresholds[thresholds.length - 1]);
    }

    function aqiLevelIndex(value) {
        if (!validNumber(value))
            return -1;

        const thresholds = aqiThresholds();
        let level = 0;
        for (let i = 0; i < thresholds.length; ++i) {
            if (value >= thresholds[i])
                level = i;

        }
        return Math.min(level, 5);
    }

    function aqiPalette(level) {
        const colors = ["#00e59b", "#ffc302", "#ff712b", "#f62a55", "#c72eaa", "#9930ff"];
        return colors[Math.max(0, Math.min(colors.length - 1, level))];
    }

    function aqiLevelName(level) {
        const names = [qsTr("优"), qsTr("良"), qsTr("差"), qsTr("不健康"), qsTr("很不健康"), qsTr("危险")];
        if (level < 0 || level >= names.length)
            return "--";

        return names[level];
    }

    function aqiSummary() {
        const air = root.weatherSource.currentAirQuality || ({
        });
        const values = [pollutantIndex(air.ozone, [0, 50, 100, 160, 240, 480]), pollutantIndex(air.nitrogenDioxide, [0, 10, 25, 200, 400, 1000]), pollutantIndex(air.pm10, [0, 15, 45, 80, 160, 400]), pollutantIndex(air.pm25, [0, 5, 15, 30, 60, 150])].filter(validNumber);
        if (values.length === 0)
            return ({
            "value": NaN,
            "level": "--",
            "color": "#00e59b"
        });

        const value = Math.max.apply(Math, values);
        const level = aqiLevelIndex(value);
        return ({
            "value": value,
            "level": aqiLevelName(level),
            "color": aqiPalette(level)
        });
    }

    function pressureValueText(value) {
        return validNumber(value) ? Number(value).toLocaleString(Qt.locale(), "f", 1) : "--";
    }

    function today() {
        return modelCount(root.weatherSource.dailyForecast) > 0 ? root.weatherSource.dailyForecast.get(0) : ({
        });
    }

    function currentIsNight() {
        const day = today();
        const sunrise = day.sunrise || 0;
        const sunset = day.sunset || 0;
        if (sunrise > 0 && sunset > 0) {
            const now = Math.floor(root.currentEpoch);
            return now < sunrise || now >= sunset;
        }
        const current = root.weatherSource.current();
        if (current && current.isDaylight !== undefined)
            return !current.isDaylight;

        const nextHour = modelCount(root.weatherSource.hourlyForecast) > 0 ? root.weatherSource.hourlyForecast.get(0) : ({
        });
        if (nextHour && nextHour.isDaylight !== undefined)
            return !nextHour.isDaylight;

        const name = (root.weatherSource.currentIconName || "").toLowerCase();
        if (name.indexOf("night") >= 0 || name.indexOf("_night") >= 0)
            return true;

        if (name.indexOf("day") >= 0 || name.indexOf("_day") >= 0)
            return false;

        return false;
    }

    onForegroundChanged: {
        if (root.foreground)
            root.currentEpoch = Math.floor(Date.now() / 1000);

    }

    Timer {
        interval: 60000
        running: root.foreground
        repeat: true
        onTriggered: root.currentEpoch = Math.floor(Date.now() / 1000)
    }

    Rectangle {
        id: weatherPanel

        anchors.fill: parent
        radius: 30
        clip: true
        color: "transparent"

        // Only the full-bleed background needs a rounded offscreen mask. The
        // scrolling cards stay on the normal scene-graph path.
        Item {
            id: weatherBackgroundClip

            anchors.fill: parent
            layer.enabled: true

            WeatherBackground {
                id: weatherBackground

                anchors.fill: parent
                weatherCode: root.weatherSource.currentWeatherCode
                iconName: root.weatherSource.currentIconName
                windSpeedMs: root.weatherSource.currentWindSpeedMs
                windGustsMs: root.weatherSource.currentWindGustsMs
                night: root.currentIsNight()
                rainBounceY: flick.y + dailyForecastCard.y - flick.contentY
                scrollProgress: Math.max(0, Math.min(1, flick.contentY / 340))
                animate: root.presentationActive
            }

            layer.effect: OpacityMask {

                maskSource: Rectangle {
                    width: weatherPanel.width
                    height: weatherPanel.height
                    radius: weatherPanel.radius
                }

            }

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
                            font.family: Fonts.materialSymbolsOutlined
                            font.pixelSize: 19
                            Layout.preferredWidth: 20
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: root.weatherSource.locationName || qsTr("天气")
                            color: root.headerInk
                            font.family: Fonts.ui
                            font.pixelSize: 19
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                    }

                    IconButton {
                        controlSize: 38
                        Layout.alignment: Qt.AlignVCenter
                        iconName: "edit"
                        iconSize: 22
                        iconColor: root.headerInk
                        accessibleName: qsTr("编辑天气位置")
                        hoverStateLayerColor: Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.1)
                        pressedStateLayerColor: Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.18)
                        onClicked: ControlCenterService.open("language-region")
                    }

                    IconButton {
                        controlSize: 38
                        Layout.alignment: Qt.AlignVCenter
                        enabled: !root.weatherSource.loading
                        iconName: "refresh"
                        iconSize: 22
                        iconColor: root.headerInk
                        accessibleName: qsTr("刷新天气")
                        hoverStateLayerColor: Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.1)
                        pressedStateLayerColor: Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.18)
                        onClicked: root.weatherSource.refresh()
                    }

                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        text: "schedule"
                        color: root.weatherSource.status === "stale" || root.weatherSource.status === "error" ? root.headerErrorInk : root.headerInkMuted
                        font.family: Fonts.materialSymbolsOutlined
                        font.pixelSize: 19
                        Layout.preferredWidth: 20
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        text: updatedText()
                        color: root.weatherSource.status === "stale" || root.weatherSource.status === "error" ? root.headerErrorInk : root.headerInk
                        font.family: Fonts.mono
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                }

            }

        }

        StyledFlickable {
            id: flick

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: fixedHeader.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.contentMargin
            anchors.rightMargin: root.contentMargin
            anchors.bottomMargin: root.contentMargin
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 4

            Column {
                id: contentColumn

                width: flick.width
                spacing: 14

                Item {
                    id: currentSummary

                    width: parent.width
                    height: Math.max(220, currentConditionsColumn.implicitHeight + Appearance.spacing.large, flick.height - 452 - 286 - contentColumn.spacing * 2)

                    Column {
                        id: currentConditionsColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            width: parent.width
                            text: root.weatherSource.currentWeatherText || qsTr("未知")
                            color: Appearance.colors.colOnImage
                            font.family: Fonts.ui
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
                                text: fmtTempPlain(root.weatherSource.currentTemperatureC)
                                color: Appearance.colors.colOnImage
                                font.family: Fonts.numeric
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
                                weatherCode: root.weatherSource.currentWeatherCode
                                iconName: root.weatherSource.currentIconName
                                night: root.currentIsNight()
                                playing: root.presentationActive && currentSummary.y + currentSummary.height >= flick.contentY && currentSummary.y <= flick.contentY + flick.height
                            }

                        }

                        Text {
                            width: parent.width
                            text: qsTr("体感温度: ") + fmtTemp(root.weatherSource.currentFeelsLikeC)
                            color: Appearance.colors.colOnImage
                            font.family: Fonts.ui
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: qsTr("最高 ") + fmtTemp(today().temperatureMaxC) + qsTr(" · 最低 ") + fmtTemp(today().temperatureMinC)
                            color: Appearance.colors.colOnImage
                            font.family: Fonts.ui
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
                    sourceModel: root.weatherSource.dailyTrendForecast
                    normalsSource: root.weatherSource
                    foreground: root.presentationActive && dailyForecastCard.y + dailyForecastCard.height >= flick.contentY && dailyForecastCard.y <= flick.contentY + flick.height
                }

                HourlyForecastTrendCard {
                    id: hourlyForecastCard

                    width: parent.width
                    height: 340
                    sourceModel: root.weatherSource.hourlyForecast
                    normalsSource: root.weatherSource
                    foreground: root.presentationActive && hourlyForecastCard.y + hourlyForecastCard.height >= flick.contentY && hourlyForecastCard.y <= flick.contentY + flick.height
                }

                RowLayout {
                    id: precipitationWindRow

                    width: parent.width
                    spacing: 10

                    WeatherRevealCard {
                        id: precipitationReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: precipitationWindRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 0

                        WeatherPrecipitationCard {
                            anchors.fill: parent
                            valueText: precipitationValueText()
                            descriptionText: precipitationDescriptionText()
                            animationEnabled: true
                            animationActive: precipitationReveal.contentAnimationActive
                        }

                    }

                    WeatherRevealCard {
                        id: windReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: precipitationWindRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 1

                        WeatherWindCard {
                            anchors.fill: parent
                            directionDegrees: root.weatherSource.currentWindDirection
                            valueText: fmtSpeed(root.weatherSource.currentWindSpeedMs)
                            detailText: qsTr("阵风 ") + fmtSpeed(root.weatherSource.currentWindGustsMs) + " · " + directionLabel(root.weatherSource.currentWindDirection)
                            accent: windAccent(root.weatherSource.currentWindSpeedMs)
                            animationEnabled: true
                            animationActive: windReveal.contentAnimationActive
                        }

                    }

                }

                RowLayout {
                    id: aqiHumidityRow

                    width: parent.width
                    spacing: 10

                    WeatherRevealCard {
                        id: aqiReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: aqiHumidityRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 0

                        WeatherAqiCard {
                            anchors.fill: parent
                            aqiValue: aqiSummary().value
                            levelText: aqiSummary().level
                            accent: aqiSummary().color
                            animationEnabled: true
                            animationActive: aqiReveal.contentAnimationActive
                        }

                    }

                    WeatherRevealCard {
                        id: humidityReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: aqiHumidityRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 1

                        WeatherHumidityCard {
                            anchors.fill: parent
                            humidityValue: root.weatherSource.currentRelativeHumidity
                            humidityText: fmtPercent(root.weatherSource.currentRelativeHumidity)
                            dewPointText: fmtTemp(root.weatherSource.currentDewPointC)
                            accent: humidityWaveAccent()
                            animationEnabled: true
                            animationActive: humidityReveal.contentAnimationActive
                        }

                    }

                }

                RowLayout {
                    id: uvVisibilityRow

                    width: parent.width
                    spacing: 10

                    WeatherRevealCard {
                        id: uvReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: uvVisibilityRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 0

                        WeatherUvCard {
                            anchors.fill: parent
                            value: root.weatherSource.currentUvIndex
                            level: uvLevel(root.weatherSource.currentUvIndex)
                            activeIndex: uvIndexBucket(root.weatherSource.currentUvIndex)
                            animationEnabled: true
                            animationActive: uvReveal.contentAnimationActive
                        }

                    }

                    WeatherRevealCard {
                        id: visibilityReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: uvVisibilityRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 1

                        WeatherVisibilityCard {
                            anchors.fill: parent
                            visibilityMeters: root.weatherSource.currentVisibilityM
                            animationEnabled: true
                            animationActive: visibilityReveal.contentAnimationActive
                        }

                    }

                }

                RowLayout {
                    id: pressureSunRow

                    width: parent.width
                    spacing: 10

                    WeatherRevealCard {
                        id: pressureReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: pressureSunRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 0

                        WeatherPressureCard {
                            anchors.fill: parent
                            pressureValue: root.weatherSource.currentPressureHpa
                            valueText: pressureValueText(root.weatherSource.currentPressureHpa)
                            unitText: "hPa"
                            animationEnabled: true
                            animationActive: pressureReveal.contentAnimationActive
                        }

                    }

                    WeatherRevealCard {
                        id: sunReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: pressureSunRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 1

                        WeatherAstroCard {
                            anchors.fill: parent
                            moon: false
                            riseText: fmtTime(today().sunrise)
                            setText: fmtTime(today().sunset)
                            riseEpoch: today().sunrise || 0
                            setEpoch: today().sunset || 0
                            currentEpoch: root.currentEpoch
                            animationEnabled: true
                            animationActive: sunReveal.contentAnimationActive
                        }

                    }

                }

                RowLayout {
                    id: moonRow

                    width: parent.width
                    spacing: 10

                    WeatherRevealCard {
                        id: moonReveal

                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        contentTop: moonRow.y
                        viewportContentY: flick.contentY
                        viewportHeight: flick.height
                        activationEnabled: root.presentationActive
                        staggerIndex: 0

                        WeatherAstroCard {
                            anchors.fill: parent
                            moon: true
                            riseText: fmtTime(today().moonrise)
                            setText: fmtTime(today().moonset)
                            riseEpoch: today().moonrise || 0
                            setEpoch: today().moonset || 0
                            currentEpoch: root.currentEpoch
                            phaseAngle: today().moonPhaseAngle || 0
                            animationEnabled: true
                            animationActive: moonReveal.contentAnimationActive
                        }

                    }

                }

                Item {
                    width: 1
                    height: 8
                }

            }

        }

    }

    // Keep the one-pixel outline outside the OpacityMask texture. Rendering it
    // into the masked layer made the already antialiased stroke pass through a
    // second alpha resampling step, which softened the stable rounded edge.
    Rectangle {
        anchors.fill: weatherPanel
        color: "transparent"
        radius: weatherPanel.radius
        border.width: 1 / root.effectiveDpr
        border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.34)
    }

    component SectionCard: Rectangle {
        id: card

        property string title: ""
        property string icon: ""
        default property alias content: contentLayer.data

        radius: 26
        color: BlurService.opaqueBackgroundColor(Appearance.m3colors.m3surfaceContainer)
        border.width: 1
        border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.55)

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.topMargin: 16
            spacing: 8

            Text {
                text: card.icon
                color: Appearance.colors.colOnSurface
                font.family: Fonts.materialSymbolsOutlined
                font.pixelSize: 20
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: card.title
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
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

}
