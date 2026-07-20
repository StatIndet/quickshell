import QtQuick
import QtQuick.Layouts

// Layout adapted from Caelestia Shell's dashboard composition (GPL-3.0).
Item {
    id: root

    signal closeRequested()
    signal avatarEditRequested()

    property var player: null
    property var screen: null

    implicitWidth: 860
    implicitHeight: 520

    RowLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        ColumnLayout {
            Layout.minimumWidth: 392
            Layout.preferredWidth: 392
            Layout.maximumWidth: 392
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

            HoleCardCarousel {
                width: 340
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                player: root.player
                screen: root.screen
            }
        }
    }
}
