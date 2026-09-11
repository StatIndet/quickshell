import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Modules.ControlCenter

WidgetPanel {
    id: root

    title: qsTr("Night Mode")
    icon: "nightlight"
    showBackButton: true
    backAction: () => WidgetState.qsView = "settings"
    readonly property var preferences: DisplayColor.preferences

    StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight

        ColumnLayout {
            id: content
            width: parent.width - Metrics.spacingS
            spacing: Metrics.spacingL

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
                flat: true
                enabled: DisplayColor.ready && DisplayColor.available

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
                    title: qsTr("Night temperature")
                    enabled: root.preferences.nightEnabled
                    from: 1000
                    to: 6500
                    stepSize: 100
                    suffix: " K"
                    value: root.preferences.nightTemperature
                    onMoved: value => DisplayColor.setPreference("nightTemperature", value)
                }
                SettingsRow {
                    Layout.fillWidth: true
                    visible: root.preferences.nightEnabled && root.preferences.mode !== "fixed"
                    title: qsTr("Scheduled temperature")
                    iconName: "schedule"
                    trailing: Text {
                        text: qsTr("%1 K").arg(DisplayColor.schedule.temperature)
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.bodyMedium.family
                        font.pixelSize: Typography.bodyMedium.pixelSize
                    }
                }
            }
            SettingsSection {
                Layout.fillWidth: true
                flat: true
                enabled: DisplayColor.ready && DisplayColor.available

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
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: root.preferences.nightEnabled && DisplayColor.scheduleWarning !== ""
                message: DisplayColor.scheduleWarning
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                readonly property var failedOutputs: DisplayColor.outputs.filter(output => output.state
                                                                                           === "failed"
                                                                                           || output.state
                                                                                           === "unavailable")
                visible: DisplayColor.available && failedOutputs.length > 0
                tone: "error"
                message: qsTr("Gamma control unavailable: %1").arg(failedOutputs.map(output
                                                                                     => output.name).join(
                                                                       ", "))
            }
        }
    }
}
