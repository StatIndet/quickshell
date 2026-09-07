import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    Component.onCompleted: BlurService.writeEffectsConfig()

    Connections {
        target: BlurService
        function onAvailableChanged() {
            if (BlurService.available)
                BlurService.writeEffectsConfig();
        }
    }

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("Background")
            iconName: "wallpaper"

            GeneralSliderSetting {
                title: qsTr("Background opacity")
                from: 0
                to: 100
                stepSize: 1
                suffix: "%"
                value: PersonalizationConfig.shellBackgroundOpacity * 100
                onMoved: value => PersonalizationConfig.setShellBackgroundOpacity(value / 100)
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "blur_on"
                title: qsTr("Background blur")

                trailing: StyledSwitch {
                    enabled: BlurService.available
                    checked: PersonalizationConfig.shellBlurEnabled
                    Accessible.name: qsTr("Background blur")
                    onToggled: PersonalizationConfig.setShellBlurEnabled(checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "filter_center_focus"
                title: qsTr("Blur wallpaper only")
                supportingText: BlurService.niriIntegrationReady ? qsTr(
                                                                       "Turning this off also blurs windows and uses more resources") :
                                                                   qsTr("Configure Niri blur integration first")

                trailing: StyledSwitch {
                    enabled: BlurService.available && BlurService.niriIntegrationReady
                    checked: PersonalizationConfig.shellBlurXray
                    Accessible.name: qsTr("Blur wallpaper only")
                    onToggled: PersonalizationConfig.setShellBlurXray(checked)
                }
            }

            SettingsActionRow {
                Layout.fillWidth: true
                visible: BlurService.available && !BlurService.niriIntegrationReady
                iconName: "settings"
                text: BlurService.integrationBusy ? qsTr("Configuring Niri integration…") : qsTr(
                                                        "Configure Niri integration")
                trailingIconName: "chevron_right"
                enabled: !BlurService.integrationBusy
                onClicked: BlurService.configureNiriIntegration()
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: BlurService.lastError !== ""
                tone: "error"
                message: BlurService.lastError
            }
        }
    }
}
