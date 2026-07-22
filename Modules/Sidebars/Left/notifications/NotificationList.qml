import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import M3Shapes
import qs.Common
import qs.Services

Rectangle {
    id: root

    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true

    NotificationListView {
        id: listView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: statusRow.top
        anchors.margins: 5
        anchors.bottomMargin: 8

        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: listView.width
                height: listView.height
                radius: Appearance.rounding.normal
            }
        }

        popup: false
    }

    Item {
        id: emptyState

        readonly property bool shown: NotificationManager.list.length === 0

        anchors.fill: listView
        anchors.topMargin: -30 * (1 - opacity)
        anchors.bottomMargin: 30 * (1 - opacity)
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.standard.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            MaterialShape {
                Layout.alignment: Qt.AlignHCenter
                implicitSize: 80
                shape: MaterialShape.Ghostish
                color: Appearance.colors.colSecondaryContainer
                rotation: -30 * (1 - emptyState.opacity)

                Text {
                    anchors.centerIn: parent
                    text: "notifications_active"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 42
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Nothing"
                font.family: Sizes.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    RowLayout {
        id: statusRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 5
        spacing: 5

        NotificationStatusButton {
            Layout.fillWidth: false
            buttonIcon: "notifications_paused"
            toggled: NotificationManager.silent
            onClicked: NotificationManager.setSilent(!NotificationManager.silent)
        }

        NotificationStatusButton {
            Layout.fillWidth: true
            enabled: false
            buttonText: `${NotificationManager.list.length} notifications`
        }

        NotificationStatusButton {
            Layout.fillWidth: false
            buttonIcon: "delete_sweep"
            onClicked: NotificationManager.discardAllNotifications()
        }
    }
}
