import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
        anchors.fill: listView
        opacity: NotificationManager.list.length === 0 ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultEffects.duration
                easing.type: Appearance.animation.expressiveDefaultEffects.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "notifications_active"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 34
                color: Appearance.colors.colOnSurfaceVariant
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing"
                font.family: Sizes.fontFamily
                font.pixelSize: 14
                font.bold: true
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
