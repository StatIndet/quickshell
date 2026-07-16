import QtQuick
import QtQuick.Layouts
import qs.Common

// Layout adapted from Caelestia Shell's dashboard composition (GPL-3.0).
Item {
    id: root

    signal closeRequested()
    signal avatarEditRequested()

    implicitWidth: 860
    implicitHeight: 520

    component FloatingHoleCard: Item {
        id: cardRoot

        default property alias content: innerContainer.data
        property real floatMargin: 10
        property real contentMargin: 14

        Rectangle {
            id: cardBackground

            anchors.fill: parent
            anchors.margins: cardRoot.floatMargin
            radius: 20
            color: Appearance.colors.colLayer0
        }

        Item {
            id: innerContainer

            anchors.fill: cardBackground
            anchors.margins: cardRoot.contentMargin
        }
    }

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

            FloatingHoleCard {
                width: 340
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                HoleCardCarousel {
                    anchors.fill: parent
                }
            }
        }
    }
}
