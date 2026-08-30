import QtQuick
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    signal detailRequested(var target)

    Rectangle {
        anchors.fill: parent
        radius: Metrics.cornerL
        color: Appearance.colors.colLayer1
    }

    InlineStatusBanner {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Metrics.cardPadding
        radius: Metrics.cornerM
        visible: NetworkService.savedWifiProfiles.length === 0
        message: qsTr("没有已保存的网络")
    }

    StyledListView {
        id: savedList

        anchors.fill: parent
        anchors.margins: Metrics.spacingS
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
            readonly property string profileName: String(savedRow.modelData.name || "")
            readonly property string networkName: String(savedRow.modelData.ssid || savedRow.profileName)
            readonly property string secondaryText: {
                const details = [];
                if (savedRow.profileName.length > 0 && savedRow.profileName !== savedRow.networkName)
                    details.push(savedRow.profileName);

                if (savedRow.modelData.autoconnect)
                    details.push(qsTr("自动连接"));

                return details.join(" · ");
            }

            width: ListView.view.width
            iconName: "bookmark"
            title: savedRow.networkName
            supportingText: savedRow.secondaryText
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
