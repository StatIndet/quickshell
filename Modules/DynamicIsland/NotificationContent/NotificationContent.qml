import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var manager

    visible: !UiPreferences.dndEnabled && manager.hasNotifs

    StyledListView {
        anchors.fill: parent
        model: root.manager.popupList
        spacing: 10
        clip: true
        interactive: false
        showVerticalScrollBar: false

        delegate: Rectangle {
            id: delegateRoot

            required property var modelData

            width: ListView.view.width
            height: 60
            color: "transparent"

            readonly property string imageSource: modelData && modelData.image ? modelData.image : ""
            readonly property string appIconSource: modelData && modelData.appIcon ? IconResolver.resolveIcon(modelData.appIcon) : ""
            readonly property string iconSource: imageSource !== "" ? imageSource : appIconSource
            readonly property bool hasImage: imageSource !== ""
            readonly property bool hasIcon: iconSource !== ""

            Timer {
                interval: 5000
                running: true
                repeat: false
                onTriggered: root.manager.removeByNotifId(delegateRoot.modelData.notificationId)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.manager.removeByNotifId(delegateRoot.modelData.notificationId)
            }

            RowLayout {
                anchors.fill: parent
                anchors.bottomMargin: 4
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 10
                    color: Appearance.colors.colLayer0
                    clip: true

                    Image {
                        id: iconImage
                        anchors.fill: parent
                        anchors.margins: delegateRoot.hasImage ? 0 : 6
                        source: delegateRoot.iconSource
                        fillMode: delegateRoot.hasImage ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                        visible: delegateRoot.hasIcon && status !== Image.Error
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "chat"
                        visible: !iconImage.visible
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        text: delegateRoot.modelData ? delegateRoot.modelData.summary : ""
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.bold: true
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: delegateRoot.modelData ? delegateRoot.modelData.body : ""
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Sizes.fontFamily
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }
                }

                Text {
                    text: "close"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: 2
                radius: 1
                color: Appearance.colors.colPrimary

                NumberAnimation on width {
                    from: delegateRoot.width - 20
                    to: 0
                    duration: 5000
                }
            }
        }
    }
}
