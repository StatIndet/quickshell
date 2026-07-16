import QtQuick
import Qt5Compat.GraphicalEffects
import M3Shapes
import qs.Common
import qs.Components

// Adapted from Caelestia Shell's dashboard media card and CoverArt (GPL-3.0).
Item {
    id: root

    required property var player
    property bool active: false

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool isPlaying: hasPlayer && player.isPlaying
    readonly property string artUrl: hasPlayer && player.trackArtUrl
        ? player.trackArtUrl : ""
    readonly property string title: hasPlayer && player.trackTitle
        ? player.trackTitle : "No media"
    readonly property string album: hasPlayer && player.trackAlbum
        ? player.trackAlbum : "Unknown album"
    readonly property string artist: hasPlayer && player.trackArtist
        ? player.trackArtist : "Unknown artist"
    property real currentPosition: 0
    property real coverRotation: 360
    readonly property real progress: hasPlayer && player.length > 0
        ? Math.max(0, Math.min(1, currentPosition / player.length)) : 0

    function syncPosition() {
        currentPosition = hasPlayer ? Math.max(0, Number(player.position) || 0) : 0;
    }

    onPlayerChanged: syncPosition()
    Component.onCompleted: syncPosition()

    Timer {
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: root.active && root.hasPlayer
        onTriggered: root.syncPosition()
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true

        function onPositionChanged() { root.syncPosition(); }
        function onTrackTitleChanged() { root.syncPosition(); }
    }

    NumberAnimation on coverRotation {
        from: 360
        to: 0
        duration: 23500
        easing.type: Easing.Linear
        loops: Animation.Infinite
        running: true
        paused: !root.active || !root.isPlaying
    }

    component MetadataText: Text {
        id: metadataText

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        maximumLineCount: 1
        font.family: Sizes.fontFamily
        renderType: Text.NativeRendering
        textFormat: Text.PlainText

        Behavior on text {
            SequentialAnimation {
                NumberAnimation {
                    target: metadataText
                    property: "opacity"
                    to: 0
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }
                PropertyAction {}
                NumberAnimation {
                    target: metadataText
                    property: "opacity"
                    to: 1
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }
    }

    DashboardMediaProgress {
        id: mediaProgress

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 222
        height: 222
        progress: root.progress
        playing: root.isPlaying
        active: root.active
        foregroundColor: Appearance.colors.colPrimary
        trackColor: Appearance.colors.colSecondaryContainer
    }

    Item {
        id: coverContainer

        anchors.centerIn: mediaProgress
        width: 180
        height: 180

        Item {
            id: shapeWrapper

            anchors.fill: parent
            layer.enabled: true

            MaterialShape {
                anchors.centerIn: parent
                implicitSize: parent.width
                shape: MaterialShape.Cookie12Sided
                color: "white"
                rotation: root.coverRotation
            }
        }

        MaterialShape {
            anchors.centerIn: parent
            implicitSize: parent.width
            shape: MaterialShape.Cookie12Sided
            color: Appearance.colors.colSurfaceContainerHighest
            rotation: root.coverRotation
        }

        Image {
            id: coverImage

            anchors.fill: parent
            source: root.artUrl
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: coverImage
            maskSource: shapeWrapper
            cached: false
            opacity: coverImage.status === Image.Ready ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.expressiveDefaultEffects.duration
                    easing.type: Appearance.animation.expressiveDefaultEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: coverImage.status === Image.Null || coverImage.status === Image.Error
            text: coverImage.status === Image.Error ? "broken_image" : "art_track"
            iconSize: 56
            fill: 1
            color: Appearance.colors.colOnSurfaceVariant
        }

        MaterialSymbol {
            id: loadingIcon

            anchors.centerIn: parent
            visible: coverImage.status === Image.Loading
            text: "progress_activity"
            iconSize: 48
            color: Appearance.colors.colPrimary

            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 1200
                easing.type: Easing.Linear
                loops: Animation.Infinite
                running: loadingIcon.visible && root.active
            }
        }
    }

    Column {
        id: metadataColumn

        anchors.top: mediaProgress.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 16, 260)
        spacing: 4

        MetadataText {
            width: parent.width
            height: 24
            text: root.title
            color: Appearance.colors.colPrimary
            font.pixelSize: 18
            font.bold: true
        }

        MetadataText {
            width: parent.width
            height: 16
            text: root.album
            color: Appearance.colors.colOutline
            font.pixelSize: 12
        }

        MetadataText {
            width: parent.width
            height: 18
            text: root.artist
            color: Appearance.colors.colSecondary
            font.pixelSize: 13
        }
    }

    DashboardMediaControls {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(240, parent.width - 20)
        height: 44
        player: root.player
    }
}
