import QtQuick
import Qt5Compat.GraphicalEffects 
import Quickshell
import Quickshell.Io  
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Services
import qs.Common

import qs.Modules.Keystone.ClockContent
import qs.Modules.Keystone.MediaContent  
import qs.Modules.Keystone.NotificationContent
import qs.Modules.Keystone.VolumeContent
import qs.Modules.Keystone.LyricsContent 
import qs.Modules.Keystone.Hub
import qs.Modules.Keystone.Tools
import qs.Modules.Keystone.audio 
import qs.Modules.Keystone.Styles.Recording

Variants {
    id: styleSurface

    signal avatarEditRequested(var screen)

    property bool detached: false
    property int topMargin: 0
    property int maxPillRadius: 24
    property bool showTopEdgeCurves: !detached

    function invoke(methodName) {
        if (instances.length === 0)
            return "KEYSTONE_UNAVAILABLE";

        const instance = instances[0];
        if (!instance || typeof instance[methodName] !== "function")
            return "KEYSTONE_UNAVAILABLE";
        return instance[methodName]();
    }

    function cancelRecord(): string {
        return invoke("cancelRecord");
    }

    function closeAllOthers(): string {
        return invoke("closeAllOthers");
    }

    function hub(): string {
        return invoke("hub");
    }

    function tools(): string {
        return invoke("tools");
    }

    model: Quickshell.screens

    PanelWindow {
        id: keystoneWindow
        required property var modelData
        screen: modelData

        property int topEdgeCurveWidth: styleSurface.showTopEdgeCurves ? 8 : 0
        property int topEdgeCurveDepth: styleSurface.showTopEdgeCurves ? 14 : 0
        property real topEdgeCurveSideControlY: 0.58
        property real topEdgeCurveTopControlX: 0.42

        function cancelRecord(): string {
            RecordingService.refresh();
            return "RECORD_CANCELLED";
        }

        function closeAllOthers(): string {
            root.showLyrics = false;
            root.showTools = false;
            root.showAudio = false;
            root.expanded = false;
            return "OTHERS_CLOSED";
        }

        function hub(): string {
            if (root.showHub) {
                root.showHub = false;
                return "HUB_CLOSED";
            }

            closeAllOthers();
            root.showHub = true;
            return "HUB_OPENED";
        }

        function tools(): string {
            if (root.showTools) {
                root.showTools = false;
                return "TOOLS_CLOSED";
            }

            closeAllOthers();
            root.showHub = false;
            root.showTools = true;
            return "TOOLS_OPENED";
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins { top: 0 }
        
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.namespace: "clavis-keystone"
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
            width: maskContainer.width
                + (styleSurface.detached && root.isRecordingMode
                    ? pillRecordingVisual.satelliteExtent
                    : 0)
        }

        mask: Region {
            item: hitBoxRegion
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
                id: shadowLeftTopCurve
                visible: styleSurface.showTopEdgeCurves
                anchors.right: rootShadow.left
                anchors.top: rootShadow.top
                width: keystoneWindow.topEdgeCurveWidth
                height: keystoneWindow.topEdgeCurveDepth
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "black";
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width, height);
                    ctx.bezierCurveTo(width, height * keystoneWindow.topEdgeCurveSideControlY,
                                      width * keystoneWindow.topEdgeCurveTopControlX, 0,
                                      0, 0);
                    ctx.fill();
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
                    topLeftRadius: styleSurface.detached ? root.radius : 0
                    topRightRadius: styleSurface.detached ? root.radius : 0
                    bottomLeftRadius: root.radius
                    bottomRightRadius: root.radius
                    color: "black"
                    visible: false
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
                        color: root.showDashboardHole ? "black" : "transparent"
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
                id: shadowRightTopCurve
                visible: styleSurface.showTopEdgeCurves
                anchors.left: rootShadow.right
                anchors.top: rootShadow.top
                width: keystoneWindow.topEdgeCurveWidth
                height: keystoneWindow.topEdgeCurveDepth
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "black";
                    ctx.beginPath();
                    ctx.moveTo(width, 0);
                    ctx.lineTo(0, 0);
                    ctx.lineTo(0, height);
                    ctx.bezierCurveTo(0, height * keystoneWindow.topEdgeCurveSideControlY,
                                      width * (1 - keystoneWindow.topEdgeCurveTopControlX), 0,
                                      width, 0);
                    ctx.fill();
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
        // 【视觉 Keystone bangs 本体】 
        // ============================================================
        Item {
            id: maskContainer
            anchors.top: parent.top
            anchors.topMargin: styleSurface.topMargin
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: styleSurface.detached && root.isRecordingMode
                ? (root.collapsedW - root.recordingPillW) / 2
                : 0
            width: root.width + (keystoneWindow.topEdgeCurveWidth * 2)
            height: root.height

            Behavior on anchors.horizontalCenterOffset {
                NumberAnimation {
                    duration: root.isRecordingMode
                        ? KeystoneMotion.shrinkingDuration
                        : KeystoneMotion.expandingDuration
                    easing.type: KeystoneMotion.type
                    easing.bezierCurve: root.isRecordingMode
                        ? KeystoneMotion.shrinkingBezier
                        : KeystoneMotion.expandingBezier
                }
            }

            Canvas {
                id: leftTopCurve
                visible: styleSurface.showTopEdgeCurves
                anchors.right: root.left
                anchors.top: root.top
                width: keystoneWindow.topEdgeCurveWidth
                height: keystoneWindow.topEdgeCurveDepth
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Appearance.colors.colLayer0;
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.lineTo(width, 0);
                    ctx.lineTo(width, height);
                    ctx.bezierCurveTo(width, height * keystoneWindow.topEdgeCurveSideControlY,
                                      width * keystoneWindow.topEdgeCurveTopControlX, 0,
                                      0, 0);
                    ctx.fill();
                }
                Connections {
                    target: Appearance.colors
                    function onColLayer0Changed() { leftTopCurve.requestPaint() }
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
                readonly property bool isRecording: RecordingService.isRecording
                readonly property bool isFinalizing: RecordingService.isFinalizing
                readonly property bool isRecordingMode: isRecording || isFinalizing

                property bool isLyricsMode: showLyrics && !isRecordingMode
                property bool isToolsMode: !isRecordingMode && showTools && !isLyricsMode
                property bool isHubMode: !isRecordingMode && showHub && !isToolsMode && !isLyricsMode
                property bool isAudioMode: !isRecordingMode && showAudio && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isVolumeMode: !isRecordingMode && showVolume && !expanded && !isAudioMode && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isNotifMode: !isRecordingMode && NotificationManager.hasNotifs && !expanded && !showVolume && !isAudioMode && !isHubMode && !isToolsMode && !isLyricsMode
                property bool isCollapsedMode: !isRecordingMode && !expanded && !isNotifMode && !isVolumeMode && !isAudioMode && !isLyricsMode && !isHubMode && !isToolsMode
                property bool isCollapsedHovered: isCollapsedMode && (keystoneMouseArea.containsMouse || collapsedInputArea.containsMouse)
                property bool hasClosablePopup: !isRecordingMode
                    && (expanded || isLyricsMode || isHubMode || isToolsMode || isAudioMode)
                
                property bool showDashboardHole: isHubMode && hubTabIndex === 0

                property int lyricsW: lyricsWidget.implicitWidth; property int lyricsH: 42 
                property int expandedW: 540; property int expandedH: 210
                property int collapsedW: 220; property int collapsedH: 42
                property int recordingPillW: 160; property int recordingPillH: 48
                property int recordingBangsW: 220; property int recordingBangsH: 48
                property int toolsW: 480; property int toolsH: 72
                property int notifW: 380; property int notifH: (NotificationManager.popupList.length * 70) + 20
                property int volW: 320; property int volH: 64
                property int audioW: 360; property int audioH: 84 
                
                property color color: Appearance.colors.colLayer0
                clip: true
                z: 100

                property int targetR: styleSurface.detached
                    ? Math.min(targetH / 2, styleSurface.maxPillRadius)
                    : 12

                property int targetW: isRecordingMode
                    ? (styleSurface.detached ? recordingPillW : recordingBangsW) :
                    isAudioMode ? audioW :
                    isToolsMode ? toolsW :
                    isHubMode ? hub.implicitWidth : 
                    isLyricsMode ? lyricsW : 
                    expanded ? expandedW : 
                    isVolumeMode ? volW : 
                    isNotifMode ? notifW : 
                    (collapsedW + (isCollapsedHovered ? 16 : 0))

                property int targetH: isRecordingMode
                    ? (styleSurface.detached ? recordingPillH : recordingBangsH) :
                        isAudioMode ? audioH :
                        isToolsMode ? toolsH : 
                        isHubMode ? hub.implicitHeight : 
                        isLyricsMode ? lyricsH : 
                        expanded ? expandedH : 
                        isVolumeMode ? volH : 
                        isNotifMode ? notifH : 
                        (collapsedH + (isCollapsedHovered ? 6 : 0))

                property int wDuration: KeystoneMotion.expandingDuration
                property int hDuration: KeystoneMotion.expandingDuration
                property int rDuration: KeystoneMotion.radiusDuration
                property var wBezier: KeystoneMotion.expandingBezier
                property var hBezier: KeystoneMotion.expandingBezier
                property var rBezier: KeystoneMotion.radiusBezier

                width: targetW
                height: targetH
                property real radius: targetR

                Rectangle {
                    id: solidRootBg
                    anchors.fill: parent
                    topLeftRadius: styleSurface.detached ? parent.radius : 0
                    topRightRadius: styleSurface.detached ? parent.radius : 0
                    bottomLeftRadius: parent.radius
                    bottomRightRadius: parent.radius
                    color: Appearance.colors.colLayer0
                    visible: false 
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
                        color: root.showDashboardHole ? "black" : "transparent"
                    }
                }

                OpacityMask {
                    id: rootSurface

                    anchors.fill: parent
                    source: solidRootBg
                    maskSource: rootHoleWrapper
                    invert: true 
                    opacity: styleSurface.detached && root.isRecordingMode ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                }

                onTargetWChanged: {
                    if (root.isHoverWidthMotion(targetW)) {
                        wDuration = KeystoneMotion.hoverDuration;
                        wBezier = KeystoneMotion.hoverBezier;
                        return;
                    }

                    const isExpanding = targetW > width;
                    wDuration = isExpanding ? KeystoneMotion.expandingDuration : KeystoneMotion.shrinkingDuration;
                    wBezier = isExpanding ? KeystoneMotion.expandingBezier : KeystoneMotion.shrinkingBezier;
                }
                onTargetHChanged: {
                    if (root.isHoverHeightMotion(targetH)) {
                        hDuration = KeystoneMotion.hoverDuration;
                        hBezier = KeystoneMotion.hoverBezier;
                        return;
                    }

                    const isExpanding = targetH > height;
                    hDuration = isExpanding ? KeystoneMotion.expandingDuration : KeystoneMotion.shrinkingDuration;
                    hBezier = isExpanding ? KeystoneMotion.expandingBezier : KeystoneMotion.shrinkingBezier;
                }
                onTargetRChanged: {
                    if (root.isHoverRadiusMotion(targetR)) {
                        rDuration = KeystoneMotion.hoverDuration;
                        rBezier = KeystoneMotion.hoverBezier;
                    } else {
                        rDuration = KeystoneMotion.radiusDuration;
                        rBezier = KeystoneMotion.radiusBezier;
                    }
                }

                function isHoverWidthMotion(nextW) {
                    return isCollapsedMode && Math.abs(nextW - width) <= KeystoneMotion.hoverWidthDelta;
                }

                function isHoverHeightMotion(nextH) {
                    return isCollapsedMode && Math.abs(nextH - height) <= KeystoneMotion.hoverHeightDelta;
                }

                function isHoverRadiusMotion(nextR) {
                    return isCollapsedMode && Math.abs(nextR - radius) <= KeystoneMotion.hoverRadiusDelta;
                }

                Behavior on width {
                    NumberAnimation {
                        duration: root.wDuration
                        easing.type: KeystoneMotion.type
                        easing.bezierCurve: root.wBezier
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: root.hDuration
                        easing.type: KeystoneMotion.type
                        easing.bezierCurve: root.hBezier
                    }
                }
                Behavior on radius {
                    NumberAnimation {
                        duration: root.rDuration
                        easing.type: KeystoneMotion.type
                        easing.bezierCurve: root.rBezier
                    }
                }

                focus: root.hasClosablePopup

                onHasClosablePopupChanged: {
                    if (root.hasClosablePopup)
                        root.forceActiveFocus();
                }

                Keys.onEscapePressed: (event) => {
                    root.closeKeystonePopups();
                    event.accepted = true;
                }

                function closeKeystonePopups() {
                    root.expanded = false;
                    root.showLyrics = false;
                    root.showVolume = false;
                    root.showHub = false;
                    root.showTools = false;
                    root.showAudio = false;
                }

                PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }
               
                property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                property var sourceAudioNode: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
                property string sliderMode: "volume"

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
                    function onVolumeChanged() { root.triggerSliderOSD("volume") } 
                    function onMutedChanged() { root.triggerSliderOSD("volume") }  
                }

                Connections {
                    target: root.sourceAudioNode; ignoreUnknownSignals: true
                    function onVolumeChanged() { root.triggerSliderOSD("mic") }
                    function onMutedChanged() { root.triggerSliderOSD("mic") }
                }

                Connections {
                    target: Brightness
                    function onBrightnessChanged() { root.triggerSliderOSD("brightness") }
                }

                function triggerSliderOSD(mode) {
                    if (root.showHub || root.showTools || root.showAudio || root.expanded || root.showLyrics) return
                    root.sliderMode = mode
                    root.showVolume = true; volHideTimer.restart()
                }

                function triggerVolumeOSD() {
                    root.triggerSliderOSD("volume")
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

                MouseArea {
                    id: keystoneMouseArea  
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true   
                    enabled: !root.isRecordingMode && !root.isNotifMode && !root.isVolumeMode
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
                        width: root.collapsedW
                        height: root.collapsedH
                        
                        player: root.currentPlayer
                        
                        opacity: root.isCollapsedMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                        
                    VolumeContent {
                        id: volumeWidget
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.volW
                        height: root.volH

                        mode: root.sliderMode
                        audioNode: root.sliderMode === "volume" ? root.audioNode : root.sliderMode === "mic" ? root.sourceAudioNode : null
                        externalValue: Brightness.brightnessValue
                        iconName: root.sliderMode === "brightness" ? "brightness_medium" : ""
                        opacity: root.isVolumeMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }

                        onMoved: value => {
                            if (root.sliderMode === "brightness")
                                Brightness.setBrightness(value);
                        }
                    }
                        
                    NotificationContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 10
                        width: root.notifW - 20
                        height: root.notifH - 20

                        manager: NotificationManager
                        
                        opacity: root.isNotifMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                        
                    LyricsContent { 
                        id: lyricsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.lyricsW
                        height: root.lyricsH

                        player: root.currentPlayer; active: root.isLyricsMode
                        opacity: root.isLyricsMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                    
                    MediaContent { 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 20
                        width: root.expandedW - 40
                        height: root.expandedH - 40

                        opacity: (!root.isRecordingMode && root.expanded && !root.isLyricsMode && !root.isHubMode) ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                        
                    HubContent {
                        id: hub
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        height: implicitHeight
                        
                        player: root.currentPlayer
                        screen: keystoneWindow.screen
                        currentIndex: root.hubTabIndex
                        onCurrentIndexChanged: root.hubTabIndex = currentIndex
                        onCloseRequested: root.showHub = false
                        onAvatarEditRequested: {
                            root.showHub = false
                            styleSurface.avatarEditRequested(keystoneWindow.screen)
                        }

                        opacity: root.isHubMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }

                    ToolsContent {
                        id: toolsWidget 
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.toolsW
                        height: root.toolsH

                        opacity: root.isToolsMode ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }

                        onRequestHideKeystone: { root.showTools = false }
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
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }

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

            PillRecordingVisual {
                id: pillRecordingVisual

                anchors.right: root.right
                anchors.rightMargin: -effectBleed
                anchors.verticalCenter: root.verticalCenter
                mainWidth: root.width
                mainHeight: root.height
                active: styleSurface.detached && root.isRecordingMode
                recording: styleSurface.detached && root.isRecording
                finalizing: styleSurface.detached && root.isFinalizing
                recordingType: RecordingService.recordingType
                elapsedMs: RecordingService.elapsedMs
                visible: styleSurface.detached && (active || opacity > 0.01)
                z: root.z + 2

                onStopRequested: RecordingService.stop()
            }

            BangsRecordingVisual {
                id: bangsRecordingVisual

                anchors.centerIn: root
                width: root.width
                height: root.height
                active: !styleSurface.detached && root.isRecordingMode
                recording: !styleSurface.detached && root.isRecording
                finalizing: !styleSurface.detached && root.isFinalizing
                recordingType: RecordingService.recordingType
                elapsedMs: RecordingService.elapsedMs
                visible: !styleSurface.detached && (active || opacity > 0.01)
                z: root.z + 2

                onStopRequested: RecordingService.stop()
            }

            Canvas {
                id: rightTopCurve
                visible: styleSurface.showTopEdgeCurves
                anchors.left: root.right
                anchors.top: root.top
                width: keystoneWindow.topEdgeCurveWidth
                height: keystoneWindow.topEdgeCurveDepth
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Appearance.colors.colLayer0;
                    ctx.beginPath();
                    ctx.moveTo(width, 0);
                    ctx.lineTo(0, 0);
                    ctx.lineTo(0, height);
                    ctx.bezierCurveTo(0, height * keystoneWindow.topEdgeCurveSideControlY,
                                      width * (1 - keystoneWindow.topEdgeCurveTopControlX), 0,
                                      width, 0);
                    ctx.fill();
                }
                Connections {
                    target: Appearance.colors
                    function onColLayer0Changed() { rightTopCurve.requestPaint() }
                }
            }
        }

    }
}
