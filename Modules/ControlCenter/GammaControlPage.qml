import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root
    readonly property var preferences: DisplayColor.preferences
    clip: true
    contentWidth: width
    contentHeight: content.implicitHeight + Metrics.pageMargin * 2
    function timeText(minutes) {
        return Math.floor(minutes / 60).toString().padStart(2, "0") + ":" + (minutes % 60).toString().padStart(
                    2, "0");
    }
    function setTime(key, text) {
        const parts = text.split(":").map(Number);
        if (parts.length === 2 && parts[0] >= 0 && parts[0] < 24 && parts[1] >= 0 && parts[1] < 60)
            DisplayColor.setPreference(key, parts[0] * 60 + parts[1]);
    }
    ColumnLayout {
        id: content
        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL
        InlineStatusBanner {
            Layout.fillWidth: true
            visible: !DisplayColor.available
            message: qsTr("The compositor does not provide Gamma control")
        }
        InlineStatusBanner {
            Layout.fillWidth: true
            visible: DisplayColor.error !== ""
            tone: "error"
            message: DisplayColor.error
        }
        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Color")
            iconName: "contrast"
            flat: true
            enabled: DisplayColor.ready
            GeneralSliderSetting {
                title: qsTr("Gamma")
                from: 50
                to: 200
                stepSize: 1
                suffix: "%"
                value: root.preferences.gamma * 100
                onMoved: value => DisplayColor.setPreference("gamma", value / 100)
            }
            GeneralSliderSetting {
                title: qsTr("Contrast")
                from: 50
                to: 200
                stepSize: 1
                suffix: "%"
                value: root.preferences.contrast * 100
                onMoved: value => DisplayColor.setPreference("contrast", value / 100)
            }
            GeneralSliderSetting {
                title: qsTr("Software dimming")
                from: 25
                to: 100
                stepSize: 1
                suffix: "%"
                value: root.preferences.dimming * 100
                onMoved: value => DisplayColor.setDimming(value / 100)
            }
        }
        SettingsSection {
            Layout.fillWidth: true
            flat: true
            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Night Mode")
                iconName: "nightlight"
                trailing: StyledSwitch {
                    checked: root.preferences.nightEnabled
                    Accessible.name: qsTr("Night Mode")
                    onToggled: DisplayColor.setPreference("nightEnabled", checked)
                }
            }
            GeneralSliderSetting {
                visible: root.preferences.nightEnabled
                title: qsTr("Night temperature")
                from: 1000
                to: 6500
                stepSize: 100
                suffix: " K"
                value: root.preferences.nightTemperature
                onMoved: value => DisplayColor.setPreference("nightTemperature", value)
            }
        }
        SettingsSection {
            Layout.fillWidth: true
            visible: root.preferences.nightEnabled
            title: qsTr("Schedule")
            iconName: "schedule"
            flat: true
            DisplayChoice {
                Layout.fillWidth: true
                title: qsTr("Automatic control")
                options: [
                    {
                        value: "fixed",
                        label: qsTr("Fixed temperature")
                    },
                    {
                        value: "time",
                        label: qsTr("Time")
                    },
                    {
                        value: "location",
                        label: qsTr("Sunrise and sunset")
                    }
                ]
                value: root.preferences.mode
                onSelected: value => DisplayColor.setPreference("mode", value)
            }
            GeneralSliderSetting {
                visible: root.preferences.mode !== "fixed"
                title: qsTr("Day temperature")
                from: 1000
                to: 10000
                stepSize: 100
                suffix: " K"
                value: root.preferences.dayTemperature
                onMoved: value => DisplayColor.setPreference("dayTemperature", value)
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width > 400 ? 2 : 1
                visible: root.preferences.mode === "time"
                OutlinedTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("Night starts (HH:MM)")
                    text: root.timeText(root.preferences.start)
                    validator: RegularExpressionValidator {
                        regularExpression: /([01][0-9]|2[0-3]):[0-5][0-9]/
                    }
                    onEditingFinished: root.setTime("start", text)
                }
                OutlinedTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("Day starts (HH:MM)")
                    text: root.timeText(root.preferences.end)
                    validator: RegularExpressionValidator {
                        regularExpression: /([01][0-9]|2[0-3]):[0-5][0-9]/
                    }
                    onEditingFinished: root.setTime("end", text)
                }
            }
            GeneralSliderSetting {
                visible: root.preferences.mode !== "fixed"
                title: qsTr("Transition duration")
                from: 0
                to: 180
                stepSize: 1
                suffix: qsTr(" min")
                value: root.preferences.transition
                onMoved: value => DisplayColor.setPreference("transition", value)
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width > 400 ? 2 : 1
                visible: root.preferences.mode === "location"
                Repeater {
                    model: [
                        {
                            key: "latitude",
                            label: qsTr("Latitude"),
                            limit: 90
                        },
                        {
                            key: "longitude",
                            label: qsTr("Longitude"),
                            limit: 180
                        }
                    ]
                    OutlinedTextField {
                        required property var modelData
                        Layout.fillWidth: true
                        labelText: modelData.label
                        text: root.preferences[modelData.key] === null ? "" : String(
                                                                             root.preferences[modelData.key])
                        validator: DoubleValidator {
                            bottom: -modelData.limit
                            top: modelData.limit
                            locale: "C"
                        }
                        onEditingFinished: DisplayColor.setPreference(modelData.key, text.trim() === "" ? null :
                                                                                                          Number(text))
                    }
                }
            }
            SettingsRow {
                Layout.fillWidth: true
                visible: root.preferences.mode === "location"
                title: qsTr("Automatic IP location")

                trailing: StyledSwitch {
                    checked: root.preferences.useIP
                    Accessible.name: qsTr("Automatic IP location")
                    onToggled: DisplayColor.setPreference("useIP", checked)
                    InlineBusyIndicator {
                        anchors.centerIn: parent
                        busy: DisplayColor.locating
                    }
                }
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: DisplayColor.locationError !== ""
                message: DisplayColor.locationError
            }
            ActionButton {
                visible: root.preferences.mode === "location" && root.preferences.useIP
                text: qsTr("Refresh location")
                enabled: !DisplayColor.locating
                onClicked: DisplayColor.locate()
            }
            ActionButton {
                visible: root.preferences.mode === "location"
                enabled: DisplayColor.ready
                text: qsTr("Use weather location")
                onClicked: DisplayColor.useWeatherLocation()
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: DisplayColor.scheduleWarning !== ""
                message: DisplayColor.scheduleWarning
            }
            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Scheduled temperature")
                iconName: "thermostat"
                supportingText: qsTr("%1 K · Target %2 K").arg(DisplayColor.schedule.temperature).arg(
                                    DisplayColor.schedule.target)
            }
            SettingsRow {
                Layout.fillWidth: true
                visible: DisplayColor.schedule.next > 0
                title: qsTr("Next transition")
                iconName: "schedule"
                supportingText: Qt.formatDateTime(new Date(DisplayColor.schedule.next), "ddd hh:mm")
            }
        }
        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Outputs")
            iconName: "monitor"
            flat: true
            Repeater {
                model: DisplayColor.outputs
                SettingsRow {
                    required property var modelData
                    Layout.fillWidth: true
                    title: modelData.name
                    iconName: "monitor"
                    supportingText: {
                        switch (modelData.state) {
                        case "failed":
                            return qsTr("Gamma control failed (reason unavailable)");
                        case "submitted":
                            return qsTr("Curve submitted");
                        case "pending":
                            return qsTr("Waiting for display");
                        case "unavailable":
                            return qsTr("Gamma control unavailable");
                        default:
                            return qsTr("Control released");
                        }
                    }
                }
            }
            ActionButton {
                text: qsTr("Retry output control")
                enabled: DisplayColor.available
                onClicked: DisplayColor.retry()
            }
        }
    }
}
