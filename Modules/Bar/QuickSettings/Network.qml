import QtQuick
import qs.Services
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    property bool vertical: false
    readonly property bool active: WidgetState.qsOpen && WidgetState.qsView === "network"
    readonly property real baseSize: Sizes.barControlCircleSize
    readonly property bool hasSsid: NetworkService.activeConnection.length > 0
    readonly property real expandedWidth: Math.max(root.baseSize, 18 + 6 + ssidMetrics.width + 20)
    property real expansionProgress: !root.vertical && root.hasSsid && horizontalButton.pointerHovered ? 1 : 0
    readonly property string tooltipText: NetworkService.connected ? ((NetworkService.activeConnection || qsTr(
                                                                           "Network connected")) + qsTr(
                                                                          "\nClick to open network settings")) :
                                                                     qsTr("Network disconnected\nClick to open network settings")
    readonly property string networkIcon: {
        if (NetworkService.activeConnectionType === "ETHERNET")
            return "settings_ethernet";

        if (!NetworkService.connected)
            return "wifi_off";

        const strength = Number(NetworkService.signalStrength || 0);
        if (strength >= 80)
            return "signal_wifi_4_bar";

        if (strength >= 60)
            return "network_wifi_3_bar";

        if (strength >= 40)
            return "network_wifi_2_bar";

        if (strength >= 20)
            return "network_wifi_1_bar";

        return "signal_wifi_0_bar";
    }

    function toggleNetworkView() {
        if (root.screen && root.screen.name)
            WidgetState.qsScreenName = root.screen.name;

        if (root.active) {
            WidgetState.qsOpen = false;
        } else {
            WidgetState.qsView = "network";
            WidgetState.qsOpen = true;
        }
    }

    implicitWidth: root.vertical ? root.baseSize : root.baseSize + (root.expandedWidth - root.baseSize)
                                   * root.expansionProgress
    implicitHeight: root.baseSize

    TextMetrics {
        id: ssidMetrics

        text: NetworkService.activeConnection
        font.family: Fonts.ui
        font.pixelSize: 12
        font.bold: true
    }

    BarCircularButton {
        id: verticalButton

        anchors.centerIn: parent
        visible: root.vertical
        enabled: root.enabled
        selected: root.active
        iconName: root.networkIcon
        containerColor: Appearance.colors.colPrimaryContainer
        rippleColor: Appearance.colors.colOnPrimaryContainer
        iconColor: Appearance.colors.colOnPrimaryContainer
        tooltipText: root.tooltipText
        onClicked: root.toggleNetworkView()
    }

    RippleButton {
        id: horizontalButton

        anchors.fill: parent
        visible: !root.vertical
        enabled: root.enabled
        toggled: root.active
        buttonRadius: height / 2
        containerColor: Appearance.colors.colPrimaryContainer
        rippleColor: Appearance.colors.colOnPrimaryContainer
        stateLayerEnabled: false
        releaseAction: () => {
            return root.toggleNetworkView();
        }

        contentItem: Item {
            anchors.fill: parent

            Row {
                anchors.centerIn: parent
                height: 18
                spacing: 6 * root.expansionProgress

                MaterialSymbol {
                    width: 18
                    height: 18
                    text: root.networkIcon
                    iconSize: 18
                    fill: 0
                    color: Appearance.colors.colOnPrimaryContainer
                }

                Item {
                    width: ssidMetrics.width * root.expansionProgress
                    height: 18
                    clip: true

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: ssidMetrics.width
                        text: NetworkService.activeConnection
                        opacity: root.expansionProgress
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        font.bold: true
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
            }
        }
    }

    PopupToolTip {
        extraVisibleCondition: !root.vertical && horizontalButton.pointerHovered
        text: root.tooltipText
    }

    Behavior on expansionProgress {
        NumberAnimation {
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }
    }
}
