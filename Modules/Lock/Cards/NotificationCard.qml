import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    property bool compact: false
    property bool veryCompact: false
    readonly property var notifications: NotificationManager.list.slice().sort((a, b) => {
        return b.time - a.time;
    })
    readonly property int notificationCount: notifications.length
    readonly property int cardMargin: Metrics.lockOuterPadding

    function normalizeSource(source) {
        if (!source || source === "")
            return "";

        if (source.startsWith("/"))
            return "file://" + source;

        return source;
    }

    function iconSourceFor(notificationObject) {
        if (!notificationObject)
            return "";

        if (notificationObject.image && notificationObject.image !== "")
            return normalizeSource(notificationObject.image);

        if (notificationObject.appIcon && notificationObject.appIcon !== "") {
            if (notificationObject.appIcon.startsWith("/") || notificationObject.appIcon.startsWith("file://"))
                return normalizeSource(notificationObject.appIcon);

            return Quickshell.iconPath(notificationObject.appIcon, "image-missing");
        }
        return "";
    }

    function formatTime(timestamp) {
        const date = new Date(Number(timestamp));
        if (isNaN(date.getTime()))
            return "";

        const now = new Date();
        if (date.toDateString() === now.toDateString())
            return UiPreferences.shortTime(date);

        return Qt.formatDate(date, "MM/dd") + " " + UiPreferences.shortTime(date);
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    color: Appearance.colors.colLayer2
    radius: Metrics.lockCardRadius
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.cardMargin
        spacing: Metrics.spacingM

        Text {
            Layout.fillWidth: true
            text: root.notificationCount > 0 ? qsTr("%1 条通知").arg(root.notificationCount) : qsTr("通知")
            color: Appearance.colors.colOutline
            font.family: Fonts.numeric
            font.pixelSize: 17
            font.weight: 500
            elide: Text.ElideRight
        }

        Item {
            id: clipRect

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: !root.veryCompact

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: Metrics.spacingXL
                opacity: root.notificationCount > 0 ? 0 : 1
                scale: root.notificationCount > 0 ? 0.96 : 1
                visible: opacity > 0

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(clipRect.width * 0.8, 360)
                    Layout.preferredHeight: width * 868 / 1984

                    Image {
                        id: dinoImage

                        anchors.fill: parent
                        source: Paths.fileUrl(Paths.imagesDir + "/dino.png")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: false
                    }

                    ColorOverlay {
                        anchors.fill: dinoImage
                        source: dinoImage
                        color: Appearance.colors.colOutlineVariant
                    }

                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("没有通知")
                    color: Appearance.colors.colOutlineVariant
                    font.family: Fonts.numeric
                    font.pixelSize: 24
                    font.weight: 500
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.standardExtraLarge.duration
                        easing.type: Appearance.animation.standardExtraLarge.type
                        easing.bezierCurve: Appearance.animation.standardExtraLarge.bezierCurve
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveDefaultSpatial.duration
                        easing.type: Appearance.animation.expressiveDefaultSpatial.type
                        easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                    }

                }

            }

            StyledListView {
                id: listView

                anchors.fill: parent
                visible: root.notificationCount > 0
                clip: true
                spacing: Metrics.spacingS
                animateMovement: true
                model: root.notifications

                delegate: Rectangle {
                    id: delegateRoot

                    required property var modelData
                    readonly property string iconSource: root.iconSourceFor(modelData)

                    width: ListView.view ? ListView.view.width : 0
                    height: Math.max(84, contentRow.implicitHeight + 14)
                    radius: Metrics.lockCardRadiusSmall
                    color: Appearance.colors.colLayer3

                    RowLayout {
                        id: contentRow

                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            Layout.alignment: Qt.AlignTop
                            radius: 18
                            color: Appearance.colors.colLayer4
                            clip: true

                            Image {
                                id: iconImg

                                anchors.fill: parent
                                anchors.margins: delegateRoot.modelData && delegateRoot.modelData.image ? 0 : 8
                                source: delegateRoot.iconSource
                                fillMode: delegateRoot.modelData && delegateRoot.modelData.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                visible: delegateRoot.iconSource !== "" && status !== Image.Error
                                asynchronous: true
                                smooth: true
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "notifications"
                                visible: !iconImg.visible
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Fonts.materialSymbolsRounded
                                font.pixelSize: 27
                            }

                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: delegateRoot.modelData ? delegateRoot.modelData.appName : ""
                                    color: Appearance.colors.colPrimary
                                    font.family: Fonts.numeric
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: delegateRoot.modelData ? root.formatTime(delegateRoot.modelData.time) : ""
                                    color: Appearance.colors.colOnSurfaceVariant
                                    font.family: Fonts.numeric
                                    font.pixelSize: 13
                                    opacity: 0.7
                                }

                                Item {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "close"
                                        color: Appearance.colors.colOnSurfaceVariant
                                        font.family: Fonts.materialSymbolsRounded
                                        font.pixelSize: 14
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        opacity: closeMouse.containsMouse ? 1 : 0.7
                                    }

                                    MouseArea {
                                        id: closeMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NotificationManager.discardNotification(delegateRoot.modelData.notificationId)
                                    }

                                }

                            }

                            Text {
                                text: delegateRoot.modelData ? delegateRoot.modelData.summary : ""
                                color: Appearance.colors.colOnSurface
                                font.family: Fonts.ui
                                font.pixelSize: 17
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: delegateRoot.modelData ? delegateRoot.modelData.body : ""
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Fonts.ui
                                font.pixelSize: 16
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                maximumLineCount: 2
                                visible: !root.compact
                                opacity: 0.8
                            }

                        }

                    }

                }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }

                        NumberAnimation {
                            property: "scale"
                            from: 0.92
                            to: 1
                            duration: Appearance.animation.expressiveDefaultSpatial.duration
                            easing.type: Appearance.animation.expressiveDefaultSpatial.type
                            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                        }

                    }

                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }

                        NumberAnimation {
                            property: "scale"
                            to: 0.6
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }

                    }

                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Appearance.animation.expressiveDefaultSpatial.duration
                        easing.type: Appearance.animation.expressiveDefaultSpatial.type
                        easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                    }

                }

            }

        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.veryCompact
            text: root.notificationCount > 0 ? qsTr("%1 条通知").arg(root.notificationCount) : qsTr("没有通知")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Fonts.numeric
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

    }

}
