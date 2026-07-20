import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root
    
    readonly property bool isActive: root.visible && MediaManager.active
    property bool isPlaying: isActive && MediaManager.active && MediaManager.active.isPlaying

    property string artUrl: (isActive && MediaManager.active.trackArtUrl) 
        ? MediaManager.active.trackArtUrl 
        : ""
        
    property string title: (isActive && MediaManager.active.trackTitle) 
        ? MediaManager.active.trackTitle 
        : "No Media"
        
    property string artist: (isActive && MediaManager.active.trackArtist) 
        ? MediaManager.active.trackArtist 
        : "Unknown Artist"
    
    property double currentPos: 0
    
    Timer {
        interval: 100
        running: root.isActive
        repeat: true
        onTriggered: {
            if (MediaManager.active && !progressBar.pressed) {
                root.currentPos = MediaManager.active.position;
            }
        }
    }
    
    property double progress: (isActive && MediaManager.active.length > 0) 
        ? (root.currentPos / MediaManager.active.length) 
        : 0

    // 对播放器列表进行重排序，让当前播放器排在第一位
    property var sortedPlayerList: {
        let activeP = MediaManager.active;
        let allP = MediaManager.list;
        
        if (!activeP || allP.length <= 1) return allP;
        
        // 创建副本并排序：将 active 移到最前
        let sorted = allP.slice();
        sorted.sort((a, b) => {
            if (a === activeP) return -1;
            if (b === activeP) return 1;
            return 0;
        });
        return sorted;
    }

    // ==========================================
    // 全局布局
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 4
        anchors.bottomMargin: 12
        spacing: 24

        // 左侧：封面容器
        Item {
            Layout.preferredWidth: 120
            Layout.preferredHeight: 120
            Layout.alignment: Qt.AlignTop

            Item {
                id: scaleWrapper
                anchors.centerIn: parent
                width: 120
                height: 120
                scale: root.isPlaying ? 1.0 : 0.8

                Behavior on scale {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutQuint
                    }
                }

                DropShadow {
                    anchors.fill: coverContainer
                    source: coverContainer
                    color: Qt.rgba(0, 0, 0, 0.85)
                    radius: 24
                    samples: 49
                    verticalOffset: 8
                    opacity: root.isPlaying ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutQuint
                        }
                    }
                }

                Item {
                    id: coverContainer
                    anchors.fill: parent

                    Rectangle {
                        id: fallbackBg
                        anchors.fill: parent
                        radius: 16
                        color: Appearance.colors.colLayer3
                        visible: root.artUrl === ""

                        Text {
                            anchors.centerIn: parent
                            text: "music_note"
                            color: Appearance.colors.colOnLayer3
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 56
                        }
                    }

                    Image {
                        id: rawImg
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    Rectangle {
                        id: maskRect
                        anchors.fill: parent
                        radius: 16
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: rawImg
                        maskSource: maskRect
                        visible: root.artUrl !== "" && rawImg.status === Image.Ready
                    }
                }
            }
        }

        // 右侧：信息与控制区
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // 标题行（右侧留出空间给药丸）
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: root.title
                        color: Appearance.colors.colOnSurface
                        font.bold: true
                        font.pixelSize: 20
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.artist
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // 为药丸预留空间
                Item {
                    Layout.preferredWidth: 80
                    Layout.fillHeight: true
                }
            }

            Item { Layout.fillHeight: true }

            // 波浪进度条（填满右侧列宽度，与标题行对齐）
            WaveProgressBar {
                id: progressBar
                Layout.fillWidth: true
                Layout.preferredHeight: 36

                progress: root.progress
                waveColor: Appearance.colors.colPrimary
                trackColor: Appearance.colors.colLayer2Hover
                isPlaying: root.isPlaying
                waveAmplitude: 6
                waveFrequency: 0.05
                thumbSize: 14

                onSeekRequested: (position) => {
                    if (MediaManager.active && MediaManager.active.length > 0) {
                        let targetPos = position * MediaManager.active.length;
                        MediaManager.active.position = targetPos;
                        root.currentPos = targetPos;
                    }
                }
            }

            // 底部控制按钮区（填满右侧列宽度，与标题行对齐）
            MediaControlBar {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 24
                isPlaying: root.isPlaying
                shuffleActive: MediaManager.active && MediaManager.active.shuffle
                shuffleEnabled: MediaManager.active && MediaManager.active.shuffleSupported
                previousEnabled: MediaManager.active
                playPauseEnabled: MediaManager.active
                nextEnabled: MediaManager.active
                loopEnabled: MediaManager.active && MediaManager.active.loopSupported
                loopMode: !MediaManager.active || MediaManager.active.loopState === MprisLoopState.None
                    ? 0
                    : (MediaManager.active.loopState === MprisLoopState.Track ? 2 : 1)
                activeColor: Appearance.colors.colPrimary
                inactiveColor: Appearance.colors.colOnSurface
                playingBg: Appearance.colors.colPrimary
                playingFg: Appearance.colors.colOnPrimary
                pausedBg: Appearance.colors.colSecondaryContainer
                pausedFg: Appearance.colors.colOnSecondaryContainer
                morphEnabled: true

                onShuffleClicked: if (MediaManager.active && MediaManager.active.shuffleSupported) MediaManager.active.shuffle = !MediaManager.active.shuffle
                onPreviousClicked: if (MediaManager.active) MediaManager.active.previous()
                onPlayPauseClicked: if (MediaManager.active) MediaManager.active.togglePlaying()
                onNextClicked: if (MediaManager.active) MediaManager.active.next()
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

    Rectangle {
        id: pillRect

        anchors.top: root.top
        anchors.right: root.right
        anchors.topMargin: 4
        anchors.rightMargin: 16
        z: 999

        property bool menuExpanded: false

        color: Appearance.colors.colTertiary
        width: menuExpanded ? 110 : pillText.width + 24
        height: menuExpanded ? (30 * MediaManager.list.length + 12) : 26
        radius: menuExpanded ? 12 : 13
        scale: (!menuExpanded && pillMa.pressed) ? 0.94 : (!menuExpanded && pillMa.containsMouse ? 1.08 : 1.0)

        Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
        }
        Behavior on height {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
        }
        Behavior on radius {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
        }
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Text {
            id: pillText
            anchors.centerIn: parent
            text: MediaManager.getIdentity(MediaManager.active)
            color: Appearance.colors.colOnTertiary
            font.pixelSize: 11
            font.weight: Font.DemiBold
            opacity: pillRect.menuExpanded ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            visible: !pillRect.menuExpanded
            onClicked: {
                if (MediaManager.list.length > 1)
                    pillRect.menuExpanded = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0
            visible: pillRect.menuExpanded
            opacity: pillRect.menuExpanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: 250; easing.type: Easing.InQuad }
            }

            Repeater {
                model: root.sortedPlayerList

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 8
                    color: itemMa.containsMouse ? Qt.rgba(0, 0, 0, 0.08) : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: MediaManager.getIdentity(modelData)
                            color: Appearance.colors.colOnTertiary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            MediaManager.manualActive = modelData;
                            pillRect.menuExpanded = false;
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: pillRect.z - 1
        visible: pillRect.menuExpanded
        onClicked: pillRect.menuExpanded = false
    }
}
