import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    readonly property bool isActive: root.visible && MediaManager.active
    property bool isPlaying: isActive && MediaManager.active && MediaManager.active.isPlaying

    property string artUrl: (isActive && MediaManager.active.trackArtUrl) ? MediaManager.active.trackArtUrl :
                                                                            ""

    property string title: (isActive && MediaManager.active.trackTitle) ? MediaManager.active.trackTitle :
                                                                          qsTr("No media")

    property string artist: (isActive && MediaManager.active.trackArtist) ? MediaManager.active.trackArtist :
                                                                            qsTr("Unknown artist")

    readonly property double currentPos: root.isActive ? MediaManager.currentPosition : 0

    readonly property bool hasDuration: isActive && Number.isFinite(MediaManager.active.length)
                                        && MediaManager.active.length > 0
    readonly property bool canSeek: hasDuration && MediaManager.active.canSeek
    readonly property double progress: hasDuration && Number.isFinite(root.currentPos) ? Math.max(0, Math.min(1,
                                                                                                              root.currentPos
                                                                                                              / MediaManager.active.length)) :
                                                                                         0
    readonly property bool caelestiaCover: PersonalizationConfig.keystoneMediaCoverStyle === "caelestia"
    readonly property real panelWidth: 440
    readonly property real panelHeight: 228
    readonly property bool backgroundCover: PersonalizationConfig.keystoneMediaCoverStyle === "background"
    readonly property bool coverColors: PersonalizationConfig.keystoneMediaColorStyle === "cover"
                                        && root.artUrl !== ""
    readonly property string paletteArtUrl: root.isActive && root.coverColors ? root.artUrl : ""
    readonly property color themePrimary: Appearance.colors.colPrimary
    readonly property color accentColor: coverColors ? MediaPalette.primary : Appearance.colors.colPrimary
    readonly property color onAccentColor: coverColors ? MediaPalette.onPrimary :
                                                         Appearance.colors.colOnPrimary
    readonly property color trackColor: coverColors ? MediaPalette.track : Appearance.colors.colLayer2Hover
    readonly property color surfaceColor: coverColors ? Qt.tint(Appearance.colors.colLayer0,
                                                                Appearance.applyAlpha(accentColor, 0.12)) :
                                                        Appearance.colors.colLayer0

    function updatePalette() {
        if (root.paletteArtUrl)
            MediaPalette.extract(root.paletteArtUrl, root.themePrimary);
    }

    function seek(position) {
        if (root.canSeek && Number.isFinite(position))
            MediaManager.active.position = Math.max(0, Math.min(1, position)) * MediaManager.active.length;
    }

    onPaletteArtUrlChanged: updatePalette()
    onThemePrimaryChanged: updatePalette()
    Component.onCompleted: updatePalette()

    function timeText(seconds) {
        const total = Number.isFinite(seconds) ? Math.max(0, Math.floor(seconds)) : 0;
        return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
    }

    Component {
        id: sineProgress
        WaveProgressBar {
            progress: root.progress
            waveColor: root.accentColor
            trackColor: root.trackColor
            isPlaying: root.isPlaying
            waveAmplitude: 6
            waveFrequency: 0.05
            progressGap: 10
            seekMargin: 0
            onSeekRequested: position => root.seek(position)
        }
    }

    Component {
        id: materialProgress
        MaterialWaveProgressBar {
            progress: root.progress
            waveColor: root.accentColor
            trackColor: root.trackColor
            trackOpacity: 1
            isPlaying: root.isPlaying
            seekMargin: 0
            onSeekRequested: position => root.seek(position)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            FlippingMediaCover {
                id: cover
                trackKey: root.isActive ? MediaManager.active.dbusName + ":" + MediaManager.active.uniqueId :
                                          ""
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                Layout.alignment: Qt.AlignVCenter
                artUrl: root.artUrl
                playing: root.isPlaying
                active: root.isActive
                caelestia: root.caelestiaCover
                accentColor: root.accentColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ScrollingLabel {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.title
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    MediaSpectrum {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 22
                        player: MediaManager.active
                        barColor: root.accentColor
                    }
                }

                ScrollingLabel {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.artist
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.ui
                    font.pixelSize: 13
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: root.hasDuration ? root.timeText(root.currentPos) : "–:––"
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.numeric
                font.pixelSize: 11
            }
            Loader {
                Layout.fillWidth: true
                Layout.minimumWidth: 20
                Layout.preferredHeight: 26
                active: root.visible
                enabled: root.canSeek
                sourceComponent: PersonalizationConfig.keystoneMediaProgressStyle === "material"
                                 ? materialProgress : sineProgress
            }
            Text {
                text: root.hasDuration ? "−" + root.timeText(MediaManager.active.length - root.currentPos) :
                                         "–:––"

                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.numeric
                font.pixelSize: 11
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 54

            MediaSourceIcon {
                fallbackIcon: "music_note_2"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                player: MediaManager.active
                Accessible.name: MediaManager.getIdentity(MediaManager.active)
            }

            Item {
                id: outputDevice
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                readonly property string description: Volume.ready && Volume.outputAvailable ? qsTr(
                                                                                                   "System default playback device: %1").arg(
                                                                                                   Volume.sinkName) :
                                                                                               qsTr("No default playback device")
                Accessible.role: Accessible.StaticText
                Accessible.name: description

                MaterialSymbol {
                    anchors.fill: parent
                    iconSize: 24
                    text: Volume.sinkIconName
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            MediaControlBar {
                x: (parent.width / 2) - playPauseCenterX
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: implicitHeight
                spacing: 20
                isPlaying: root.isPlaying
                shuffleActive: MediaManager.active && MediaManager.active.shuffle
                shuffleEnabled: MediaManager.active && MediaManager.active.shuffleSupported
                previousEnabled: MediaManager.active
                playPauseEnabled: MediaManager.active
                nextEnabled: MediaManager.active
                loopEnabled: MediaManager.active && MediaManager.active.loopSupported
                loopMode: !MediaManager.active || MediaManager.active.loopState === MprisLoopState.None ? 0 : (
                                                                                                              MediaManager.active.loopState
                                                                                                              === MprisLoopState.Track
                                                                                                              ? 2 : 1)
                activeColor: root.accentColor
                inactiveColor: Appearance.colors.colOnSurface
                playingBg: root.accentColor
                playingFg: root.onAccentColor
                pausedBg: root.coverColors ? root.trackColor : Appearance.colors.colSecondaryContainer
                pausedFg: root.coverColors ? root.accentColor : Appearance.colors.colOnSecondaryContainer
                morphEnabled: true

                onShuffleClicked: if (MediaManager.active && MediaManager.active.shuffleSupported)
                                      MediaManager.active.shuffle = !MediaManager.active.shuffle
                onPreviousClicked: {
                    if (MediaManager.active) {
                        cover.expectDirection(-1);
                        MediaManager.active.previous();
                    }
                }
                onPlayPauseClicked: if (MediaManager.active)
                                        MediaManager.active.togglePlaying()
                onNextClicked: {
                    if (MediaManager.active) {
                        cover.expectDirection(1);
                        MediaManager.active.next();
                    }
                }
                onLoopClicked: {
                    if (!MediaManager.active || !MediaManager.active.loopSupported)
                        return;

                    if (MediaManager.active.loopState === MprisLoopState.None)
                        MediaManager.active.loopState = MprisLoopState.Playlist;
                    else if (MediaManager.active.loopState === MprisLoopState.Playlist)
                        MediaManager.active.loopState = MprisLoopState.Track;
                    else
                        MediaManager.active.loopState = MprisLoopState.None;
                }
            }
        }
    }
}
