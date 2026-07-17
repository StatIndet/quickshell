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

    width: 820
    height: 560

    property bool active: false
    property real latitude: 0
    property real longitude: 0
    property string locationName: "Weather"
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
        property color containerColor: Appearance.colors.colSecondaryContainer
        property color contentColor: Appearance.colors.colOnSecondaryContainer
        property color accentColor: Appearance.colors.colOnSecondaryContainer

        implicitHeight: 44
        radius: Appearance.rounding.small
        color: containerColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            MaterialSymbol {
                text: parent.parent.iconName
                iconSize: 17
                color: parent.parent.accentColor
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: parent.parent.parent.label
                    color: Appearance.applyAlpha(
                        parent.parent.parent.contentColor,
                        0.72
                    )
                    font.family: Sizes.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: parent.parent.parent.value
                    color: parent.parent.parent.contentColor
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 12
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
            return root.hasWeather ? "Refreshing" : "Locating"
        if (WeatherPlugin.status === "stale")
            return "Data may be stale"
        if (WeatherPlugin.status === "partial")
            return "Partially updated"
        if (WeatherPlugin.status === "error")
            return "Update failed"
        if (WeatherPlugin.lastUpdated) {
            const updated = new Date(WeatherPlugin.lastUpdated)
            if (!isNaN(updated.getTime()))
                return "Updated " + Qt.formatDateTime(updated, "hh:mm")
        }
        return "Live weather"
    }

    function weatherErrorText() {
        return WeatherPlugin.errorMessage || "Weather data is unavailable"
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

    function stopRefreshAnimation() {
        forceStopTimer.stop()
        if (spinAnimation.running)
            spinAnimation.stop()
        resetAnimation.start()
    }

    function fetchData() {
        if (WeatherPlugin.loading)
            return

        resetAnimation.stop()
        refreshIcon.rotation = 0
        spinAnimation.start()
        forceStopTimer.restart()
        WeatherPlugin.refresh()
    }

    function syncWeatherData() {
        if (!WeatherPlugin.hasValidData) {
            root.locationName = WeatherPlugin.locationName || "Weather"
            root.currentTemp = "--"
            root.currentIcon = "cloud"
            root.currentDesc = "--"
            root.feelsLike = "--"
            root.humidity = "--"
            root.windSpeed = "--"
            root.pressure = "--"
            root.hourlyData = []
            root.dailyData = []
            hourlyCanvas.requestPaint()
            return
        }

        root.latitude = Number(WeatherPlugin.latitude)
        root.longitude = Number(WeatherPlugin.longitude)
        root.locationName = WeatherPlugin.locationName || "Unknown"
        root.currentTemp = Math.round(WeatherPlugin.currentTemperatureC) + "°"
        root.currentIcon = WeatherPlugin.currentIconName || "cloud"
        root.currentDesc = WeatherPlugin.currentWeatherText || "Unknown"
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
                description: item.weatherText || "Unknown",
                isDaylight: item.isDaylight === undefined ? true : item.isDaylight
            })
        }
        root.hourlyData = nextHourly

        const nextDaily = []
        const dailyCount = Math.min(7, WeatherPlugin.dailyForecast.count())
        for (let dayIndex = 0; dayIndex < dailyCount; ++dayIndex) {
            const item = WeatherPlugin.dailyForecast.get(dayIndex)
            const dateObject = item.date
                ? new Date(item.date + "T00:00:00")
                : new Date(Number(item.time || 0) * 1000)
            const dayPart = item.day || ({})
            nextDaily.push({
                day: dayIndex === 0 ? "Today" : Qt.formatDate(dateObject, "ddd"),
                icon: dayPart.iconName || item.iconName || "cloud",
                maxTemp: Math.round(
                    Number(item.temperatureMaxC || dayPart.temperatureC || 0)
                ) + "°",
                minTemp: Math.round(Number(item.temperatureMinC || 0)) + "°"
            })
        }
        root.dailyData = nextDaily

        hourlyCanvas.requestPaint()
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
            root.stopRefreshAnimation()
        }

        function onLoadingChanged() {
            if (!WeatherPlugin.loading)
                root.stopRefreshAnimation()
        }
    }

    Timer {
        id: forceStopTimer

        interval: 5000
        onTriggered: root.stopRefreshAnimation()
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 292
            Layout.preferredHeight: 292
            Layout.maximumHeight: 292
            spacing: 16

            Rectangle {
                id: currentCard

                Layout.preferredWidth: 272
                Layout.fillHeight: true
                radius: Appearance.rounding.large
                color: root.hasWeather
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colSurfaceContainerHigh
                clip: true

                Accessible.name: root.hasWeather
                    ? root.locationName + ", " + root.currentDesc + ", " + root.currentTemp
                    : root.weatherErrorText()

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 48
                        Layout.preferredHeight: 48
                        Layout.maximumHeight: 48
                        spacing: 8

                        MaterialSymbol {
                            text: "location_on"
                            iconSize: 20
                            fill: 1
                            color: root.hasWeather
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colPrimary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: root.locationName
                                color: root.hasWeather
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colOnSurface
                                font.family: Sizes.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.updatedText()
                                color: root.hasWeather
                                    ? Appearance.applyAlpha(
                                        Appearance.colors.colOnPrimaryContainer,
                                        0.72
                                    )
                                    : Appearance.colors.colOnSurfaceVariant
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }

                        ToolButton {
                            id: refreshButton

                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignVCenter
                            enabled: !WeatherPlugin.loading
                            hoverEnabled: true
                            focusPolicy: Qt.StrongFocus

                            Accessible.name: "Refresh weather"

                            onClicked: root.fetchData()

                            background: Rectangle {
                                radius: Appearance.rounding.full
                                color: refreshButton.down
                                    ? root.hasWeather
                                        ? Appearance.colors.colPrimaryContainerActive
                                        : Appearance.colors.colLayer4Active
                                    : refreshButton.hovered || refreshButton.activeFocus
                                        ? root.hasWeather
                                            ? Appearance.colors.colPrimaryContainerHover
                                            : Appearance.colors.colLayer4
                                        : Appearance.transparentize(
                                            root.hasWeather
                                                ? Appearance.colors.colPrimaryContainer
                                                : Appearance.colors.colLayer4,
                                            1
                                        )

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.animation.expressiveEffects.duration
                                        easing.type: Appearance.animation.expressiveEffects.type
                                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                    }
                                }
                            }

                            contentItem: MaterialSymbol {
                                id: refreshIcon

                                text: "refresh"
                                iconSize: 21
                                color: refreshButton.enabled
                                    ? root.hasWeather
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnSurfaceVariant
                                    : Appearance.applyAlpha(
                                        root.hasWeather
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colOnSurface,
                                        0.38
                                    )
                            }

                            StyledToolTip {
                                extraVisibleCondition: refreshButton.hovered
                                text: WeatherPlugin.loading
                                    ? "Refreshing weather"
                                    : "Refresh weather"
                            }

                            RotationAnimation {
                                id: spinAnimation

                                target: refreshIcon
                                property: "rotation"
                                from: 0
                                to: 360
                                duration: 800
                                loops: Animation.Infinite
                            }

                            RotationAnimation {
                                id: resetAnimation

                                target: refreshIcon
                                property: "rotation"
                                to: 0
                                duration: Appearance.animation.expressiveEffects.duration
                                direction: RotationAnimation.Shortest
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.hasWeather ? 0 : 1

                        ColumnLayout {
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 72
                                spacing: 10

                                MaterialSymbol {
                                    text: root.currentIcon
                                    iconSize: 52
                                    fill: 1
                                    color: Appearance.colors.colOnPrimaryContainer
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -2

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.currentDesc
                                        color: Appearance.colors.colOnPrimaryContainer
                                        font.family: Sizes.fontFamily
                                        font.pixelSize: 16
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.currentTemp
                                        color: Appearance.colors.colOnPrimaryContainer
                                        font.family: Sizes.fontFamilyMono
                                        font.pixelSize: 46
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 8

                                MetricTile {
                                    Layout.fillWidth: true
                                    iconName: "thermostat"
                                    label: "Feels like"
                                    value: root.feelsLike
                                    containerColor: Appearance.colors.colSecondaryContainer
                                    contentColor: Appearance.colors.colOnSecondaryContainer
                                    accentColor: Appearance.colors.colOnSecondaryContainer
                                }

                                MetricTile {
                                    Layout.fillWidth: true
                                    iconName: "water_drop"
                                    label: "Humidity"
                                    value: root.humidity
                                    containerColor: Appearance.colors.colSecondaryContainer
                                    contentColor: Appearance.colors.colOnSecondaryContainer
                                    accentColor: Appearance.colors.colOnSecondaryContainer
                                }

                                MetricTile {
                                    Layout.fillWidth: true
                                    iconName: "air"
                                    label: "Wind"
                                    value: root.windSpeed
                                    containerColor: Appearance.colors.colSecondaryContainer
                                    contentColor: Appearance.colors.colOnSecondaryContainer
                                    accentColor: Appearance.colors.colOnSecondaryContainer
                                }

                                MetricTile {
                                    Layout.fillWidth: true
                                    iconName: "compress"
                                    label: "Pressure"
                                    value: root.pressure
                                    containerColor: Appearance.colors.colSecondaryContainer
                                    contentColor: Appearance.colors.colOnSecondaryContainer
                                    accentColor: Appearance.colors.colOnSecondaryContainer
                                }
                            }
                        }

                        Item {
                            ColumnLayout {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, 210)
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
                                        ? "Loading weather"
                                        : "Weather unavailable"
                                    color: Appearance.colors.colOnSurface
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    textFormat: Text.PlainText
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: WeatherPlugin.loading
                                        ? "Finding your local forecast…"
                                        : root.weatherErrorText()
                                    color: Appearance.colors.colOnSurfaceVariant
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: weatherMapLoader

                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.active
                asynchronous: true
                source: active
                    ? Qt.resolvedUrl("WeatherMapCard.qml")
                    : ""
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

        Rectangle {
            id: forecastCard

            Layout.fillWidth: true
            Layout.minimumHeight: 220
            Layout.preferredHeight: 220
            Layout.maximumHeight: 220
            radius: Appearance.rounding.large
            color: Appearance.colors.colSurfaceContainerHigh
            clip: true

            Accessible.name: root.isHourly
                ? "Eight hour weather forecast"
                : "Seven day weather forecast"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 8

                    MaterialSymbol {
                        text: root.isHourly ? "schedule" : "calendar_month"
                        iconSize: 22
                        fill: 1
                        color: Appearance.colors.colPrimary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: "Forecast"
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        textFormat: Text.PlainText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledButtonGroup {
                        currentValue: root.isHourly ? "hourly" : "daily"
                        style: StyledButtonGroup.Style.Primary
                        buttonHeight: 40
                        horizontalPadding: 20
                        textPixelSize: 13
                        model: [
                            ({
                                "value": "hourly",
                                "label": "8 Hours",
                                "tooltip": "Show the next eight hours"
                            }),
                            ({
                                "value": "daily",
                                "label": "7 Days",
                                "tooltip": "Show the next seven days"
                            })
                        ]
                        Accessible.name: "Forecast range"
                        onValueSelected: value => root.isHourly = value === "hourly"
                    }
                }

                Item {
                    id: forecastBody

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        id: hourlyPane

                        anchors.fill: parent
                        opacity: root.isHourly ? 1 : 0
                        visible: opacity > 0

                        readonly property real chartTop: 50
                        readonly property real chartBottom: Math.max(
                            chartTop + 24,
                            height - 24
                        )

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }

                        Canvas {
                            id: hourlyCanvas

                            anchors.fill: parent
                            antialiasing: true
                            renderTarget: Canvas.FramebufferObject
                            visible: root.hourlyData && root.hourlyData.length >= 2

                            property color lineColor: Appearance.colors.colPrimary

                            onLineColorChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                const count = root.hourlyData
                                    ? root.hourlyData.length
                                    : 0
                                if (count < 2)
                                    return

                                const columnWidth = width / count

                                function pointX(index) {
                                    return columnWidth * index + columnWidth / 2
                                }

                                function pointY(index) {
                                    return root.hourlyPointY(
                                        root.hourlyData[index].temp,
                                        hourlyPane.chartTop,
                                        hourlyPane.chartBottom
                                    )
                                }

                                const fillGradient = ctx.createLinearGradient(
                                    0,
                                    hourlyPane.chartTop,
                                    0,
                                    hourlyPane.chartBottom
                                )
                                fillGradient.addColorStop(
                                    0,
                                    root.cssColor(lineColor, 0.20)
                                )
                                fillGradient.addColorStop(
                                    1,
                                    root.cssColor(lineColor, 0.02)
                                )

                                ctx.beginPath()
                                ctx.moveTo(pointX(0), hourlyPane.chartBottom)
                                ctx.lineTo(pointX(0), pointY(0))
                                for (let index = 1; index < count; ++index)
                                    ctx.lineTo(pointX(index), pointY(index))
                                ctx.lineTo(
                                    pointX(count - 1),
                                    hourlyPane.chartBottom
                                )
                                ctx.closePath()
                                ctx.fillStyle = fillGradient
                                ctx.fill()

                                ctx.beginPath()
                                ctx.moveTo(pointX(0), pointY(0))
                                for (let lineIndex = 1; lineIndex < count; ++lineIndex)
                                    ctx.lineTo(pointX(lineIndex), pointY(lineIndex))
                                ctx.strokeStyle = lineColor
                                ctx.lineWidth = 3
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.stroke()

                                for (let pointIndex = 0; pointIndex < count; ++pointIndex) {
                                    const x = pointX(pointIndex)
                                    const y = pointY(pointIndex)
                                    ctx.beginPath()
                                    ctx.arc(x, y, 4.5, 0, Math.PI * 2)
                                    ctx.fillStyle = lineColor
                                    ctx.fill()
                                }
                            }
                        }

                        Repeater {
                            model: root.hourlyData

                            delegate: Item {
                                required property int index
                                required property var modelData

                                width: hourlyPane.width / Math.max(
                                    1,
                                    root.hourlyData.length
                                )
                                height: hourlyPane.height
                                x: index * width

                                readonly property real pointY: root.hourlyPointY(
                                    modelData.temp,
                                    hourlyPane.chartTop,
                                    hourlyPane.chartBottom
                                )

                                Accessible.name: modelData.time
                                    + ", " + modelData.description
                                    + ", " + modelData.temp + " degrees"

                                MaterialSymbol {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: parent.modelData.icon
                                    iconSize: 22
                                    fill: parent.modelData.isDaylight ? 1 : 0
                                    color: Appearance.colors.colOnSurfaceVariant
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.max(25, parent.pointY - implicitHeight - 6)
                                    text: parent.modelData.temp + "°"
                                    color: Appearance.colors.colOnSurface
                                    font.family: Sizes.fontFamilyMono
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    textFormat: Text.PlainText
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: parent.modelData.time
                                    color: Appearance.colors.colOnSurfaceVariant
                                    font.family: Sizes.fontFamilyMono
                                    font.pixelSize: 11
                                    textFormat: Text.PlainText
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: !root.hourlyData || root.hourlyData.length === 0

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "hourglass_empty"
                                iconSize: 30
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            Text {
                                text: "Hourly forecast unavailable"
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Sizes.fontFamily
                                font.pixelSize: 13
                                textFormat: Text.PlainText
                            }
                        }
                    }

                    Item {
                        id: dailyPane

                        anchors.fill: parent
                        opacity: root.isHourly ? 0 : 1
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            visible: root.dailyData && root.dailyData.length > 0

                            Repeater {
                                model: root.dailyData

                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumWidth: 72
                                    radius: Appearance.rounding.normal
                                    color: index === 0
                                        ? Appearance.colors.colSecondaryContainer
                                        : Appearance.colors.colSurfaceContainerHighest

                                    Accessible.name: modelData.day
                                        + ", high " + modelData.maxTemp
                                        + ", low " + modelData.minTemp

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.topMargin: 8
                                        anchors.bottomMargin: 8
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: parent.parent.modelData.day
                                            color: parent.parent.index === 0
                                                ? Appearance.colors.colOnSecondaryContainer
                                                : Appearance.colors.colOnSurfaceVariant
                                            font.family: Sizes.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            textFormat: Text.PlainText
                                        }

                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.fillHeight: true
                                            text: parent.parent.modelData.icon
                                            iconSize: 27
                                            fill: 1
                                            color: parent.parent.index === 0
                                                ? Appearance.colors.colOnSecondaryContainer
                                                : Appearance.colors.colPrimary
                                        }

                                        Row {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 5

                                            Text {
                                                text: parent.parent.parent.modelData.maxTemp
                                                color: parent.parent.parent.index === 0
                                                    ? Appearance.colors.colOnSecondaryContainer
                                                    : Appearance.colors.colOnSurface
                                                font.family: Sizes.fontFamilyMono
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                textFormat: Text.PlainText
                                            }

                                            Text {
                                                text: parent.parent.parent.modelData.minTemp
                                                color: parent.parent.parent.index === 0
                                                    ? Appearance.applyAlpha(
                                                        Appearance.colors.colOnSecondaryContainer,
                                                        0.72
                                                    )
                                                    : Appearance.colors.colOnSurfaceVariant
                                                font.family: Sizes.fontFamilyMono
                                                font.pixelSize: 12
                                                textFormat: Text.PlainText
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: !root.dailyData || root.dailyData.length === 0

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "event_busy"
                                iconSize: 30
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            Text {
                                text: "Daily forecast unavailable"
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Sizes.fontFamily
                                font.pixelSize: 13
                                textFormat: Text.PlainText
                            }
                        }
                    }
                }
            }
        }
    }
}
