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

    // Preview knobs: change these values to test different sidebar weather scenes.
    property string previewWeatherType: "clear" // clear, partly, overcast, rain, snow, storm
    property bool previewNight: false
    property bool previewWindy: false
    property int previewWeatherCode: 2
    property string previewIconName: "partly_cloudy_day"
    property string previewWeatherText: "Partly Cloudy"
    property real previewTemperatureC: 22
    property real previewFeelsLikeC: 21
    property real previewHighC: 26
    property real previewLowC: 17
    property bool lightHeaderPalette: previewNight
    property color headerInk: lightHeaderPalette ? Qt.rgba(0.96, 0.98, 1.0, 0.94) : Qt.rgba(0.09, 0.14, 0.20, 0.88)
    property color headerInkMuted: lightHeaderPalette ? Qt.rgba(0.87, 0.91, 0.98, 0.76) : Qt.rgba(0.20, 0.28, 0.38, 0.62)
    property color headerErrorInk: lightHeaderPalette ? Qt.rgba(1.0, 0.79, 0.82, 0.96) : Qt.rgba(0.62, 0.14, 0.18, 0.88)

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

    function uvLevel(value) {
        if (!validNumber(value)) return "--"
        if (value < 3) return "Low"
        if (value < 6) return "Moderate"
        if (value < 8) return "High"
        if (value < 11) return "Very high"
        return "Extreme"
    }

    function uvIndexBucket(value) {
        if (!validNumber(value)) return -1
        if (value < 3) return 0
        if (value < 6) return 1
        if (value < 8) return 2
        if (value < 11) return 3
        return 4
    }

    function today() {
        return WeatherPlugin.dailyForecast.count() > 0 ? WeatherPlugin.dailyForecast.get(0) : ({})
    }

    Rectangle {
        id: weatherPanel
        anchors.fill: parent
        radius: 30
        clip: true
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.34)
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: weatherPanel.width
                height: weatherPanel.height
                radius: weatherPanel.radius
            }
        }

        WeatherBackgroundPreview {
            anchors.fill: parent
            weatherType: root.previewWeatherType
            night: root.previewNight
            windy: root.previewWindy
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
                        onClicked: console.log("Open weather settings")

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
                    width: parent.width
                    height: Math.max(220, flick.height - 452 - 286 - contentColumn.spacing * 2)

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            width: parent.width
                            text: root.previewWeatherText
                            color: Appearance.colors.colOnSurface
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
                                text: fmtTempPlain(root.previewTemperatureC)
                                color: Appearance.colors.colOnSurface
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
                                weatherCode: root.previewWeatherCode
                                iconName: root.previewIconName
                                night: root.previewNight
                            }
                        }

                        Text {
                            width: parent.width
                            text: "体感温度: " + fmtTemp(root.previewFeelsLikeC)
                            color: Appearance.colors.colOnSurface
                            font.family: "LXGW WenKai GB Screen"
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: "最高 " + fmtTemp(root.previewHighC)
                                  + " · 最低 " + fmtTemp(root.previewLowC)
                            color: Appearance.colors.colOnSurface
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

                    WeatherBlob {
                        Layout.preferredWidth: 186
                        Layout.preferredHeight: 186
                        value: WeatherPlugin.currentUvIndex
                        level: uvLevel(WeatherPlugin.currentUvIndex)
                        activeIndex: uvIndexBucket(WeatherPlugin.currentUvIndex)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 186
                        spacing: 10

                        WeatherMetricCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: "air"
                            label: "Wind"
                            value: fmtSpeed(WeatherPlugin.currentWindSpeedMs)
                            detail: "Gust " + fmtSpeed(WeatherPlugin.currentWindGustsMs)
                            accent: Appearance.colors.colPrimary
                        }

                        WeatherMetricCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            icon: "water_drop"
                            label: "Humidity"
                            value: fmtPercent(WeatherPlugin.currentRelativeHumidity)
                            detail: "Dew " + fmtTemp(WeatherPlugin.currentDewPointC)
                            accent: Appearance.colors.colSecondary
                        }
                    }
                }

                GridLayout {
                    width: parent.width
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    WeatherMetricCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        icon: "compress"
                        label: "Pressure"
                        value: validNumber(WeatherPlugin.currentPressureHpa) ? Math.round(WeatherPlugin.currentPressureHpa) + " hPa" : "--"
                        accent: Appearance.colors.colTertiary
                    }

                    WeatherMetricCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        icon: "visibility"
                        label: "Visibility"
                        value: fmtDistance(WeatherPlugin.currentVisibilityM)
                        accent: Appearance.colors.colPrimary
                    }

                    WeatherMetricCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        icon: "cloud"
                        label: "Clouds"
                        value: fmtPercent(WeatherPlugin.currentCloudCover)
                        accent: Appearance.colors.colSecondary
                    }

                    WeatherMetricCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        icon: "grain"
                        label: "Precipitation"
                        value: WeatherPlugin.minutelyForecast.count() > 0
                               ? WeatherPlugin.minutelyForecast.get(0).precipitationIntensityMmH.toFixed(1) + " mm/h"
                               : fmtPercent(WeatherPlugin.hourlyForecast.count() > 0 ? WeatherPlugin.hourlyForecast.get(0).precipitationProbability : NaN)
                        accent: Appearance.colors.colTertiary
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    AstroPill {
                        Layout.fillWidth: true
                        icon: "sunny"
                        label: "Sun"
                        value: fmtTime(today().sunrise) + " / " + fmtTime(today().sunset)
                    }

                    AstroPill {
                        Layout.fillWidth: true
                        icon: "nightlight"
                        label: "Moon"
                        value: fmtTime(today().moonrise) + " / " + fmtTime(today().moonset)
                    }
                }

                Item {
                    width: 1
                    height: 8
                }
            }
        }
    }

    component AstroPill: Rectangle {
        id: pill

        property string icon
        property string label
        property string value

        radius: 22
        implicitHeight: 66
        color: Qt.rgba(Appearance.colors.colLayer2.r, Appearance.colors.colLayer2.g, Appearance.colors.colLayer2.b, 0.78)
        border.width: 1
        border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.55)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            Text {
                text: pill.icon
                color: Appearance.colors.colPrimary
                font.family: "Material Symbols Outlined"
                font.pixelSize: 22
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: pill.label
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    text: pill.value
                    color: Appearance.colors.colOnSurface
                    font.family: "LXGW WenKai GB Screen"
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
