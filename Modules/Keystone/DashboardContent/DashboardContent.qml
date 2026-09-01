import QtQuick
import QtQuick.Layouts
import qs.Services

// Layout adapted from Caelestia Shell's dashboard composition (GPL-3.0).
Item {
    id: root

    property var screen: null
    readonly property var keyholeGlassItems: keyholeCardCarousel.blurBackgroundItems
    readonly property real clockColumnWidth: 160
    readonly property real profileColumnWidth: 392
    readonly property real layoutMargin: 32
    readonly property real layoutSpacing: 24
    readonly property real keyholeWidth: 340
    readonly property real keyholeLeftMargin: 30
    readonly property real keyholeCenterOffset: layoutMargin + clockColumnWidth + layoutSpacing + profileColumnWidth + layoutSpacing + keyholeLeftMargin - implicitWidth / 2

    signal closeRequested()
    signal avatarEditRequested()

    implicitWidth: 1040
    implicitHeight: 520

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.layoutMargin
        spacing: root.layoutSpacing

        DashboardClock {
            Layout.minimumWidth: root.clockColumnWidth
            Layout.preferredWidth: root.clockColumnWidth
            Layout.maximumWidth: root.clockColumnWidth
            Layout.fillHeight: true
        }

        ColumnLayout {
            Layout.minimumWidth: root.profileColumnWidth
            Layout.preferredWidth: root.profileColumnWidth
            Layout.maximumWidth: root.profileColumnWidth
            Layout.fillHeight: true
            spacing: 16

            UserCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                onAvatarEditRequested: root.avatarEditRequested()
            }

            CalendarCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            KeyholeCardCarousel {
                id: keyholeCardCarousel

                width: root.keyholeWidth
                anchors.left: parent.left
                anchors.leftMargin: root.keyholeLeftMargin
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                screen: root.screen
                visible: PersonalizationConfig.keystoneKeyholeCards.length > 0
            }

        }

    }

}
