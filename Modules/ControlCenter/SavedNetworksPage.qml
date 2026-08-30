import QtQuick
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    signal detailRequested(var target)

    InlineStatusBanner {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: NetworkService.savedWifiProfiles.length === 0
        message: qsTr("没有已保存的 Wi-Fi 配置")
    }

    StyledListView {
        id: savedList

        anchors.fill: parent
        visible: NetworkService.savedWifiProfiles.length > 0
        model: NetworkService.savedWifiProfiles
        spacing: Metrics.spacingXS
        boundsBehavior: Flickable.StopAtBounds
        fasterTouchpadScroll: true
        showVerticalScrollBar: true
        animateMovement: true

        delegate: SettingsRow {
            id: savedRow

            required property var modelData

            width: ListView.view.width
            iconName: savedRow.modelData.networkConnected ? "wifi" : "signal_wifi_off"
            title: savedRow.modelData.ssid || savedRow.modelData.name
            supportingText: savedRow.modelData.name + (savedRow.modelData.autoconnect ? qsTr(" · 自动连接") : "") + (savedRow.modelData.networkConnected ? qsTr(" · 同名网络已连接") : "")
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
