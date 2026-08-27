import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var manager
    // Активно ли поле ответа (раскрыто по hover) — KeystoneSurface отдаёт
    // клавиатурный фокус слою, чтобы можно было печатать ответ.
    property bool replyActive: false
    // Фактическая высота содержимого (сумма делегатов) — KeystoneSurface
    // использует её для динамической высоты попапа при hover-раскрытии.
    readonly property real contentHeight: notifList.contentHeight

    visible: !UiPreferences.dndEnabled && manager.hasNotifs

    StyledListView {
        id: notifList

        anchors.fill: parent
        model: root.manager.popupList
        spacing: 10
        clip: true
        interactive: false
        animateMovement: true
        showVerticalScrollBar: false

        delegate: Rectangle {
            id: delegateRoot

            required property var modelData
            readonly property string imageSource: modelData && modelData.image ? modelData.image : ""
            readonly property string appIconSource: modelData && modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, "image-missing") : ""
            readonly property string iconSource: imageSource !== "" ? imageSource : appIconSource
            readonly property bool hasImage: imageSource !== ""
            readonly property bool hasIcon: iconSource !== ""
            readonly property bool isCritical: modelData && modelData.urgency === NotificationUrgency.Critical.toString()
            readonly property bool isLow: modelData && modelData.urgency === NotificationUrgency.Low.toString()
            // Расширение по наведению: показываем действия, приостанавливаем таймер.
            // HoverHandler вместо MouseArea: не конфликтует с вложенными
            // MouseArea (RippleButton) и не создаёт цикл свернуть/развернуть.
            readonly property bool hovered: hoverHandler.hovered
            readonly property bool expanded: hovered
            readonly property int baseHeight: 60
            readonly property int expandedHeight: expanded ? Math.max(baseHeight, actionsColumn.implicitHeight + 46) : baseHeight
            readonly property bool hasActions: modelData && modelData.actions && modelData.actions.length > 0
            readonly property bool canReply: modelData && modelData.hasInlineReply

            width: ListView.view.width
            height: delegateRoot.expandedHeight
            color: delegateRoot.expanded ? Appearance.colors.colSurfaceContainerLow : "transparent"
            radius: Appearance.rounding.normal
            // При раскрытии с полем ответа — передать фокус вводу,
            // чтобы можно было печатать без клика по полю.
            // При сворачивании — снять фокус с поля, чтобы не удерживать
            // клавиатуру за Keystone.
            onExpandedChanged: {
                if (expanded && canReply) {
                    root.replyActive = true;
                    Qt.callLater(() => {
                        return replyInput.forceActiveFocus();
                    });
                } else {
                    root.replyActive = false;
                    replyInput.focus = false;
                }
            }
            // Критично: если делегат уничтожен (ответ отправлен, попап закрыт,
            // уведомление истекло), не оставлять клавиатурный фокус захваченным —
            // иначе Keystone навсегда удержит ввод и другие приложения
            // не смогут печатать.
            Component.onDestruction: root.replyActive = false

            HoverHandler {
                id: hoverHandler

                onHoveredChanged: {
                    if (!modelData)
                        return ;

                    if (hovered)
                        root.manager.cancelTimeout(modelData.notificationId);
                    else
                        root.manager.resumeTimeout(modelData.notificationId);
                }
            }

            MouseArea {
                id: hoverArea

                anchors.fill: parent
                // Клик по телу = активация приложения (стандарт freedesktop: default action).
                // Кнопки и поле ответа выше по z-order — получают клики раньше.
                onClicked: {
                    if (modelData)
                        root.manager.invokeDefaultAction(modelData.notificationId);

                }
            }

            RowLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
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
                        font.family: Fonts.materialSymbolsRounded
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
                        font.family: Fonts.ui
                        font.bold: true
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: delegateRoot.modelData ? delegateRoot.modelData.body : ""
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        visible: !delegateRoot.expanded || !delegateRoot.hasActions && !delegateRoot.canReply
                    }

                }

                // Закрыть — отдельная зона, чтобы не активировать приложение.
                MouseArea {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignTop
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (modelData)
                            root.manager.discardNotification(modelData.notificationId);

                    }

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        color: parent.containsMouse ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.materialSymbolsRounded
                        font.pixelSize: 18
                    }

                }

            }

            // Действия, раскрывающиеся по наведению.
            ColumnLayout {
                id: actionsColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 62
                anchors.rightMargin: 10
                anchors.bottomMargin: 8
                spacing: 8
                visible: delegateRoot.expanded && (delegateRoot.hasActions || delegateRoot.canReply)
                opacity: visible ? 1 : 0

                // Inline reply (напр. Telegram): поле быстрого ответа.
                RowLayout {
                    visible: delegateRoot.canReply
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1

                        TextInput {
                            id: replyInput

                            function sendReply() {
                                const text = replyInput.text.trim();
                                if (text === "" || !delegateRoot.modelData)
                                    return ;

                                root.manager.sendInlineReply(delegateRoot.modelData.notificationId, text);
                            }

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: 12
                            clip: true
                            selectByMouse: true
                            Keys.onReturnPressed: sendReply()
                            Keys.onEnterPressed: sendReply()

                            Text {
                                anchors.fill: parent
                                visible: replyInput.text === ""
                                verticalAlignment: Text.AlignVCenter
                                text: delegateRoot.modelData && delegateRoot.modelData.inlineReplyPlaceholder ? delegateRoot.modelData.inlineReplyPlaceholder : qsTr("回复")
                                color: Appearance.colors.colSubtext
                                font.family: Fonts.ui
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                        }

                    }

                    RippleButton {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 40
                        buttonRadius: Appearance.rounding.small
                        containerColor: Appearance.colors.colPrimaryContainer
                        stateLayerColor: Appearance.colors.colPrimaryContainerHover
                        pressedStateLayerColor: Appearance.colors.colPrimaryContainerActive
                        rippleColor: Appearance.colors.colOnPrimaryContainer
                        onClicked: replyInput.sendReply()

                        contentItem: Item {
                            implicitWidth: 24
                            implicitHeight: 24

                            Text {
                                anchors.centerIn: parent
                                text: "send"
                                font.family: Fonts.materialSymbolsRounded
                                font.pixelSize: 18
                                color: Appearance.colors.colOnPrimaryContainer
                            }

                        }

                    }

                }

                // Действия приложения (Reply / Mark as read / Open и т.п.).
                RowLayout {
                    visible: delegateRoot.hasActions
                    Layout.fillWidth: true
                    spacing: 6
                    layoutDirection: Qt.RightToLeft

                    Repeater {
                        model: delegateRoot.hasActions ? delegateRoot.modelData.actions : []

                        RippleButton {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            buttonRadius: Appearance.rounding.small
                            containerColor: delegateRoot.isCritical ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer4
                            stateLayerColor: delegateRoot.isCritical ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer4Hover
                            pressedStateLayerColor: delegateRoot.isCritical ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer4Active
                            rippleColor: delegateRoot.isCritical ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer4
                            onClicked: {
                                if (delegateRoot.modelData)
                                    root.manager.attemptInvokeAction(delegateRoot.modelData.notificationId, modelData.identifier);

                            }

                            contentItem: RowLayout {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: "arrow_forward"
                                    font.family: Fonts.materialSymbolsRounded
                                    font.pixelSize: 16
                                    color: delegateRoot.isCritical ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer4
                                }

                                Text {
                                    text: modelData.text
                                    font.family: Fonts.ui
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: delegateRoot.isCritical ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer4
                                    elide: Text.ElideRight
                                }

                            }

                        }

                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveDefaultEffects.duration
                        easing.type: Appearance.animation.expressiveDefaultEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                    }

                }

            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: 2
                radius: 1
                // Urgency-индикатор: Critical → error, Low → subtext, иначе primary.
                // Зеркалит цветовую схему NotificationItem.
                color: delegateRoot.isCritical ? Appearance.colors.colError : (delegateRoot.isLow ? Appearance.colors.colSubtext : Appearance.colors.colPrimary)

                NumberAnimation on width {
                    from: delegateRoot.width - 20
                    to: 0
                    duration: 5000
                    running: !delegateRoot.isCritical && !delegateRoot.hovered
                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                }

            }

        }

    }

}
