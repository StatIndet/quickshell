import QtQuick
import QtQuick.Layouts
import Clavis.WeatherMap
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    property var parentModal: null
    property bool presentationActive: false

    signal navigateRequested(string pageId)

    function closeChildWindows() {
        locationPicker.closeChildWindows();
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("语言")
            iconName: "translate"

            SettingsRow {
                Layout.fillWidth: true
                iconName: "language"
                title: qsTr("界面语言")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 190
                    options: I18nService.supportedLanguages
                    value: UiPreferences.language
                    placeholder: qsTr("选择语言")
                    textRole: "label"
                    valueRole: "code"
                    closeOnAccept: true
                    onAccepted: (value) => {
                        return UiPreferences.setLanguage(value);
                    }
                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("地区与天气位置")
            iconName: "map"

            LocationPicker {
                id: locationPicker

                Layout.fillWidth: true
                parentModal: root.parentModal
                active: root.presentationActive && root.visible
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("天气地图")
            iconName: "layers"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("底图服务")

                trailing: StyledButtonGroup {
                    model: [{
                        "value": "openfreemap",
                        "label": "OpenFreeMap"
                    }, {
                        "value": "maptiler",
                        "label": "MapTiler"
                    }]
                    currentValue: UiPreferences.weatherMapBaseProvider
                    buttonMinWidth: 104
                    onValueSelected: (value) => {
                        return UiPreferences.setWeatherMapBaseProvider(value);
                    }
                }

            }

            SettingsActionRow {
                Layout.fillWidth: true
                visible: UiPreferences.weatherMapBaseProvider === "maptiler" && WeatherMapPlugin.credentialsReady && !WeatherMapPlugin.mapTilerConfigured
                text: qsTr("MapTiler 未配置，当前使用 OpenFreeMap")
                iconName: "key_off"
                trailingIconName: "arrow_forward"
                onClicked: root.navigateRequested("advanced")
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("天气图层服务")

                trailing: StyledButtonGroup {
                    model: [{
                        "value": "rainviewer",
                        "label": "RainViewer"
                    }, {
                        "value": "openweather",
                        "label": "OpenWeather"
                    }]
                    currentValue: UiPreferences.weatherMapOverlayProvider
                    buttonMinWidth: 104
                    onValueSelected: (value) => {
                        return UiPreferences.setWeatherMapOverlayProvider(value);
                    }
                }

            }

            SettingsActionRow {
                Layout.fillWidth: true
                visible: UiPreferences.weatherMapOverlayProvider === "openweather" && WeatherMapPlugin.credentialsReady && !WeatherMapPlugin.apiConfigured
                text: qsTr("OpenWeather 未配置，当前使用 RainViewer")
                iconName: "key_off"
                trailingIconName: "arrow_forward"
                onClicked: root.navigateRequested("advanced")
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("单位")
            iconName: "thermostat"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("天气温度")

                trailing: StyledButtonGroup {
                    model: [({
                        "value": "celsius",
                        "label": "°C"
                    }), ({
                        "value": "fahrenheit",
                        "label": "°F"
                    })]
                    currentValue: UiPreferences.weatherTemperatureUnit
                    buttonMinWidth: 56
                    onValueSelected: (value) => {
                        return UiPreferences.setWeatherTemperatureUnit(value);
                    }
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("硬件温度")

                trailing: StyledButtonGroup {
                    model: [({
                        "value": "celsius",
                        "label": "°C"
                    }), ({
                        "value": "fahrenheit",
                        "label": "°F"
                    })]
                    currentValue: UiPreferences.systemTemperatureUnit
                    buttonMinWidth: 56
                    onValueSelected: (value) => {
                        return UiPreferences.setSystemTemperatureUnit(value);
                    }
                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("时间与日期")
            iconName: "schedule"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("时钟格式")

                trailing: StyledButtonGroup {
                    model: [({
                        "value": "24",
                        "label": qsTr("24 小时")
                    }), ({
                        "value": "12",
                        "label": qsTr("12 小时")
                    })]
                    currentValue: UiPreferences.useTwelveHourClock ? "12" : "24"
                    buttonMinWidth: 78
                    onValueSelected: (value) => {
                        return UiPreferences.setUseTwelveHourClock(value === "12");
                    }
                }

            }

        }

    }

}
