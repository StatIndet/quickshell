pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

TopBarPill {
    id: root

    property bool vertical: false
    property string edge: PersonalizationConfig.barPosition
    property real maximumTitleWidth: 180
    readonly property var player: MediaManager.active
    readonly property string title: player ? player.trackTitle || player.identity || qsTr("No media") : qsTr(
                                                 "No media")
    implicitWidth: vertical ? root.pillThickness : layout.implicitWidth + 2 * root.pillPadding
    implicitHeight: vertical ? layout.implicitHeight + 2 * root.pillPadding : root.pillThickness

    GridLayout {
        id: layout

        anchors.centerIn: parent
        columns: root.vertical ? 1 : 5
        rowSpacing: Sizes.barItemSpacing
        columnSpacing: Sizes.barItemSpacing

        Item {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: Sizes.barControlCircleSize
            Layout.preferredHeight: Sizes.barControlCircleSize
            MediaSourceIcon {
                anchors.centerIn: parent
                width: Sizes.barIconSize
                height: Sizes.barIconSize
                player: root.player
            }
        }

        MediaButton {
            iconName: "skip_previous"
            accessibleName: qsTr("Previous track")
            enabled: root.player !== null && root.player.canGoPrevious
            onClicked: root.player.previous()
        }

        MediaButton {
            iconName: root.player && root.player.isPlaying ? "pause" : "play_arrow"
            accessibleName: root.player && root.player.isPlaying ? qsTr("Pause") : qsTr("Play")
            enabled: root.player !== null && root.player.canTogglePlaying
            iconColor: BarColors.selected
            onClicked: root.player.togglePlaying()
        }

        MediaButton {
            iconName: "skip_next"
            accessibleName: qsTr("Next track")
            enabled: root.player !== null && root.player.canGoNext
            onClicked: root.player.next()
        }

        Item {
            id: titleSlot

            readonly property real titleExtent: Math.min(Math.max(0, root.maximumTitleWidth),
                                                         titleText.implicitWidth)
            implicitWidth: root.vertical ? 28 : titleExtent
            implicitHeight: root.vertical ? titleExtent : 28
            Layout.alignment: Qt.AlignCenter

            Item {
                id: titleViewport

                anchors.centerIn: parent
                width: titleSlot.titleExtent
                height: 28
                rotation: root.vertical ? (root.edge === "left" ? -90 : 90) : 0
                clip: true
                readonly property bool overflowing: titleText.implicitWidth > width

                onWidthChanged: restartScroll()
                Component.onCompleted: restartScroll()

                function restartScroll() {
                    titleScroll.stop();
                    titleStrip.x = 0;
                    if (overflowing && root.visible)
                        titleScroll.start();
                }

                Item {
                    id: titleStrip

                    height: parent.height
                    width: titleText.implicitWidth

                    Text {
                        id: titleText

                        anchors.verticalCenter: parent.verticalCenter
                        text: root.title
                        textFormat: Text.PlainText
                        font.family: Fonts.ui
                        font.pointSize: 11
                        color: BarColors.foreground
                        onTextChanged: Qt.callLater(titleViewport.restartScroll)
                        onImplicitWidthChanged: Qt.callLater(titleViewport.restartScroll)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: titleText.implicitWidth + 32
                        text: root.title
                        textFormat: Text.PlainText
                        font: titleText.font
                        color: titleText.color
                        visible: titleViewport.overflowing
                    }
                }

                Connections {
                    target: root
                    function onVisibleChanged() {
                        titleViewport.restartScroll();
                    }
                }

                SequentialAnimation {
                    id: titleScroll

                    loops: Animation.Infinite
                    PropertyAction {
                        target: titleStrip
                        property: "x"
                        value: 0
                    }
                    PauseAnimation {
                        duration: 1200
                    }
                    NumberAnimation {
                        target: titleStrip
                        property: "x"
                        from: 0
                        to: -(titleText.implicitWidth + 32)
                        duration: (titleText.implicitWidth + 32) * 35
                        easing.type: Easing.Linear
                    }
                }
            }

            HoverHandler {
                id: titleHover
            }

            StyledToolTip {
                text: root.title
                extraVisibleCondition: titleHover.hovered && titleViewport.overflowing
            }
        }
    }

    component MediaButton: IconButton {
        Layout.alignment: Qt.AlignCenter
        iconColor: BarColors.foreground
        selectedIconColor: BarColors.selected
        controlSize: Sizes.barControlCircleSize
        iconSize: Sizes.barIconSize
        opacity: enabled ? 1 : 0.35
    }
}
