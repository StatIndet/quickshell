import QtQuick
import QtQuick.Layouts
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
        animateMovement: true
        showVerticalScrollBar: false

        delegate: Item {
            id: delegateRoot

            required property var modelData
            readonly property var normalActions: root.manager.normalActions(delegateRoot.modelData)
            readonly property bool hasDefaultAction: root.manager.defaultAction(delegateRoot.modelData) !== null
            readonly property bool hasExpiry: delegateRoot.modelData && delegateRoot.modelData.popupExpiresAt > 0
            property real expiryProgress: 0

            function sanitizedBody() {
                return (modelData ? modelData.body : "").replace(/<img\b[^>]*>/gi, "");
            }

            function restartProgress() {
                progressAnimation.stop();
                if (!delegateRoot.hasExpiry) {
                    delegateRoot.expiryProgress = 0;
                    return ;
                }
                const total = Math.max(1, delegateRoot.modelData.popupExpiresAt - delegateRoot.modelData.popupStartedAt);
                const remaining = Math.max(0, delegateRoot.modelData.popupExpiresAt - Date.now());
                delegateRoot.expiryProgress = Math.min(1, remaining / total);
                progressAnimation.duration = remaining;
                progressAnimation.restart();
            }

            width: ListView.view.width
            height: normalActions.length > 0 ? 104 : 64
            Component.onCompleted: restartProgress()
            onModelDataChanged: restartProgress()

            NumberAnimation {
                id: progressAnimation

                target: delegateRoot
                property: "expiryProgress"
                to: 0
                easing.type: Easing.Linear
            }

            MouseArea {
                anchors.fill: card
                enabled: delegateRoot.hasDefaultAction
                cursorShape: Qt.PointingHandCursor
                onClicked: root.manager.invokeDefaultAction(delegateRoot.modelData.notificationId)
            }

            RowLayout {
                id: card

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: progressTrack.top
                anchors.bottomMargin: 4
                spacing: 12

                NotificationVisual {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignTop
                    appIcon: delegateRoot.modelData ? delegateRoot.modelData.appIcon : ""
                    image: delegateRoot.modelData ? delegateRoot.modelData.image : ""
                    summary: delegateRoot.modelData ? delegateRoot.modelData.summary : ""
                    urgency: delegateRoot.modelData ? delegateRoot.modelData.urgency : ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    Text {
                        text: delegateRoot.modelData ? delegateRoot.modelData.summary : ""
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.bold: true
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: delegateRoot.sanitizedBody()
                        textFormat: Text.StyledText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: delegateRoot.normalActions.length > 0 ? 1 : 2
                        onLinkActivated: (link) => {
                            return Qt.openUrlExternally(link);
                        }
                    }

                    StyledFlickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        visible: delegateRoot.normalActions.length > 0
                        contentWidth: actionRow.implicitWidth
                        contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        showVerticalScrollBar: false

                        RowLayout {
                            id: actionRow

                            height: parent.height
                            spacing: 6

                            Repeater {
                                model: delegateRoot.normalActions

                                RippleButton {
                                    id: actionButton

                                    required property var modelData

                                    implicitHeight: 34
                                    implicitWidth: Math.max(64, actionLabel.implicitWidth + 24)
                                    buttonRadius: Appearance.rounding.full
                                    containerColor: "transparent"
                                    stateLayerColor: Appearance.colors.colOnSurfaceVariant
                                    hoverStateLayerOpacity: 0.08
                                    focusStateLayerOpacity: 0.1
                                    pressedStateLayerOpacity: 0.12
                                    rippleColor: Appearance.colors.colOnSurfaceVariant
                                    Accessible.name: actionButton.modelData.text
                                    onClicked: root.manager.invokeAction(actionButton.modelData)

                                    contentItem: Text {
                                        id: actionLabel

                                        text: actionButton.modelData.text
                                        color: Appearance.colors.colOnSurfaceVariant
                                        font.family: Fonts.ui
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                }

                            }

                        }

                    }

                }

                RippleButton {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignTop
                    buttonRadius: Appearance.rounding.full
                    containerColor: "transparent"
                    stateLayerColor: Appearance.colors.colOnSurfaceVariant
                    hoverStateLayerOpacity: 0.08
                    focusStateLayerOpacity: 0.1
                    pressedStateLayerOpacity: 0.12
                    rippleColor: Appearance.colors.colOnSurfaceVariant
                    Accessible.name: qsTr("关闭")
                    onClicked: root.manager.dismissPopup(delegateRoot.modelData.notificationId)

                    contentItem: Text {
                        text: "close"
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.materialSymbolsRounded
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                }

            }

            Rectangle {
                id: progressTrack

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: delegateRoot.hasExpiry ? 2 : 0
                radius: 1
                color: Appearance.colors.colLayer2
                visible: delegateRoot.hasExpiry

                Rectangle {
                    width: parent.width * delegateRoot.expiryProgress
                    height: parent.height
                    radius: parent.radius
                    color: Appearance.colors.colPrimary
                }

            }

        }

    }

}
