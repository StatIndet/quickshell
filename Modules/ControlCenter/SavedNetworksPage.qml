import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    signal detailRequested(var target)

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: NetworkService.savedWifiProfiles.length === 0
            message: qsTr("没有已保存的 Wi-Fi 配置")
        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            visible: NetworkService.savedWifiProfiles.length > 0
            title: qsTr("已保存的 Wi-Fi 配置")
            iconName: "bookmark"

            Repeater {
                model: NetworkService.savedWifiProfiles

                SettingsRow {
                    id: savedRow

                    required property var modelData

                    Layout.fillWidth: true
                    iconName: modelData.networkConnected ? "wifi" : "signal_wifi_off"
                    title: modelData.ssid || modelData.name
                    supportingText: modelData.name + (modelData.autoconnect ? qsTr(" · 自动连接") : "") + (modelData.networkConnected ? qsTr(" · 同名网络已连接") : "")
                    interactive: true
                    highlighted: false
                    onClicked: root.detailRequested(savedRow.modelData)

                    trailing: MaterialSymbol {
                        text: "chevron_right"
                        iconSize: Metrics.iconS
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                }

            }

        }

    }

}
