import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common
import qs.Widgets.weather

Rectangle {
    id: root

    property var sourceModel
    property real itemWidth: trendFlick.width > 0 ? trendFlick.width / 6 : 122
    property int maxItems: 16
    property int currentTab: 0

    radius: 26
    color: Appearance.colors.colWeatherCardSurface
    border.width: 1
    border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.42)
    clip: true

    function modelCount() {
        return sourceModel && sourceModel.count ? Math.min(maxItems, sourceModel.count()) : 0
    }

    function itemAt(index) {
        return sourceModel && sourceModel.get ? sourceModel.get(index) : ({})
    }

    function valueAt(map, key, fallback) {
        const v = map ? map[key] : undefined
        return (v === undefined || v === null || isNaN(v)) ? fallback : Number(v)
    }

    function fmtTemp(value) {
        return value !== undefined && value !== null && !isNaN(value) ? Math.round(value) + "°" : "--"
    }

    function fmtPercent(value) {
        return value !== undefined && value !== null && !isNaN(value) ? Math.round(value) + "%" : "--"
    }

    function applyInitialPosition() {
        if (trendFlick.initialPositionApplied) return
        const count = root.modelCount()
        if (count < 2) {
            trendFlick.contentX = 0
            trendFlick.initialPositionApplied = true
            return
        }
        const maxX = Math.max(0, trendFlick.contentWidth - trendFlick.width)
        if (maxX <= 0) {
            trendFlick.contentX = 0
            trendFlick.initialPositionApplied = true
            return
        }
        trendFlick.contentX = Math.min(root.itemWidth, maxX)
        trendFlick.initialPositionApplied = true
    }

    function dayLabel(index, epoch) {
        if (index === 0) return "昨天"
        if (index === 1) return "今天"
        if (index === 2) return "明天"
        if (!epoch) return "--"
        const week = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return week[new Date(epoch * 1000).getDay()]
    }

    function dateLabel(epoch) {
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "M/d") : "--"
    }

    Timer {
        id: initialPositionTimer
        interval: 0
        repeat: false
        onTriggered: applyInitialPosition()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 16
            Layout.preferredHeight: 82
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "calendar_month"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "每日预报"
                    color: Appearance.colors.colOnSurface
                    font.family: "LXGW WenKai GB Screen"
                    font.bold: true
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledButtonGroup {
                    currentValue: root.currentTab
                    model: [
                        ({ "value": 0, "label": "天气情况" }),
                        ({ "value": 1, "label": "空气质量" }),
                        ({ "value": 2, "label": "风况" })
                    ]
                    onValueSelected: value => root.currentTab = value
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    radius: 18
                    color: moreMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "more_horiz"
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: moreMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: console.log("Open weather forecast menu")
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledFlickable {
                id: trendFlick

                anchors.fill: parent
                clip: true
                interactive: root.currentTab === 0
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                showVerticalScrollBar: false
                smoothWheelEnabled: false
                contentWidth: Math.max(width, root.modelCount() * root.itemWidth)
                contentHeight: height
                visible: root.currentTab === 0
                property bool initialPositionApplied: false

                onContentXChanged: trendCanvas.requestPaint()

                Component.onCompleted: initialPositionTimer.restart()
                onContentWidthChanged: initialPositionTimer.restart()
                onWidthChanged: initialPositionTimer.restart()
                onVisibleChanged: {
                    if (visible) initialPositionTimer.restart()
                }

                Item {
                    id: trendContent
                    width: trendFlick.contentWidth
                    height: trendFlick.height

                    property real columnWidth: root.itemWidth
                    property real topTextY: 8
                    property real topLabelSpacing: 3
                    property real dayIconSize: Math.max(46, Math.min(60, columnWidth * 0.46))
                    property real dayIconY: 56
                    property real chartTopInset: 166
                    property real chartBottomInset: Math.max(chartTopInset + 72, height - 126)
                    property real rainLabelY: chartBottomInset + 18
                    property real nightIconSize: dayIconSize
                    property real nightIconY: height - nightIconSize - 12
                    property real highTempTextY: 102
                    property real lowTempTextY: nightIconY - 30

                    Canvas {
                        id: trendCanvas
                        anchors.fill: parent
                        antialiasing: true

                        property real chartTop: trendContent.chartTopInset
                        property real chartBottom: trendContent.chartBottomInset

                        function pointX(index) {
                            return root.itemWidth * index + root.itemWidth / 2
                        }

                        function yAt(value, minValue, maxValue) {
                            return chartBottom - (value - minValue) / (maxValue - minValue) * (chartBottom - chartTop)
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            const count = root.modelCount()
                            if (count < 2) return

                            let dayValues = []
                            let nightValues = []
                            let precipitationValues = []
                            let minTemp = 999
                            let maxTemp = -999

                            for (let i = 0; i < count; ++i) {
                                const item = root.itemAt(i)
                                const day = item.day || ({})
                                const night = item.night || ({})
                                const dayTemp = root.valueAt(day, "temperatureC", root.valueAt(item, "temperatureMaxC", NaN))
                                const nightTemp = root.valueAt(night, "temperatureC", root.valueAt(item, "temperatureMinC", NaN))
                                const pop = Math.max(
                                    root.valueAt(day, "precipitationProbability", 0),
                                    root.valueAt(night, "precipitationProbability", 0)
                                )

                                dayValues.push(dayTemp)
                                nightValues.push(nightTemp)
                                precipitationValues.push(pop)
                                if (!isNaN(dayTemp)) {
                                    minTemp = Math.min(minTemp, dayTemp)
                                    maxTemp = Math.max(maxTemp, dayTemp)
                                }
                                if (!isNaN(nightTemp)) {
                                    minTemp = Math.min(minTemp, nightTemp)
                                    maxTemp = Math.max(maxTemp, nightTemp)
                                }
                            }

                            if (maxTemp < minTemp) return
                            if (Math.abs(maxTemp - minTemp) < 0.1) {
                                maxTemp += 1
                                minTemp -= 1
                            }

                            ctx.beginPath()
                            for (let f = 0; f < count; ++f) {
                                const xFill = pointX(f)
                                const yFill = yAt(dayValues[f], minTemp, maxTemp)
                                if (f === 0) ctx.moveTo(xFill, yFill)
                                else ctx.lineTo(xFill, yFill)
                            }
                            for (let r = count - 1; r >= 0; --r) {
                                ctx.lineTo(pointX(r), yAt(nightValues[r], minTemp, maxTemp))
                            }
                            ctx.closePath()
                            const fillGradient = ctx.createLinearGradient(0, chartTop, 0, chartBottom)
                            fillGradient.addColorStop(0, "rgba(" + Math.round(Appearance.colors.colPrimary.r * 255) + "," + Math.round(Appearance.colors.colPrimary.g * 255) + "," + Math.round(Appearance.colors.colPrimary.b * 255) + ",0.12)")
                            fillGradient.addColorStop(1, "rgba(" + Math.round(Appearance.colors.colPrimary.r * 255) + "," + Math.round(Appearance.colors.colPrimary.g * 255) + "," + Math.round(Appearance.colors.colPrimary.b * 255) + ",0.02)")
                            ctx.fillStyle = fillGradient
                            ctx.fill()

                            for (let p = 0; p < count; ++p) {
                                const popValue = precipitationValues[p]
                                if (popValue <= 0) continue
                                const x = pointX(p)
                                const fadedBar = p === 0
                                const barTop = chartBottom - (chartBottom - chartTop) * Math.min(100, popValue) / 100
                                ctx.fillStyle = fadedBar
                                    ? Qt.rgba(Appearance.colors.colSecondary.r, Appearance.colors.colSecondary.g, Appearance.colors.colSecondary.b, 0.10)
                                    : Qt.rgba(Appearance.colors.colSecondary.r, Appearance.colors.colSecondary.g, Appearance.colors.colSecondary.b, 0.18)
                                ctx.beginPath()
                                roundedRect(ctx, x - 5, barTop, 10, chartBottom - barTop, 5)
                                ctx.fill()
                                ctx.fillStyle = fadedBar
                                    ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.42)
                                    : Appearance.colors.colPrimary
                                ctx.font = "bold 11px \"JetBrainsMono Nerd Font\""
                                ctx.textAlign = "center"
                                ctx.fillText(root.fmtPercent(popValue), x, trendContent.rainLabelY)
                            }

                            drawSeries(ctx, dayValues, minTemp, maxTemp, Appearance.colors.colPrimary, 4)
                            drawSeries(ctx, nightValues, minTemp, maxTemp, Appearance.colors.colSecondary, 4)
                        }

                        function drawSeries(ctx, values, minValue, maxValue, color, lineWidth) {
                            for (let i = 1; i < values.length; ++i) {
                                const prevX = pointX(i - 1)
                                const prevY = yAt(values[i - 1], minValue, maxValue)
                                const x = pointX(i)
                                const y = yAt(values[i], minValue, maxValue)
                                const faded = i - 1 === 0 || i === 0

                                ctx.save()
                                if (ctx.setLineDash && i === 1) ctx.setLineDash([4, 3])
                                ctx.strokeStyle = withAlpha(color, faded ? 0.26 : 1)
                                ctx.lineWidth = lineWidth
                                ctx.lineJoin = "round"
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.moveTo(prevX, prevY)
                                ctx.lineTo(x, y)
                                ctx.stroke()
                                ctx.restore()
                            }

                        }

                        function withAlpha(color, factor) {
                            return Qt.rgba(color.r, color.g, color.b, color.a * factor)
                        }

                        function roundedRect(ctx, x, y, w, h, r) {
                            ctx.moveTo(x + r, y)
                            ctx.lineTo(x + w - r, y)
                            ctx.quadraticCurveTo(x + w, y, x + w, y + r)
                            ctx.lineTo(x + w, y + h - r)
                            ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
                            ctx.lineTo(x + r, y + h)
                            ctx.quadraticCurveTo(x, y + h, x, y + h - r)
                            ctx.lineTo(x, y + r)
                            ctx.quadraticCurveTo(x, y, x + r, y)
                        }
                    }

                    Repeater {
                        model: root.modelCount()

                        delegate: Item {
                            x: root.itemWidth * index
                            width: root.itemWidth
                            height: trendContent.height
                            opacity: index === 0 ? 0.45 : 1

                            property var dayItem: root.itemAt(index)
                            property var dayPart: dayItem.day || ({})
                            property var nightPart: dayItem.night || ({})

                            Rectangle {
                                anchors.fill: parent
                                radius: 26
                                color: "transparent"
                                border.width: 0
                            }

                            Column {
                                y: trendContent.topTextY
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                spacing: trendContent.topLabelSpacing

                                Text {
                                    width: parent.width
                                    text: root.dayLabel(index, dayItem.time)
                                    color: Appearance.colors.colOnSurface
                                    font.family: "LXGW WenKai GB Screen"
                                    font.pixelSize: 16
                                    font.bold: index === 1
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: root.dateLabel(dayItem.time)
                                    color: Appearance.colors.colOnSurfaceVariant
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MeteoIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: trendContent.dayIconY
                                width: trendContent.dayIconSize
                                height: trendContent.dayIconSize
                                weatherCode: root.valueAt(dayPart, "weatherCode", -1)
                                iconName: dayPart.iconName || ""
                                night: false
                                style: "fill"
                            }

                            Text {
                                width: parent.width
                                y: trendContent.highTempTextY
                                text: root.fmtTemp(root.valueAt(dayPart, "temperatureC", root.valueAt(dayItem, "temperatureMaxC", NaN)))
                                color: Appearance.colors.colOnSurface
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 19
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                width: parent.width
                                y: trendContent.lowTempTextY
                                text: root.fmtTemp(root.valueAt(nightPart, "temperatureC", root.valueAt(dayItem, "temperatureMinC", NaN)))
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MeteoIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: trendContent.nightIconY
                                width: trendContent.nightIconSize
                                height: trendContent.nightIconSize
                                weatherCode: root.valueAt(nightPart, "weatherCode", -1)
                                iconName: nightPart.iconName || ""
                                night: true
                                style: "fill"
                            }
                        }
                    }

                    MouseArea {
                        id: dragArea
                        x: trendFlick.contentX
                        y: 0
                        z: 20
                        width: trendFlick.width
                        height: trendFlick.height
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        property real lastMouseX: 0

                        onPressed: function(mouse) {
                            lastMouseX = mouse.x
                        }

                        onPositionChanged: function(mouse) {
                            if (!pressed) return
                            const dx = mouse.x - lastMouseX
                            const maxX = Math.max(0, trendFlick.contentWidth - trendFlick.width)
                            trendFlick.contentX = Math.max(0, Math.min(maxX, trendFlick.contentX - dx))
                            lastMouseX = mouse.x
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: root.currentTab === 1

                DailyAirQualityTrendPane {
                    anchors.fill: parent
                    sourceModel: root.sourceModel
                }
            }

            Item {
                anchors.fill: parent
                visible: root.currentTab === 2

                DailyWindTrendPane {
                    anchors.fill: parent
                    sourceModel: root.sourceModel
                }
            }
        }
    }

    Connections {
        target: root.sourceModel
        ignoreUnknownSignals: true
        function onModelReset() {
            trendFlick.initialPositionApplied = false
            initialPositionTimer.restart()
            trendCanvas.requestPaint()
        }
        function onDataChanged() { trendCanvas.requestPaint() }
        function onRowsInserted() {
            trendFlick.initialPositionApplied = false
            initialPositionTimer.restart()
            trendCanvas.requestPaint()
        }
        function onRowsRemoved() { trendCanvas.requestPaint() }
    }

    onSourceModelChanged: {
        trendFlick.initialPositionApplied = false
        initialPositionTimer.restart()
        trendCanvas.requestPaint()
    }
    onWidthChanged: trendCanvas.requestPaint()
    onHeightChanged: trendCanvas.requestPaint()
}
