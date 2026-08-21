import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris
import Clavis.Lyrics
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root
    
    implicitWidth: 720
    implicitHeight: 480
    
    required property var player
    
    property string artUrl: (player && player.trackArtUrl) ? player.trackArtUrl : ""
    property string title: (player && player.trackTitle) ? player.trackTitle : qsTr("未在播放")
    property string artist: (player && player.trackArtist) ? player.trackArtist : qsTr("未知艺术家")
    property string album: (player && player.trackAlbum) ? player.trackAlbum : ""
    readonly property bool isActive: root.visible && root.player
    property bool showLyrics: false 
    readonly property var lyricsModel: Lyrics.lyrics

    onShowLyricsChanged: {
        if (root.showLyrics)
            Qt.callLater(lyricsView.positionPlaybackLine);
    }

    readonly property string spectrumToken: "keystone-media"
    Component.onCompleted: {
        if (root.isActive)
            AudioSpectrum.acquire(root.spectrumToken);
        MediaPalette.extract(root.artUrl, Appearance.colors.colPrimary);
    }
    Component.onDestruction: AudioSpectrum.release(root.spectrumToken)

    Connections {
        target: root
        function onArtUrlChanged() {
            MediaPalette.extract(root.artUrl, Appearance.colors.colPrimary);
        }
    }

    property color dynamicThemeColor: MediaPalette.primary
    property color dynamicOnThemeColor: MediaPalette.onPrimary
    property color dynamicTrackColor: MediaPalette.track
    Behavior on dynamicThemeColor { ColorAnimation { duration: 800; easing.type: Easing.OutQuint } }
    Behavior on dynamicTrackColor { ColorAnimation { duration: 800; easing.type: Easing.OutQuint } }

    // MediaManager owns the single 250 ms MPRIS position tick. The lyric
    // index remains a pure projection of playback time, never of contentY.
    Connections {
        target: root
        function onIsActiveChanged() {
            if (root.isActive)
                AudioSpectrum.acquire(root.spectrumToken);
            else
                AudioSpectrum.release(root.spectrumToken);
        }
    }

    readonly property double currentPos: root.player && root.player === MediaManager.active
        ? MediaManager.currentPosition
        : (root.player ? Math.max(0, Number(root.player.position) || 0) : 0)
    readonly property bool synchronizedLyrics: Lyrics.hasSynchronizedLyrics
    readonly property int playbackIndex: {
        const lines = Lyrics.lyrics;
        if (!root.player || !root.synchronizedLyrics || !lines || lines.length === 0)
            return -1;
        return Lyrics.indexForTime(root.currentPos);
    }

    function formatTime(val) {
        let num = Number(val);
        if (isNaN(num) || num <= 0) return "0:00";
        let seconds = (num > 100000) ? Math.floor(num / (num > 100000000 ? 1000000 : 1000)) : Math.floor(num);
        let m = Math.floor(seconds / 60);
        let s = seconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
    property double realProgress: (player && player.length > 0) ? (currentPos / player.length) : 0

    // ==========================================
    // 界面渲染层
    // ==========================================
    Rectangle {
        id: mainBg
        anchors.fill: parent
        
        anchors.topMargin: 5
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        anchors.bottomMargin: 25 
 
        radius: 24 
        color: Appearance.colors.colLayer1

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: mainBg.width
                height: mainBg.height
                radius: mainBg.radius
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: bgSource
                anchors.centerIn: parent
                width: parent.width * 1.5
                height: parent.height * 1.5
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            MultiEffect {
                anchors.fill: bgSource
                source: bgSource
                visible: root.artUrl !== ""
                blurEnabled: true
                blur: 1.0
                blurMax: 80
                contrast: 0.2
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
            }
        }

        IconButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 16
            z: 10
            controlSize: 36
            iconName: "lyrics"
            iconSize: 18
            selected: root.showLyrics
            iconFill: root.showLyrics || pointerHovered || down ? 1 : 0
            iconColor: "white"
            selectedIconColor: "white"
            accessibleName: root.showLyrics
                ? qsTr("隐藏歌词") : qsTr("显示歌词")
            hoverStateLayerColor: Appearance.applyAlpha("white", 0.12)
            pressedStateLayerColor: Appearance.applyAlpha("white", 0.2)
            selectedHoverStateLayerColor:
                Appearance.applyAlpha("white", 0.12)
            selectedPressedStateLayerColor:
                Appearance.applyAlpha("white", 0.2)
            onClicked: root.showLyrics = !root.showLyrics
        }

        Item {
            id: stage
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: bottomControlPanel.top
            anchors.margins: 16

            state: root.showLyrics ? "LYRICS_OPEN" : "LYRICS_CLOSED"

            states: [
                State {
                    name: "LYRICS_CLOSED"
                    PropertyChanges { target: coverContainer; x: (stage.width - coverContainer.width) / 2; scale: 1.0 }
                    PropertyChanges { target: infoContainer; opacity: 1; visible: true }
                    PropertyChanges { target: lyricsContainer; x: stage.width + 50; opacity: 0; visible: false }
                },
                State {
                    name: "LYRICS_OPEN"
                    PropertyChanges { target: coverContainer; x: 40; scale: 0.9 }
                    PropertyChanges { target: infoContainer; opacity: 0; visible: false }
                    PropertyChanges { target: lyricsContainer; x: 280; opacity: 1; visible: true }
                }
            ]

            transitions: [
                Transition {
                    ParallelAnimation {
                        NumberAnimation { targets: [coverContainer, lyricsContainer]; properties: "x,scale"; duration: 600; easing.type: Easing.OutExpo }
                        NumberAnimation { targets: [infoContainer, lyricsContainer]; properties: "opacity"; duration: 400; easing.type: Easing.InOutQuad }
                    }
                }
            ]

            Item {
                id: coverContainer
                width: 220; height: 220
                y: 10 

                RadialSpectrum {
                    anchors.fill: parent
                    values: AudioSpectrum.values
                    barCount: AudioSpectrum.bars
                    innerRadius: 70
                    maxMagnitude: 36
                    strokeWidth: 4
                    strokeColor: root.dynamicThemeColor
                    valueScale: 1.08
                    opacity: root.isActive && AudioSpectrum.available ? 1 : 0.35

                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    width: 120; height: 120; radius: 60; color: "transparent"; anchors.centerIn: parent
                    Image {
                        id: artImg; anchors.fill: parent; source: root.artUrl !== "" ? root.artUrl : ""
                        fillMode: Image.PreserveAspectCrop; layer.enabled: true
                        layer.effect: OpacityMask { maskSource: Rectangle { width: artImg.width; height: artImg.height; radius: width / 2 } }
                    }
                    Text { anchors.centerIn: parent; text: "🎵"; font.pixelSize: 40; visible: root.artUrl === "" }
                }
            }

            ColumnLayout {
                id: infoContainer
                width: parent.width
                x: 0
                y: coverContainer.y + coverContainer.height - 8
                spacing: 2 

                Text { text: root.title; color: "white"; font.pixelSize: 20; font.bold: true; Layout.alignment: Qt.AlignHCenter; elide: Text.ElideRight; Layout.maximumWidth: root.width - 80 }
                Text { text: root.artist; color: "#cccccc"; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter; elide: Text.ElideRight; Layout.maximumWidth: root.width - 80 }
                Text { text: root.album; color: "#888888"; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter; elide: Text.ElideRight; Layout.maximumWidth: root.width - 80 }
            }

                Item {
                    id: lyricsContainer
                    width: stage.width - 280
                    height: 240
                    y: 10

                    Text {
                        id: firstLineMeasure

                        visible: false
                        width: lyricsView.width
                        text: root.lyricsModel && root.lyricsModel.length > 0
                            ? String(root.lyricsModel[0].text || "") : ""
                        font.family: Fonts.ui
                        font.pixelSize: 18
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        id: lastLineMeasure

                        visible: false
                        width: lyricsView.width
                        text: root.lyricsModel && root.lyricsModel.length > 0
                            ? String(root.lyricsModel[root.lyricsModel.length - 1].text || "") : ""
                        font.family: Fonts.ui
                        font.pixelSize: 18
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    StyledListView {
                        id: lyricsView

                        readonly property real minimumLineHeight: 34
                        readonly property real firstLineHeight: Math.max(
                            minimumLineHeight, firstLineMeasure.implicitHeight)
                        readonly property real lastLineHeight: Math.max(
                            minimumLineHeight, lastLineMeasure.implicitHeight)
                        readonly property real currentLineHeight: Math.max(
                            minimumLineHeight, currentItem ? currentItem.height : 0)
                        readonly property real leadingSpacerHeight: count > 0
                            ? Math.max(0, (height - firstLineHeight) / 2) : 0
                        readonly property real trailingSpacerHeight: count > 0
                            ? Math.max(0, (height - lastLineHeight) / 2) : 0

                        function positionPlaybackLine() {
                            const index = root.playbackIndex;
                            if (index >= 0 && index < count)
                                positionViewAtIndex(index, ListView.Center);
                        }

                        anchors.fill: parent
                        model: root.lyricsModel
                        interactive: true
                        showVerticalScrollBar: false
                        animateAppearance: false
                        animateMovement: false
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 8

                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: Math.max(0, (height - currentLineHeight) / 2)
                        preferredHighlightEnd: Math.min(height, (height + currentLineHeight) / 2)
                        highlightMoveDuration: Appearance.animation.expressiveDefaultSpatial.duration
                        highlightMoveVelocity: -1
                        highlightFollowsCurrentItem: true

                        currentIndex: root.playbackIndex

                        header: Item {
                            width: lyricsView.width
                            height: lyricsView.leadingSpacerHeight
                        }

                        footer: Item {
                            width: lyricsView.width
                            height: lyricsView.trailingSpacerHeight
                        }

                        Component.onCompleted: Qt.callLater(positionPlaybackLine)
                        onCountChanged: Qt.callLater(positionPlaybackLine)
                        onWidthChanged: Qt.callLater(positionPlaybackLine)
                        onHeightChanged: Qt.callLater(positionPlaybackLine)

                    delegate: Item {
                        id: lyricDelegate

                        required property int index
                        required property var modelData
                        readonly property bool activeLine: index === root.playbackIndex
                        readonly property int distance: root.playbackIndex < 0
                            ? 99 : Math.abs(index - root.playbackIndex)
                        readonly property bool hovered: hoverHandler.hovered

                        width: ListView.view.width
                        height: Math.max(34, lyricText.implicitHeight)
                        scale: !root.synchronizedLyrics
                            ? 1.0 : (hovered ? 1.01 : (activeLine ? 1.0 : 0.97))
                        opacity: !root.synchronizedLyrics
                            ? 0.82 : (activeLine ? 1.0 : (distance <= 2 ? 0.58 : 0.24))
                        transformOrigin: Item.Left

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveDefaultEffects.duration
                                easing.type: Appearance.animation.expressiveDefaultEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveDefaultEffects.bezierCurve
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveFastEffects.duration
                                easing.type: Appearance.animation.expressiveFastEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                id: lyricText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                text: modelData.text || ""
                                color: !root.synchronizedLyrics
                                    ? "#ddffffff"
                                    : (lyricDelegate.activeLine
                                    ? "white"
                                    : (lyricDelegate.hovered ? "#ddffffff" : "#99ffffff"))
                                font.family: Fonts.ui
                                font.pixelSize: 18
                                font.bold: true
                                horizontalAlignment: Text.AlignLeft
                                wrapMode: Text.WordWrap

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.animation.expressiveFastEffects.duration
                                        easing.type: Appearance.animation.expressiveFastEffects.type
                                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                                    }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                visible: modelData.translation !== undefined && modelData.translation !== ""
                                text: modelData.translation || ""
                                color: !root.synchronizedLyrics
                                    ? "#99ffffff"
                                    : (lyricDelegate.activeLine ? "#ddffffff" : "#77ffffff")
                                font.family: Fonts.ui
                                font.pixelSize: 13
                                font.bold: false
                                horizontalAlignment: Text.AlignLeft
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 2

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.animation.expressiveFastEffects.duration
                                        easing.type: Appearance.animation.expressiveFastEffects.type
                                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                                    }
                                }
                            }
                        }

                        HoverHandler {
                            id: hoverHandler
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: {
                                if (!root.player || root.player.canSeek !== true)
                                    return;
                                const target = Lyrics.timeForIndex(lyricDelegate.index);
                                if (target >= 0)
                                    root.player.position = target;
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: "#bbffffff"
                        font.family: Fonts.ui
                        font.pixelSize: 15
                        visible: Lyrics.status !== "ready"
                        text: Lyrics.status === "loading"
                            ? qsTr("正在加载歌词…")
                            : (Lyrics.status === "error"
                                ? (Lyrics.error || qsTr("歌词加载失败"))
                                : qsTr("暂无歌词"))
                    }
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: LinearGradient {
                        width: lyricsContainer.width
                        height: lyricsContainer.height
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" } 
                            GradientStop { position: 0.25; color: "black" }      
                            GradientStop { position: 0.75; color: "black" }      
                            GradientStop { position: 1.0; color: "transparent" } 
                        }
                    }
                }
            }
        }

        // --- 下半部分 (进度条和控制按钮) ---
        ColumnLayout {
            id: bottomControlPanel
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: 6

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 340 
                Layout.preferredHeight: 46 

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    MaterialWaveProgressBar {
                        id: mediaProgress
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        progress: root.realProgress
                        waveColor: root.dynamicThemeColor
                        trackColor: root.dynamicTrackColor
                        trackOpacity: 1.0
                        isPlaying: root.player ? root.player.isPlaying : false

                        onSeekRequested: (position) => {
                            if (root.player && root.player.length > 0) {
                                root.player.position = position * root.player.length;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: root.isActive ? root.formatTime(root.currentPos) : "0:00"; color: "#dddddd"; font.pixelSize: 12; font.family: Fonts.numeric }
                        Item { Layout.fillWidth: true }
                        Text { text: root.isActive ? root.formatTime(root.player.length) : "0:00"; color: "#dddddd"; font.pixelSize: 12; font.family: Fonts.numeric }
                    }
                }
            }

            Item { Layout.fillHeight: true; Layout.maximumHeight: 10 }

            MediaControlBar {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumHeight: 60
                spacing: 36
                isPlaying: root.player ? root.player.isPlaying : false
                shuffleActive: root.player && root.player.shuffle
                shuffleEnabled: root.player && root.player.shuffleSupported
                previousEnabled: root.player
                playPauseEnabled: root.player
                nextEnabled: root.player
                loopEnabled: root.player && root.player.loopSupported
                loopMode: !root.player || root.player.loopState === MprisLoopState.None
                    ? 0
                    : (root.player.loopState === MprisLoopState.Track ? 2 : 1)
                activeColor: root.dynamicThemeColor
                inactiveColor: "white"
                iconSize: 24
                skipIconSize: 24
                inactiveOpacity: 0.7
                disabledOpacity: 0.35
                playingBg: root.dynamicThemeColor
                playingFg: root.dynamicOnThemeColor
                pausedBg: root.dynamicThemeColor
                pausedFg: root.dynamicOnThemeColor
                playButtonSize: 60
                playIconSize: 28
                playPressedScale: 0.9
                playHoverScale: 1.05
                morphEnabled: true

                onShuffleClicked: if (root.player && root.player.shuffleSupported) root.player.shuffle = !root.player.shuffle
                onPreviousClicked: if (root.player) root.player.previous()
                onPlayPauseClicked: if (root.player) root.player.togglePlaying()
                onNextClicked: if (root.player) root.player.next()
                onLoopClicked: {
                    if (!root.player || !root.player.loopSupported)
                        return;
                    if (root.player.loopState === MprisLoopState.None)
                        root.player.loopState = MprisLoopState.Playlist;
                    else if (root.player.loopState === MprisLoopState.Playlist)
                        root.player.loopState = MprisLoopState.Track;
                    else
                        root.player.loopState = MprisLoopState.None;
                }
            }
        }
    }
}
