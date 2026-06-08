import QtQuick
import Qt5Compat.GraphicalEffects 
import Quickshell
import Quickshell.Io  
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Services
import qs.Common

import qs.Modules.DynamicIsland.ClockContent
import qs.Modules.DynamicIsland.MediaContent  
import qs.Modules.DynamicIsland.NotificationContent
import qs.Modules.DynamicIsland.VolumeContent
import qs.Modules.DynamicIsland.LyricsContent 
import qs.Modules.DynamicIsland.Hub
import qs.Modules.DynamicIsland.Tools
import qs.Modules.DynamicIsland.audio 

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: islandWindow
        required property var modelData
        screen: modelData

        property int earRadius: 16

        anchors {
            top: true
            left: true
            right: true
        }
        // 只覆盖灵动岛实际需要的高度，避免全屏透明层阻塞输入
        // barHeight + 灵动岛最大展开高度 + 弹出内容空间 + 阴影偏移
        implicitHeight: Sizes.barHeight + 500
        margins { top: 0 }
        
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.namespace: "clavis-dynamic-island"
        WlrLayershell.layer: WlrLayer.Top

        WlrLayershell.keyboardFocus: root.hasClosablePopup
            ? WlrKeyboardFocus.Exclusive 
            : WlrKeyboardFocus.None

        // ============================================================
        // 【物理挖孔层 (Mask Region)】 
        // ============================================================
        Item {
            id: hitBoxRegion
            anchors.top: maskContainer.top
            anchors.bottom: maskContainer.bottom
            anchors.right: maskContainer.right
            anchors.left: detachedRecordContainer.left 
        }

        // 有弹出内容时 mask 覆盖整个窗口以捕获外部点击，否则只覆盖岛区域
        mask: Region {
            x: 0; y: 0
            width: root.hasClosablePopup ? islandWindow.width : 0
            height: root.hasClosablePopup ? islandWindow.height : 0
            regions: [
                Region { item: hitBoxRegion }
            ]
        }

        // 点击灵动岛外部关闭弹出内容
        MouseArea {
            anchors.fill: parent
            enabled: root.hasClosablePopup
            z: -1
            onClicked: root.closeIslandPopups()
        }

        // ============================================================
        // 【阴影源 (Shadow Source)】
        // ============================================================
        Item {
            id: shadowSource
            anchors.top: maskContainer.top
            anchors.horizontalCenter: maskContainer.horizontalCenter
            width: maskContainer.width
            height: maskContainer.height
            visible: false 

            Canvas {
                id: shadowLeftEar 
                anchors.right: rootShadow.left
                anchors.top: rootShadow.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset(); ctx.fillStyle = "black";
                    ctx.beginPath(); ctx.moveTo(0, 0);
                    ctx.lineTo(width, 0); ctx.lineTo(width, height);
                    ctx.arc(0, height, width, 0, -Math.PI/2, true); ctx.fill();
                }
                Connections { 
                    target: Appearance.colors
                    function onColLayer0Changed() { shadowLeftEar.requestPaint() }
                }
            }

            Item {
                id: rootShadow
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.width
                height: root.height
                
                Rectangle {
                    id: solidShadowBg
                    anchors.fill: parent
                    radius: root.radius
                    color: "black"
                    visible: false
                    
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.radius
                        color: "black"
                    }
                }

                Item {
                    id: shadowHoleWrapper
                    anchors.fill: parent
                    visible: false
                    Rectangle {
                        // 【宽度 340，左移至 18 完美对齐右侧卡片】
                        width: 340
                        height: 456
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: 48
                        anchors.top: parent.top
                        anchors.topMargin: 132
                        radius: 24
                        color: root.showOverviewHole ? "black" : "transparent"
                    }
                }

                OpacityMask {
                    anchors.fill: parent
                    source: solidShadowBg
                    maskSource: shadowHoleWrapper
                    invert: true
                }
            }

            Canvas {
                id: shadowRightEar 
                anchors.left: rootShadow.right
                anchors.top: rootShadow.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "black";
                    ctx.beginPath(); ctx.moveTo(width, 0); ctx.lineTo(0, 0); ctx.lineTo(0, height);
                    ctx.arc(width, height, width, Math.PI, Math.PI*1.5, false); ctx.fill();
                }
                Connections { 
                    target: Appearance.colors
                    function onColLayer0Changed() { shadowRightEar.requestPaint() }
                }
            }
        }

        DropShadow {
            anchors.fill: shadowSource
            source: shadowSource
            horizontalOffset: 0
            verticalOffset: 6
            radius: 20
            samples: 32
            color: "#80000000" 
            cached: true
        }

        // ============================================================
        // 【视觉灵动岛本体】 
        // ============================================================
        Item {
            id: maskContainer
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width + (islandWindow.earRadius * 2)
            height: root.height

            Canvas {
                id: leftEar
                anchors.right: root.left
                anchors.top: root.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Appearance.colors.colLayer0;
                    ctx.beginPath();
                    ctx.moveTo(0, 0);                 
                    ctx.lineTo(width, 0);             
                    ctx.lineTo(width, height);
                    ctx.arc(0, height, width, 0, -Math.PI/2, true);
                    ctx.fill();
                }
                Connections {
                    target: Appearance.colors
                    function onColLayer0Changed() { leftEar.requestPaint() }
                }
            }

            Item {
                id: root
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter

                property bool showLyrics: false 
                property bool expanded: false
                property bool showVolume: false
                property bool showHub: false
                property bool showTools: false 
                property bool showAudio: false 
                
                property string currentAudioMode: "mic" 
                property int hubTabIndex: 0
                property bool isRecording: false

                property bool isLyricsMode: showLyrics
                property bool isToolsMode: showTools && !isLyricsMode
                property bool isHubMode: showHub && !isToolsMode && !isLyricsMode
                property bool isAudioMode: showAudio && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isVolumeMode: showVolume && !expanded && !isAudioMode && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isNotifMode: NotificationManager.hasNotifs && !expanded && !showVolume && !isAudioMode && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isCollapsedMode: !expanded && !isNotifMode && !isVolumeMode && !isAudioMode && !isLyricsMode && !isHubMode && !isToolsMode
                property bool isCollapsedHovered: isCollapsedMode && (islandMouseArea.containsMouse || collapsedInputArea.containsMouse)
                property bool hasClosablePopup: expanded || showLyrics || showHub || showTools || showAudio
                
                property bool showOverviewHole: isHubMode && hubTabIndex === 0

                property int lyricsW: lyricsWidget.implicitWidth; property int lyricsH: 42 
                property int expandedW: 540; property int expandedH: 210
                property int collapsedW: 220; property int collapsedH: 42
                property int recordExtraW: 0 
                property int toolsW: 480; property int toolsH: 72
                property int notifW: 380; property int notifH: (NotificationManager.popupList.length * 70) + 20
                property int volW: 320; property int volH: 64
                property int audioW: 360; property int audioH: 84 
                
                property color color: Appearance.colors.colLayer0
                clip: true
                z: 100

                property int targetR: (expanded || isNotifMode || isVolumeMode || 
                      isLyricsMode || isHubMode || isToolsMode || isAudioMode) 
                      ? 24 : (isCollapsedHovered ? 18 : 16)

                property int targetW: isAudioMode ? audioW :
                    isToolsMode ? toolsW :
                    isHubMode ? hub.implicitWidth : 
                    isLyricsMode ? lyricsW : 
                    expanded ? expandedW : 
                    isVolumeMode ? volW : 
                    isNotifMode ? notifW : 
                    (collapsedW + (root.isRecording ? recordExtraW : 0) + (isCollapsedHovered ? 16 : 0))

                property int targetH: isAudioMode ? audioH :
                        isToolsMode ? toolsH : 
                        isHubMode ? hub.implicitHeight : 
                        isLyricsMode ? lyricsH : 
                        expanded ? expandedH : 
                        isVolumeMode ? volH : 
                        isNotifMode ? notifH : 
                        (collapsedH + (isCollapsedHovered ? 6 : 0))

                property real wDamping: DynamicIslandMotion.initialDamping
                property real hDamping: DynamicIslandMotion.initialDamping
                property real rDamping: DynamicIslandMotion.initialDamping

                width: targetW
                height: targetH
                property real radius: targetR

                Rectangle {
                    id: solidRootBg
                    anchors.fill: parent
                    radius: parent.radius
                    color: Appearance.colors.colLayer0
                    visible: false 
                    
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.radius
                        color: parent.color
                    }
                }

                Item {
                    id: rootHoleWrapper
                    anchors.fill: parent
                    visible: false
                    Rectangle {
                        // 【同步对齐】
                        width: 340
                        height: 456
                        anchors.left: parent.horizontalCenter
                        anchors.leftMargin: 48
                        anchors.top: parent.top
                        anchors.topMargin: 132
                        radius: 24
                        color: root.showOverviewHole ? "black" : "transparent"
                    }
                }

                OpacityMask {
                    anchors.fill: parent
                    source: solidRootBg
                    maskSource: rootHoleWrapper
                    invert: true 
                }

                onTargetWChanged: {
                    let isExpanding = (targetW > width); wDamping = isExpanding ? DynamicIslandMotion.expandingDamping : DynamicIslandMotion.shrinkingDamping;
                }
                onTargetHChanged: {
                    let isExpanding = (targetH > height); hDamping = isExpanding ? DynamicIslandMotion.expandingDamping : DynamicIslandMotion.shrinkingDamping;
                }
                onTargetRChanged: {
                    let isExpanding = (targetR > radius); rDamping = isExpanding ? DynamicIslandMotion.expandingDamping : DynamicIslandMotion.shrinkingDamping;
                }

                Behavior on width { SpringAnimation { spring: DynamicIslandMotion.spring; mass: DynamicIslandMotion.mass; damping: root.wDamping; epsilon: DynamicIslandMotion.epsilon } }
                Behavior on height { SpringAnimation { spring: DynamicIslandMotion.spring; mass: DynamicIslandMotion.mass; damping: root.hDamping; epsilon: DynamicIslandMotion.epsilon } }
                Behavior on radius { SpringAnimation { spring: DynamicIslandMotion.spring; mass: DynamicIslandMotion.mass; damping: root.rDamping; epsilon: DynamicIslandMotion.epsilon } }

                focus: root.hasClosablePopup

                onHasClosablePopupChanged: {
                    if (root.hasClosablePopup)
                        root.forceActiveFocus();
                }

                Keys.onEscapePressed: (event) => {
                    root.closeIslandPopups();
                    event.accepted = true;
                }

                function closeIslandPopups() {
                    root.expanded = false;
                    root.showLyrics = false;
                    root.showVolume = false;
                    root.showHub = false;
                    root.showTools = false;
                    root.showAudio = false;
                }

                IpcHandler {
                    target: "island"
                    
                    function cancelRecord() {
                        root.isRecording = false; return "RECORD_CANCELLED"
                    }

                    function closeAllOthers() {
                        root.showLyrics = false; root.showTools = false;
                        root.showAudio = false; 
                        root.expanded = false;
                    }

                    function hub() {
                        if (root.showHub) { root.showHub = false; return "HUB_CLOSED" } 
                        else { closeAllOthers(); root.showHub = true; return "HUB_OPENED" }
                    }

                    function tools() {
                        if (root.showTools) { root.showTools = false; return "TOOLS_CLOSED" } 
                        else { closeAllOthers(); root.showHub = false; root.showTools = true; return "TOOLS_OPENED" }
                    }
                }

                PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
               
                property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

                Timer { 
                    id: volHideTimer
                    interval: 2000
                    onTriggered: {
                        if (volumeWidget.isInteractionActive) { restart() } 
                        else { root.showVolume = false }
                    }
                }
            
                Connections {
                    target: root.audioNode; ignoreUnknownSignals: true
                    function onVolumeChanged() { root.triggerVolumeOSD() } 
                    function onMutedChanged() { root.triggerVolumeOSD() }  
                }
            
                function triggerVolumeOSD() {
                    if (root.showHub || root.showTools || root.showAudio || root.expanded || root.showLyrics) return
                    root.showVolume = true; volHideTimer.restart()
                }
                
                property var currentPlayer: null

                Timer {
                    id: stickyTimer
                    interval: 500; repeat: true; triggeredOnStart: true
                    running: Mpris.players.values.length > 0
                    onRunningChanged: { if (!running) root.currentPlayer = null }
                    onTriggered: {
                        var players = Mpris.players.values
                        if (players.length === 0) { root.currentPlayer = null; return }
                        var playingPlayer = null
                        for (let i = 0; i < players.length; i++) { 
                            if (players[i].isPlaying) { playingPlayer = players[i]; break } 
                        }
                        if (playingPlayer) { 
                            if (root.currentPlayer !== playingPlayer) root.currentPlayer = playingPlayer 
                        } else {
                            var currentIsValid = false
                            if (root.currentPlayer) { 
                                for (let i = 0; i < players.length; i++) { 
                                    if (players[i] === root.currentPlayer) { currentIsValid = true; break } 
                                } 
                            }
                            if (!currentIsValid) root.currentPlayer = players[0]
                        }
                    }
                }

                // 阻止点击事件穿透到外部全屏 MouseArea
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: {} // 消费点击事件，不传播
                }

                MouseArea {
                    id: islandMouseArea
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: !root.isNotifMode && !root.isVolumeMode
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            if (root.showHub) root.showHub = false 
                            else if (root.showTools) root.showTools = false 
                            else if (root.showAudio) root.showAudio = false
                            
                            root.showLyrics = !root.showLyrics
                            if (root.showLyrics) root.expanded = false
                        } else {
                            if (root.isLyricsMode || root.isHubMode || root.isToolsMode || root.isAudioMode)
                                return;

                            root.expanded = !root.expanded;
                        }
                    }
                }

                Item {
                    id: staticCanvas
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1600 
                    height: 1200

                    ClockContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.collapsedW + (root.isRecording ? root.recordExtraW : 0)
                        height: root.collapsedH
                        
                        player: root.currentPlayer
                        
                        opacity: (!root.expanded && !root.isNotifMode && !root.isVolumeMode && !root.isLyricsMode && !root.isHubMode && !root.isToolsMode && !root.isAudioMode) ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    VolumeContent {
                        id: volumeWidget
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.volW
                        height: root.volH

                        audioNode: root.audioNode
                        opacity: root.isVolumeMode ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    NotificationContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 10
                        width: root.notifW - 20
                        height: root.notifH - 20

                        manager: NotificationManager
                        
                        opacity: root.isNotifMode ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    LyricsContent { 
                        id: lyricsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.lyricsW
                        height: root.lyricsH

                        player: root.currentPlayer; active: root.isLyricsMode
                        opacity: root.isLyricsMode ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                    
                    MediaContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 20
                        width: root.expandedW - 40
                        height: root.expandedH - 40

                        opacity: (root.expanded && !root.isLyricsMode && !root.isHubMode) ? 1 : 0
                        visible: opacity > 0.01; Behavior on opacity { NumberAnimation { duration: 200 } } 
                    }
                        
                    HubContent {
                        id: hub
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        height: implicitHeight
                        
                        player: root.currentPlayer
                        currentIndex: root.hubTabIndex
                        onCurrentIndexChanged: root.hubTabIndex = currentIndex
                        onCloseRequested: root.showHub = false

                        opacity: root.isHubMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    ToolsContent {
                        id: toolsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.toolsW
                        height: root.toolsH

                        opacity: root.isToolsMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        onRequestHideIsland: { root.showTools = false }
                        onRequestSetRecording: (state) => { root.isRecording = state }
                        onRequestShowAudio: (mode) => { 
                            root.currentAudioMode = mode
                            root.showTools = false
                            root.showAudio = true 
                        }
                    }

                    AudioContent {
                        id: audioWidget
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.audioW
                        height: root.audioH

                        active: root.isAudioMode
                        audioMode: root.currentAudioMode
                        opacity: root.isAudioMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        onRequestStop: {
                            root.showAudio = false
                            toolsWidget.stopAudio() 
                        }
                    }
                }

                MouseArea {
                    id: collapsedInputArea
                    anchors.fill: parent
                    z: 10000
                    enabled: root.isCollapsedMode
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            root.showLyrics = !root.showLyrics;
                            if (root.showLyrics)
                                root.expanded = false;
                        } else if (mouse.button === Qt.LeftButton) {
                            root.expanded = true;
                        }

                        mouse.accepted = true;
                    }
                }
            }

            Canvas {
                id: rightEar
                anchors.left: root.right
                anchors.top: root.top
                width: islandWindow.earRadius
                height: islandWindow.earRadius
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Appearance.colors.colLayer0;
                    ctx.beginPath();
                    ctx.moveTo(width, 0);             
                    ctx.lineTo(0, 0);                 
                    ctx.lineTo(0, height);
                    ctx.arc(width, height, width, Math.PI, Math.PI*1.5, false);
                    ctx.fill();
                }
                Connections {
                    target: Appearance.colors
                    function onColLayer0Changed() { rightEar.requestPaint() }
                }
            }
        }

        Item {
            id: detachedRecordContainer
            width: 36
            height: 36
            anchors.verticalCenter: maskContainer.verticalCenter
            anchors.right: maskContainer.left
            anchors.rightMargin: root.isRecording ? 5 : -width
            z: maskContainer.z - 1 

            Behavior on anchors.rightMargin {
                SpringAnimation { spring: 4.0; damping: 0.8; mass: 1.0 }
            }
            
            opacity: root.isRecording ? 1 : 0
            Behavior on opacity { 
                SequentialAnimation {
                    PauseAnimation { duration: root.isRecording ? 0 : 400 }
                    NumberAnimation { duration: root.isRecording ? 200 : 0 } 
                }
            }
            visible: root.isRecording || opacity > 0

            Rectangle {
                id: detachedBtnBg
                anchors.fill: parent
                radius: width / 2
                color: Appearance.colors.colLayer0
                visible: false 
            }

            DropShadow {
                anchors.fill: detachedBtnBg
                source: detachedBtnBg
                horizontalOffset: 0
                verticalOffset: 6
                radius: 20
                samples: 32
                color: "#80000000"
                cached: true
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Appearance.colors.colLayer0
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: "#ff3333"
                    antialiasing: true
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.isRecording
                        NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isRecording = false 
                        toolsWidget.stopRecording() 
                    }
                }
            }
        }
    }
}
