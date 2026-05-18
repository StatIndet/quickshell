import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Notifications
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property int delegateIndex: -1
    property var notificationObject
    property bool expanded: false
    property bool onlyNotification: false
    property real fontSize: 12
    property real padding: onlyNotification ? 0 : 8
    property real summaryElideRatio: 0.85
    property real dragConfirmThreshold: 70
    property real dismissOvershoot: notificationIcon.implicitWidth + 20
    property var dragHost
    property int parentDragIndex: dragHost ? dragHost.dragIndex : -1
    property real parentDragDistance: dragHost ? dragHost.dragDistance : 0
    property int dragIndexDiff: Math.abs(parentDragIndex - delegateIndex)
    property real xOffset: dragIndexDiff === 0 ? parentDragDistance
        : Math.abs(parentDragDistance) > dragConfirmThreshold ? 0
        : dragIndexDiff === 1 ? parentDragDistance * 0.3
        : dragIndexDiff === 2 ? parentDragDistance * 0.1
        : 0
    readonly property var notificationActions: notificationObject && notificationObject.actions ? notificationObject.actions : []
    readonly property string notificationUrgency: notificationObject ? notificationObject.urgency : NotificationUrgency.Normal.toString()

    implicitHeight: background.implicitHeight

    NotificationUtils { id: notifUtils }

    TextMetrics {
        id: summaryTextMetrics
        font.pixelSize: root.fontSize
        text: root.notificationObject ? root.notificationObject.summary : ""
    }

    function isCriticalUrgency(urgency) {
        return urgency === NotificationUrgency.Critical || urgency === NotificationUrgency.Critical.toString();
    }

    function processedBody() {
        const body = root.notificationObject ? root.notificationObject.body : "";
        const sourceName = root.notificationObject ? (root.notificationObject.appName || root.notificationObject.summary || "") : "";
        return notifUtils.processNotificationBody(body, sourceName).replace(/\n/g, "<br/>");
    }

    function destroyWithAnimation(left = false) {
        if (root.dragHost)
            root.dragHost.resetDrag();
        dragManager.resetDrag();
        background.anchors.leftMargin = background.anchors.leftMargin;
        destroyAnimation.left = left;
        destroyAnimation.running = true;
    }

    SequentialAnimation {
        id: destroyAnimation
        property bool left: true
        running: false

        NumberAnimation {
            target: background.anchors
            property: "leftMargin"
            to: (root.width + root.dismissOvershoot) * (destroyAnimation.left ? -1 : 1)
            duration: Appearance.animation.expressiveDefaultSpatial.duration
            easing.type: Appearance.animation.expressiveDefaultSpatial.type
            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
        }

        onFinished: {
            if (root.notificationObject)
                NotificationManager.discardNotification(root.notificationObject.notificationId);
        }
    }

    DragManager {
        id: dragManager
        anchors.fill: root
        anchors.leftMargin: root.expanded ? -notificationIcon.implicitWidth : 0
        interactive: root.expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                root.destroyWithAnimation();
        }

        onDraggingChanged: {
            if (dragging && root.dragHost)
                root.dragHost.dragIndex = root.delegateIndex;
        }

        onDragDiffXChanged: {
            if (root.dragHost)
                root.dragHost.dragDistance = dragDiffX;
        }

        onDragReleased: (diffX) => {
            if (Math.abs(diffX) > root.dragConfirmThreshold) {
                root.destroyWithAnimation(diffX < 0);
            } else {
                dragManager.resetDrag();
                if (root.dragHost)
                    root.dragHost.resetDrag();
            }
        }
    }

    NotificationAppIcon {
        id: notificationIcon
        opacity: (!root.onlyNotification && root.notificationObject && root.notificationObject.image !== "" && root.expanded) ? 1 : 0
        visible: opacity > 0
        image: root.notificationObject ? root.notificationObject.image : ""
        appIcon: root.notificationObject ? root.notificationObject.appIcon : ""
        summary: root.notificationObject ? root.notificationObject.summary : ""
        urgency: root.notificationUrgency
        anchors.right: background.left
        anchors.top: background.top
        anchors.rightMargin: 10

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }
    }

    Rectangle {
        id: background

        width: parent.width
        anchors.left: parent.left
        anchors.leftMargin: root.xOffset
        radius: Appearance.rounding.small
        color: (root.expanded && !root.onlyNotification)
            ? (root.isCriticalUrgency(root.notificationUrgency)
                ? Appearance.mix(Appearance.colors.colSecondaryContainer, Appearance.colors.colLayer2, 0.35)
                : Appearance.colors.colLayer3)
            : Appearance.transparentize(Appearance.colors.colLayer3, 1)
        implicitHeight: root.expanded
            ? contentColumn.implicitHeight + root.padding * 2
            : summaryRow.implicitHeight

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging && !destroyAnimation.running
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: root.expanded ? root.padding : 0
            spacing: 3

            Behavior on anchors.margins {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }
            }

            RowLayout {
                id: summaryRow
                visible: !root.onlyNotification || !root.expanded
                Layout.fillWidth: true
                implicitHeight: summaryText.implicitHeight

                Text {
                    id: summaryText
                    Layout.fillWidth: summaryTextMetrics.width >= summaryRow.implicitWidth * root.summaryElideRatio
                    visible: !root.onlyNotification
                    text: root.notificationObject ? root.notificationObject.summary : ""
                    font.family: Sizes.fontFamily
                    font.pixelSize: root.fontSize
                    font.bold: true
                    color: Appearance.colors.colOnLayer3
                    elide: Text.ElideRight
                }

                Text {
                    opacity: !root.expanded ? 1 : 0
                    visible: opacity > 0
                    Layout.fillWidth: true
                    text: root.processedBody()
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    font.family: Sizes.fontFamily
                    font.pixelSize: root.fontSize
                    color: Appearance.colors.colSubtext

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveFastEffects.duration
                            easing.type: Appearance.animation.expressiveFastEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                        }
                    }
                }
            }

            ColumnLayout {
                id: expandedContentColumn
                Layout.fillWidth: true
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: `<style>img{max-width:${expandedContentColumn.width}px;}</style>${root.processedBody()}`
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    font.family: Sizes.fontFamily
                    font.pixelSize: root.fontSize
                    color: Appearance.colors.colSubtext

                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                }

                Item {
                    Layout.fillWidth: true
                    implicitWidth: actionsFlickable.implicitWidth
                    implicitHeight: actionsFlickable.implicitHeight

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: actionsFlickable.width
                            height: actionsFlickable.height
                            radius: Appearance.rounding.small
                        }
                    }

                    StyledFlickable {
                        id: actionsFlickable
                        anchors.fill: parent
                        implicitHeight: actionRowLayout.implicitHeight
                        contentWidth: actionRowLayout.implicitWidth
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick
                        showVerticalScrollBar: false
                        smoothWheelEnabled: false

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                                easing.type: Appearance.animation.expressiveFastEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                            }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                                easing.type: Appearance.animation.expressiveFastEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                            }
                        }

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                                easing.type: Appearance.animation.expressiveFastEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                            }
                        }

                        RowLayout {
                            id: actionRowLayout
                            Layout.alignment: Qt.AlignBottom
                            spacing: 6

                            NotificationActionButton {
                                Layout.fillWidth: true
                                buttonText: root.notificationActions.length === 0 ? "Close" : ""
                                iconName: root.notificationActions.length === 0 ? "" : "close"
                                urgency: root.notificationUrgency
                                onClicked: root.destroyWithAnimation()
                            }

                            Repeater {
                                model: root.notificationActions

                                NotificationActionButton {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    buttonText: modelData.text
                                    urgency: root.notificationUrgency
                                    onClicked: {
                                        if (root.notificationObject)
                                            NotificationManager.attemptInvokeAction(root.notificationObject.notificationId, modelData.identifier);
                                    }
                                }
                            }

                            NotificationActionButton {
                                id: copyButton
                                Layout.fillWidth: true
                                iconName: "content_copy"
                                urgency: root.notificationUrgency
                                onClicked: {
                                    Quickshell.clipboardText = root.notificationObject ? root.notificationObject.body : "";
                                    copyButton.iconName = "inventory";
                                    copyIconTimer.restart();
                                }

                                Timer {
                                    id: copyIconTimer
                                    interval: 1500
                                    repeat: false
                                    onTriggered: copyButton.iconName = "content_copy"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
