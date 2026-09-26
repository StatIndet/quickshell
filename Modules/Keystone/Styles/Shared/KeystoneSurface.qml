import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Clavis.Niri
import qs.Services
import qs.Common
import qs.Widgets.common
import qs.Modules.Keystone.ClockContent
import qs.Modules.Keystone.MediaContent
import qs.Modules.Keystone.NotificationContent
import qs.Modules.Keystone.VolumeContent
import qs.Modules.Keystone.LyricsContent
import qs.Modules.Keystone.Hub
import qs.Modules.Keystone.Tools
import qs.Modules.Keystone.Styles.Recording
import qs.Modules.Keystone.Styles.Long

Variants {
    id: styleSurface

    property bool detached: false
    property bool elongated: false
    readonly property bool splitRecording: detached && !elongated
    property int edgeMargin: 0
    property int maxPillRadius: 24
    property bool showAttachedEdgeCurves: !detached

    signal avatarEditRequested(var screen)

    function targetInstance() {
        if (instances.length === 0)
            return null;

        const outputName = String(Niri.currentOutput || "");
        if (outputName.length > 0) {
            for (let index = 0; index < instances.length; ++index) {
                const instance = instances[index];
                if (instance && instance.screen && instance.screen.name === outputName)
                    return instance;
            }
        }
        return instances[0];
    }

    function invoke(methodName) {
        const instance = targetInstance();
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

    function dashboard(): string {
        return invoke("dashboard");
    }

    function lyrics(): string {
        return invoke("lyrics");
    }

    function tools(): string {
        return invoke("tools");
    }

    model: Quickshell.screens

    PanelWindow {
        id: keystoneWindow

        required property var modelData
        readonly property string edge: PersonalizationConfig.keystonePosition
        readonly property bool horizontalEdge: edge === "top" || edge === "bottom"
        readonly property bool topEdge: edge === "top"
        readonly property bool bottomEdge: edge === "bottom"
        readonly property bool leftEdge: edge === "left"
        readonly property bool rightEdge: edge === "right"
        property int edgeCurveAlong: styleSurface.showAttachedEdgeCurves ? 8 : 0
        property int edgeCurveDepth: styleSurface.showAttachedEdgeCurves ? 14 : 0
        property real edgeCurveSideControl: 0.58
        property real edgeCurveOuterControl: 0.42

        function cancelRecord(): string {
            return "RECORD_CANCELLED";
        }

        function closeAllOthers(): string {
            hoverIntent.cancel();
            root.showHub = false;
            root.showLyrics = false;
            root.showTools = false;
            root.expanded = false;
            root.hoverOpened = false;
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

        function dashboard(): string {
            if (root.showHub && root.hubTabIndex === 0) {
                root.showHub = false;
                return "DASHBOARD_CLOSED";
            }
            closeAllOthers();
            root.hubTabIndex = 0;
            root.showHub = true;
            return "DASHBOARD_OPENED";
        }

        function lyrics(): string {
            if (root.showLyrics) {
                root.showLyrics = false;
                return "LYRICS_CLOSED";
            }
            closeAllOthers();
            root.showLyrics = true;
            return "LYRICS_OPENED";
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

        screen: modelData
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.namespace: "clavis-shell-keystone"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // On-demand focus lets desktop clicks leave the island and clicks on
        // the island focus it again. Hover previews never request keyboard input.
        WlrLayershell.keyboardFocus: root.keyboardInteractionActive ? WlrKeyboardFocus.OnDemand :
                                                                      WlrKeyboardFocus.None

        PanelWindow {
            // Niri focuses newly mapped OnDemand surfaces. Keep that mapping
            // separate from the visible island so expansion never drops a frame.
            // After a desktop click, neither window requests focus again.
            visible: root.keyboardInteractionActive
            screen: keystoneWindow.screen
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            exclusiveZone: -1
            WlrLayershell.namespace: "clavis-shell-keystone-keyboard"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            anchors {
                top: true
                left: true
            }
            mask: Region {}

            Item {
                anchors.fill: parent
                focus: true
                Keys.forwardTo: root.isToolsMode ? [toolsWidget, root] : [root]

                // Shortcuts belong to their receiving window. Mouse interaction
                // focuses the visible island, where HubContent handles them.
                Shortcut {
                    enabled: root.isHubMode
                    sequence: "Tab"
                    onActivated: hub.cycleTab(1)
                }

                Shortcut {
                    enabled: root.isHubMode
                    sequence: "Shift+Tab"
                    onActivated: hub.cycleTab(-1)
                }
            }
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        margins {
            top: 0
        }

        // ============================================================
        // 【阴影源 (Shadow Source)】
        // ============================================================
        Item {
            id: shadowSource

            anchors.fill: maskContainer

            AttachedEdgeCurve {
                id: shadowLeftTopCurve

                visible: styleSurface.showAttachedEdgeCurves
                edge: keystoneWindow.edge
                after: false
                along: keystoneWindow.edgeCurveAlong
                depth: keystoneWindow.edgeCurveDepth
                sideControl: keystoneWindow.edgeCurveSideControl
                edgeControl: keystoneWindow.edgeCurveOuterControl
                fillColor: "black"

                anchors {
                    right: keystoneWindow.horizontalEdge ? rootShadow.left : keystoneWindow.rightEdge
                                                           ? rootShadow.right : undefined
                    left: keystoneWindow.leftEdge ? rootShadow.left : undefined
                    bottom: !keystoneWindow.horizontalEdge ? rootShadow.top : keystoneWindow.bottomEdge
                                                             ? rootShadow.bottom : undefined
                    top: keystoneWindow.topEdge ? rootShadow.top : undefined
                }
            }

            Item {
                id: rootShadow

                width: root.width
                height: root.height
                state: keystoneWindow.edge
                states: [
                    State {
                        name: "top"

                        AnchorChanges {
                            target: rootShadow
                            anchors.top: shadowSource.top
                            anchors.bottom: undefined
                            anchors.left: undefined
                            anchors.right: undefined
                            anchors.horizontalCenter: shadowSource.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                    },
                    State {
                        name: "bottom"

                        AnchorChanges {
                            target: rootShadow
                            anchors.top: undefined
                            anchors.bottom: shadowSource.bottom
                            anchors.left: undefined
                            anchors.right: undefined
                            anchors.horizontalCenter: shadowSource.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                    },
                    State {
                        name: "left"

                        AnchorChanges {
                            target: rootShadow
                            anchors.top: undefined
                            anchors.bottom: undefined
                            anchors.left: shadowSource.left
                            anchors.right: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: shadowSource.verticalCenter
                        }
                    },
                    State {
                        name: "right"

                        AnchorChanges {
                            target: rootShadow
                            anchors.top: undefined
                            anchors.bottom: undefined
                            anchors.left: undefined
                            anchors.right: shadowSource.right
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: shadowSource.verticalCenter
                        }
                    }
                ]

                SurfaceShape {
                    surfaceColor: "black"
                    topLeftRadius: rootSurface.topLeftRadius
                    topRightRadius: rootSurface.topRightRadius
                    bottomRightRadius: rootSurface.bottomRightRadius
                    bottomLeftRadius: rootSurface.bottomLeftRadius
                    cutoutVisible: rootSurface.cutoutVisible
                    cutoutX: rootSurface.cutoutX
                    cutoutY: rootSurface.cutoutY
                    cutoutWidth: rootSurface.cutoutWidth
                    cutoutHeight: rootSurface.cutoutHeight
                    cutoutRadius: rootSurface.cutoutRadius
                }
            }

            AttachedEdgeCurve {
                id: shadowRightTopCurve

                visible: styleSurface.showAttachedEdgeCurves
                edge: keystoneWindow.edge
                after: true
                along: keystoneWindow.edgeCurveAlong
                depth: keystoneWindow.edgeCurveDepth
                sideControl: keystoneWindow.edgeCurveSideControl
                edgeControl: keystoneWindow.edgeCurveOuterControl
                fillColor: "black"

                anchors {
                    left: keystoneWindow.leftEdge ? rootShadow.left : (keystoneWindow.horizontalEdge
                                                                       ? rootShadow.right : undefined)
                    right: keystoneWindow.rightEdge ? rootShadow.right : undefined
                    top: keystoneWindow.topEdge ? rootShadow.top : (!keystoneWindow.horizontalEdge
                                                                    ? rootShadow.bottom : undefined)
                    bottom: keystoneWindow.bottomEdge ? rootShadow.bottom : undefined
                }
            }
        }

        // Keep the canvas paintable while hiding its black source from the scene.
        ShaderEffectSource {
            id: shadowTexture
            anchors.fill: shadowSource
            sourceItem: shadowSource
            hideSource: true
            visible: false
        }

        DropShadow {
            anchors.fill: shadowSource
            source: shadowTexture
            horizontalOffset: keystoneWindow.leftEdge ? 6 : keystoneWindow.rightEdge ? -6 : 0
            verticalOffset: keystoneWindow.topEdge ? 6 : keystoneWindow.bottomEdge ? -6 : 0
            radius: 20
            samples: 32
            color: "#80000000"
            cached: false
            opacity: styleSurface.elongated ? 0 : root.color.a * (styleSurface.splitRecording
                                                                  && root.recordingPresentationActive ? 0 : 1)
        }

        // ============================================================
        // 【视觉 Keystone bangs 本体】
        // ============================================================
        Item {
            id: maskContainer

            anchors.topMargin: keystoneWindow.topEdge ? styleSurface.edgeMargin : 0
            anchors.bottomMargin: keystoneWindow.bottomEdge ? styleSurface.edgeMargin : 0
            anchors.leftMargin: keystoneWindow.leftEdge ? styleSurface.edgeMargin : 0
            anchors.rightMargin: keystoneWindow.rightEdge ? styleSurface.edgeMargin : 0
            width: styleSurface.elongated && longFrame.item ? longFrame.item.implicitWidth : root.width + (
                                                                  keystoneWindow.horizontalEdge
                                                                  ? keystoneWindow.edgeCurveAlong * 2 : 0)
            height: styleSurface.elongated && longFrame.item ? longFrame.item.implicitHeight : root.height + (
                                                                   !keystoneWindow.horizontalEdge
                                                                   ? keystoneWindow.edgeCurveAlong * 2 : 0)
            state: keystoneWindow.edge
            states: [
                State {
                    name: "top"

                    AnchorChanges {
                        target: maskContainer
                        anchors.top: keystoneWindow.contentItem.top
                        anchors.bottom: undefined
                        anchors.left: undefined
                        anchors.right: undefined
                        anchors.horizontalCenter: keystoneWindow.contentItem.horizontalCenter
                        anchors.verticalCenter: undefined
                    }
                },
                State {
                    name: "bottom"

                    AnchorChanges {
                        target: maskContainer
                        anchors.top: undefined
                        anchors.bottom: keystoneWindow.contentItem.bottom
                        anchors.left: undefined
                        anchors.right: undefined
                        anchors.horizontalCenter: keystoneWindow.contentItem.horizontalCenter
                        anchors.verticalCenter: undefined
                    }
                },
                State {
                    name: "left"

                    AnchorChanges {
                        target: maskContainer
                        anchors.top: undefined
                        anchors.bottom: undefined
                        anchors.left: keystoneWindow.contentItem.left
                        anchors.right: undefined
                        anchors.horizontalCenter: undefined
                        anchors.verticalCenter: keystoneWindow.contentItem.verticalCenter
                    }
                },
                State {
                    name: "right"

                    AnchorChanges {
                        target: maskContainer
                        anchors.top: undefined
                        anchors.bottom: undefined
                        anchors.left: undefined
                        anchors.right: keystoneWindow.contentItem.right
                        anchors.horizontalCenter: undefined
                        anchors.verticalCenter: keystoneWindow.contentItem.verticalCenter
                    }
                }
            ]

            AttachedEdgeCurve {
                id: leftTopCurve

                visible: styleSurface.showAttachedEdgeCurves
                edge: keystoneWindow.edge
                after: false
                along: keystoneWindow.edgeCurveAlong
                depth: keystoneWindow.edgeCurveDepth
                sideControl: keystoneWindow.edgeCurveSideControl
                edgeControl: keystoneWindow.edgeCurveOuterControl
                fillColor: root.color

                anchors {
                    right: keystoneWindow.horizontalEdge ? root.left : keystoneWindow.rightEdge ? root.right :
                                                                                                  undefined

                    left: keystoneWindow.leftEdge ? root.left : undefined
                    bottom: !keystoneWindow.horizontalEdge ? root.top : keystoneWindow.bottomEdge
                                                             ? root.bottom : undefined
                    top: keystoneWindow.topEdge ? root.top : undefined
                }

                Connections {
                    function onColorChanged() {
                        leftTopCurve.requestPaint();
                    }

                    target: root
                }
            }

            Loader {
                id: longFrame
                anchors.fill: parent
                active: styleSurface.elongated
                sourceComponent: LongIslandFrame {
                    screen: keystoneWindow.screen
                    edge: keystoneWindow.edge
                    expanded: !root.isCollapsedMode
                    targetWidth: root.targetW
                    targetHeight: root.targetH
                    childItem: root
                    cutoutItem: dashboardKeyholeCutout
                    cutoutVisible: root.showDashboardKeyhole
                    surfaceColor: root.color
                    onClockClicked: button => root.activateMouseAction(button === Qt.MiddleButton
                                                                       ? PersonalizationConfig.keystoneMiddleClickAction :
                                                                         PersonalizationConfig.keystoneLeftClickAction,
                                                                       true)
                    onMediaRequested: root.activateMouseAction("media", true)
                }
            }

            // The long main bar stays visible while its child surface is collapsed.
            DropArea {
                id: longCloudUploadDropArea
                parent: styleSurface.elongated && longFrame.item ? longFrame.item.mainItem : maskContainer
                anchors.fill: parent
                z: 20000
                enabled: styleSurface.elongated && !!longFrame.item && root.cloudUploadDropEnabled
                onEntered: drag => root.enterCloudUploadDrag(drag)
                onDropped: drop => root.acceptCloudUploadDrop(drop)
            }

            KeystoneHoverController {
                id: hoverIntent
                triggerHovered: styleSurface.elongated ? !!longFrame.item && longFrame.item.clockHovered :
                                                         surfaceHover.hovered
                surfaceHovered: surfaceHover.hovered || (styleSurface.elongated && !!longFrame.item
                                                         && longFrame.item.mainHovered)
                canOpen: root.isCollapsedMode && PersonalizationConfig.keystoneHoverAction !== "none"
                previewOpen: root.hoverOpened
                openDelay: PersonalizationConfig.keystoneHoverOpenDelay
                closeDelay: PersonalizationConfig.keystoneHoverCloseDelay
                onOpenRequested: {
                    const action = PersonalizationConfig.keystoneHoverAction;
                    root.activateMouseAction(styleSurface.elongated && action === "peak" ? "media" : action,
                                             false, true);
                    root.hoverOpened = true;
                }
                onCloseRequested: keystoneWindow.closeAllOthers()
            }

            Item {
                id: root

                property bool hoverOpened: false

                readonly property bool cloudUploadDropEnabled: !contentPresentationActive && (isCollapsedMode
                                                                                              || isHubMode)

                function supportsCloudUploadDrop(event) {
                    return cloudUploadDropEnabled && event.hasUrls && event.formats.indexOf("text/uri-list")
                            >= 0 && CloudUploadService.hasLocalUrls(event.urls);
                }

                function enterCloudUploadDrag(drag) {
                    drag.accepted = supportsCloudUploadDrop(drag);
                    if (!drag.accepted)
                        return;
                    hoverOpened = false;
                    hoverIntent.cancel();
                    expanded = false;
                    showLyrics = false;
                    showVolume = false;
                    showTools = false;
                    hubTabIndex = 1;
                    showHub = true;
                }

                function acceptCloudUploadDrop(drop) {
                    if (!supportsCloudUploadDrop(drop)) {
                        drop.accepted = false;
                        return;
                    }
                    const addedCount = CloudUploadService.enqueueUrls(drop.urls);
                    hub.finishCloudUploadDrop(addedCount);
                    drop.acceptProposedAction();
                }

                function activateMouseAction(action, toggle, fromHover = false) {
                    if (action === "none" || action === "peak" || root.contentPresentationActive
                            || root.isNotifMode || root.isVolumeMode)
                        return;
                    const tabs = {
                        dashboard: 0,
                        upload: 1,
                        weather: 2
                    };
                    const isTab = Object.prototype.hasOwnProperty.call(tabs, action);
                    const alreadyOpen = action === "media" ? root.expanded : action === "lyrics"
                                                             ? root.showLyrics : action === "tools"
                                                               ? root.showTools : isTab && root.showHub
                                                                 && root.hubTabIndex === tabs[action];
                    if (toggle && alreadyOpen && root.hoverOpened) {
                        root.hoverOpened = false;
                        hoverIntent.cancel();
                        return;
                    }
                    keystoneWindow.closeAllOthers();
                    if (toggle && alreadyOpen)
                        return;
                    root.hoverOpened = fromHover;
                    if (action === "media")
                        root.expanded = true;
                    else if (action === "lyrics")
                        root.showLyrics = true;
                    else if (action === "tools")
                        root.showTools = true;
                    else if (isTab) {
                        root.hubTabIndex = tabs[action];
                        root.showHub = true;
                    }
                }

                HoverHandler {
                    id: surfaceHover
                    enabled: !styleSurface.elongated || (!!longFrame.item && longFrame.item.progress > 0.02)
                }

                TapHandler {
                    // A click turns a hover preview into a persistent keyboard
                    // interaction without consuming child controls' pointer events.
                    enabled: root.hoverOpened && !root.isCollapsedMode
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onTapped: root.hoverOpened = false
                }

                property bool showLyrics: false
                property bool expanded: false
                property bool showVolume: false
                property bool showHub: false
                property bool showTools: false
                readonly property bool recordingLaunchPending: styleSurface.elongated && showTools && (
                                                                   RecordingService.isSelecting
                                                                   || RecordingService.isStarting
                                                                   || AudioRecordingService.isStarting)
                property int hubTabIndex: 0
                property bool componentReady: false
                property bool pillStopFusionMinimumActive: false
                readonly property bool backendFinalizing: RecordingService.isFinalizing
                readonly property bool gifRecording: RecordingService.recordingType === "gif"
                readonly property bool stopPresentationActive: RecordingService.isStopPending || (
                                                                   styleSurface.splitRecording
                                                                   && pillStopFusionMinimumActive)
                readonly property bool isRecording: (RecordingService.isRecording || RecordingService.state
                                                     === "paused") && !stopPresentationActive
                readonly property bool isFinalizing: backendFinalizing || stopPresentationActive
                readonly property bool isRecordingMode: isRecording || isFinalizing
                property bool recordingExitActive: false
                readonly property bool recordingPresentationActive: isRecordingMode || recordingExitActive
                                                                    || recordingInfoProgress > 0.01
                                                                    || recordingActionProgress > 0.01
                                                                    || processingContentProgress > 0.01
                readonly property int audioPhaseHidden: 0
                readonly property int audioPhaseExpanded: 1
                readonly property int audioPhaseCollapsing: 2
                property int audioPresentationPhase: audioPhaseHidden
                readonly property bool audioSessionActive: AudioRecordingService.isActive
                readonly property bool audioPresentationActive: audioSessionActive || audioPresentationPhase
                                                                !== audioPhaseHidden
                readonly property bool audioGeometryActive: audioSessionActive || audioPresentationPhase
                                                            === audioPhaseExpanded
                readonly property bool contentPresentationActive: recordingPresentationActive
                                                                  || audioPresentationActive
                property bool isLyricsMode: showLyrics && !contentPresentationActive
                property bool isToolsMode: !contentPresentationActive && showTools && !isLyricsMode
                property bool isHubMode: !contentPresentationActive && showHub && !isToolsMode &&
                                         !isLyricsMode
                property bool isVolumeMode: !contentPresentationActive && showVolume && !expanded &&
                                            !isHubMode && !isToolsMode && !isLyricsMode
                property bool isNotifMode: !contentPresentationActive && NotificationManager.hasNotifs &&
                                           !expanded && !showVolume && !isHubMode && !isToolsMode &&
                                           !isLyricsMode
                property bool isCollapsedMode: !contentPresentationActive && !expanded && !isNotifMode &&
                                               !isVolumeMode && !isLyricsMode && !isHubMode && !isToolsMode
                property bool isCollapsedHovered: PersonalizationConfig.keystoneHoverAction === "peak"
                                                  && isCollapsedMode && root.hoverOpened
                readonly property bool escapeDismissActive: !contentPresentationActive && (expanded
                                                                                           || isLyricsMode
                                                                                           || isHubMode
                                                                                           || isToolsMode
                                                                                           || isCollapsedHovered)
                readonly property bool keyboardInteractionActive: escapeDismissActive && !hoverOpened &&
                                                                  !isCollapsedMode && !recordingLaunchPending
                onKeyboardInteractionActiveChanged: {
                    if (keyboardInteractionActive)
                        root.requestKeyboardFocus();
                }
                readonly property bool dashboardTabActive: isHubMode && hubTabIndex === 0
                readonly property string dashboardUptimeOwner: "keystone-dashboard:" + String(
                                                                   keystoneWindow.modelData.name || "default")
                // The hub remains visible while fading out after its mode is dismissed.
                // Keep its cutout and blur subtraction until the card is hidden too.
                readonly property bool showDashboardKeyhole: hub.currentIndex === 0 && hub.visible
                property real pillMorphProgress: 0
                property real recordingInfoProgress: 0
                property real recordingActionProgress: 0
                property real processingContentProgress: 0
                readonly property int pillEntryDuration: 900
                readonly property int pillFusionDuration: 820
                property int pillActiveFusionDuration: pillFusionDuration
                property int notifW: 380
                property int notifH: 20 + NotificationManager.popupList.reduce((height, notif) => {
                    return height + (NotificationManager.normalActions(notif).length > 0 ? 104 : 64);
                }, 0) + Math.max(0, NotificationManager.popupList.length - 1) * 10
                property color color: BlurService.backgroundColor(mediaWidget.visible
                                                                  && mediaWidget.coverColors
                                                                  ? mediaWidget.surfaceColor :
                                                                    Appearance.colors.colLayer0)
                readonly property QtObject activeLayout: keystoneWindow.horizontalEdge ? horizontalLayout :
                                                                                         verticalLayout
                readonly property real recordingVisualWidth: styleSurface.splitRecording
                                                             && pillRecordingPresenter.item
                                                             ? pillRecordingPresenter.item.implicitWidth :
                                                               activeLayout.attachedRecordingWidth
                readonly property real recordingVisualHeight: styleSurface.splitRecording
                                                              && pillRecordingPresenter.item
                                                              ? pillRecordingPresenter.item.implicitHeight :
                                                                activeLayout.attachedRecordingHeight
                readonly property bool useRecordingBlurRegions: styleSurface.splitRecording
                                                                && root.recordingPresentationActive
                                                                && pillRecordingPresenter.item !== null
                readonly property var recordingBlurBackgroundItems: useRecordingBlurRegions
                                                                    ? pillRecordingPresenter.item.blurBackgroundItems :
                                                                      []
                property real targetW: isVolumeMode && keyboardOsd ? (keystoneWindow.horizontalEdge ? 260 :
                                                                                                      112) : activeLayout.targetWidth
                property real targetH: isVolumeMode && keyboardOsd ? (keystoneWindow.horizontalEdge ? 64 :
                                                                                                      144) : activeLayout.targetHeight
                property int targetR: styleSurface.detached ? Math.min(Math.min(targetW, targetH) / 2, styleSurface.maxPillRadius) :
                                                              12
                property int wDuration: KeystoneMotion.expandingDuration
                property int hDuration: KeystoneMotion.expandingDuration
                property int rDuration: KeystoneMotion.radiusDuration
                property var wBezier: KeystoneMotion.expandingBezier
                property var hBezier: KeystoneMotion.expandingBezier
                property var rBezier: KeystoneMotion.radiusBezier
                property real radius: targetR
                property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                property var sourceAudioNode: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio :
                                                                            null
                property string sliderMode: "volume"
                readonly property bool keyboardOsd: sliderMode === "capslock" || sliderMode === "numlock"
                property bool locksInitialized: false
                property bool previousCapsLock: false
                property bool previousNumLock: false
                property bool lockEnabled: false

                function updateKeyboardLocks() {
                    if (!KeyboardLockService.available) {
                        locksInitialized = false;
                        if (keyboardOsd)
                            showVolume = false;
                        return;
                    }
                    const caps = KeyboardLockService.capsLock;
                    const num = KeyboardLockService.numLock;
                    if (locksInitialized) {
                        if (caps !== previousCapsLock && PersonalizationConfig.keystoneCapsLockOsd) {
                            root.lockEnabled = caps;
                            root.triggerSliderOSD("capslock");
                        }
                        if (num !== previousNumLock && PersonalizationConfig.keystoneNumLockOsd) {
                            root.lockEnabled = num;
                            root.triggerSliderOSD("numlock");
                        }
                    }
                    previousCapsLock = caps;
                    previousNumLock = num;
                    locksInitialized = true;
                }

                readonly property var currentPlayer: MediaManager.active

                function isHoverWidthMotion(nextW) {
                    return isCollapsedMode && Math.abs(nextW - width) <= KeystoneMotion.hoverWidthDelta;
                }

                function isHoverHeightMotion(nextH) {
                    return isCollapsedMode && Math.abs(nextH - height) <= KeystoneMotion.hoverHeightDelta;
                }

                function isHoverRadiusMotion(nextR) {
                    return isCollapsedMode && Math.abs(nextR - radius) <= KeystoneMotion.hoverRadiusDelta;
                }

                function closeKeystonePopups() {
                    hoverIntent.cancel();
                    root.expanded = false;
                    root.showLyrics = false;
                    root.showVolume = false;
                    root.showHub = false;
                    root.showTools = false;
                    root.hoverOpened = false;
                    if (root.isNotifMode)
                        NotificationManager.hideAllPopups();
                }

                function triggerSliderOSD(mode) {
                    if (root.contentPresentationActive || root.showHub || root.showTools || root.expanded
                            || root.showLyrics)
                        return;

                    root.sliderMode = mode;
                    root.showVolume = true;
                    volHideTimer.restart();
                }

                function triggerVolumeOSD() {
                    root.triggerSliderOSD("volume");
                }

                function requestKeyboardFocus() {
                    Qt.callLater(() => {
                        if (!root.keyboardInteractionActive)
                            return;

                        if (root.isToolsMode)
                            toolsWidget.forceActiveFocus();
                        else
                            root.forceActiveFocus();
                    });
                }

                onIsToolsModeChanged: {
                    if (root.isToolsMode)
                        root.requestKeyboardFocus();
                }
                onDashboardTabActiveChanged: SystemIdentityService.setUptimeConsumer(root.dashboardUptimeOwner,
                                                                                     root.dashboardTabActive)
                Component.onDestruction: SystemIdentityService.setUptimeConsumer(root.dashboardUptimeOwner,
                                                                                 false)
                focus: root.keyboardInteractionActive
                Keys.onEscapePressed: event => {
                    WidgetState.closeAllPopups();
                    event.accepted = true;
                }
                state: keystoneWindow.edge
                // HubContent changes its own currentIndex when a tab is
                // clicked. Keep the two pieces of state synchronized
                // explicitly; a child assignment would otherwise break a
                // binding installed on HubContent.currentIndex.
                onHubTabIndexChanged: {
                    if (hub.currentIndex !== root.hubTabIndex)
                        hub.currentIndex = root.hubTabIndex;
                }
                clip: true
                z: 100
                width: styleSurface.elongated && longFrame.item ? longFrame.item.childWidth : targetW
                height: styleSurface.elongated && longFrame.item ? longFrame.item.childHeight : targetH
                opacity: styleSurface.elongated ? (longFrame.item ? longFrame.item.contentOpacity : 0) : 1
                visible: !styleSurface.elongated || (!!longFrame.item && longFrame.item.progress > 0)
                enabled: !styleSurface.elongated || (!!longFrame.item && longFrame.item.progress > 0.02)
                anchors.topMargin: styleSurface.elongated && keystoneWindow.topEdge && longFrame.item
                                   ? longFrame.item.childOffset : 0
                anchors.bottomMargin: styleSurface.elongated && keystoneWindow.bottomEdge && longFrame.item
                                      ? longFrame.item.childOffset : 0
                anchors.leftMargin: styleSurface.elongated && keystoneWindow.leftEdge && longFrame.item
                                    ? longFrame.item.childOffset : 0
                anchors.rightMargin: styleSurface.elongated && keystoneWindow.rightEdge && longFrame.item
                                     ? longFrame.item.childOffset : 0
                onAudioSessionActiveChanged: {
                    if (root.audioSessionActive) {
                        if (styleSurface.elongated) {
                            root.hoverOpened = false;
                            hoverIntent.cancel();
                        }
                        root.audioPresentationPhase = root.audioPhaseExpanded;
                        root.expanded = false;
                        root.showLyrics = false;
                        root.showVolume = false;
                        root.showHub = false;
                        root.showTools = false;
                        if (root.componentReady)
                            audioRecordingVisual.beginEntry();

                        return;
                    }
                    if (root.audioPresentationPhase === root.audioPhaseExpanded)
                        audioRecordingVisual.beginExit();
                }
                onIsRecordingChanged: {
                    if (!root.isRecording)
                        return;

                    if (styleSurface.elongated) {
                        // Recording already owns the presentation here, so
                        // clearing Tools cannot collapse the existing island.
                        root.showTools = false;
                        root.showHub = false;
                        root.showLyrics = false;
                        root.showVolume = false;
                        root.expanded = false;
                        root.hoverOpened = false;
                        hoverIntent.cancel();
                    }
                    contentResetTimer.stop();
                    recordingPresentationOut.stop();
                    recordingActionOut.stop();
                    pillRecordingInfoOut.stop();
                    bangsRecordingInfoOut.stop();
                    processingContentIn.stop();
                    root.recordingExitActive = false;
                    recordingContentIn.restart();
                    if (styleSurface.splitRecording) {
                        pillGeometryExit.stop();
                        pillGeometryEntry.restart();
                    }
                }
                onIsFinalizingChanged: {
                    if (!root.isFinalizing)
                        return;

                    recordingContentIn.stop();
                    processingContentIn.stop();
                    recordingActionOut.restart();
                    if (styleSurface.splitRecording) {
                        pillGeometryEntry.stop();
                        root.pillActiveFusionDuration = Math.max(220, Math.round(root.pillFusionDuration
                                                                                 * root.pillMorphProgress));
                        pillRecordingInfoOut.restart();
                        pillGeometryExit.restart();
                    } else if (root.gifRecording) {
                        bangsRecordingInfoOut.restart();
                        processingContentIn.restart();
                    }
                }
                onBackendFinalizingChanged: {
                    if (root.gifRecording && root.backendFinalizing && (!styleSurface.splitRecording
                                                                        || root.pillMorphProgress <= 0.01)
                            && root.processingContentProgress < 0.99)
                        processingContentIn.restart();
                }
                onIsRecordingModeChanged: {
                    if (root.isRecordingMode)
                        return;

                    root.pillStopFusionMinimumActive = false;
                    pillRecordingInfoOut.stop();
                    bangsRecordingInfoOut.stop();
                    processingContentIn.stop();
                    if (!styleSurface.splitRecording) {
                        // Backend completion starts the geometry exit immediately;
                        // don't add a processing/fade-out presentation beforehand.
                        recordingContentIn.stop();
                        recordingActionOut.stop();
                        recordingPresentationOut.stop();
                        root.recordingInfoProgress = 0;
                        root.recordingActionProgress = 0;
                        root.processingContentProgress = 0;
                        root.recordingExitActive = false;
                        return;
                    }
                    root.recordingExitActive = true;
                    recordingPresentationOut.restart();
                }
                Component.onCompleted: {
                    root.updateKeyboardLocks();
                    SystemIdentityService.setUptimeConsumer(root.dashboardUptimeOwner,
                                                            root.dashboardTabActive);
                    root.componentReady = true;
                    recordingContentIn.stop();
                    recordingPresentationOut.stop();
                    recordingActionOut.stop();
                    pillRecordingInfoOut.stop();
                    bangsRecordingInfoOut.stop();
                    processingContentIn.stop();
                    pillGeometryEntry.stop();
                    pillGeometryExit.stop();
                    root.recordingExitActive = false;
                    root.pillMorphProgress = styleSurface.splitRecording && root.isRecording ? 1 : 0;
                    root.recordingInfoProgress = root.isRecording || (!styleSurface.splitRecording
                                                                      && root.isFinalizing &&
                                                                      !root.gifRecording) ? 1 : 0;
                    root.recordingActionProgress = root.isRecording ? 1 : 0;
                    root.processingContentProgress = root.gifRecording && root.isFinalizing ? 1 : 0;
                    root.audioPresentationPhase = root.audioSessionActive ? root.audioPhaseExpanded :
                                                                            root.audioPhaseHidden;
                    if (root.audioSessionActive)
                        audioRecordingVisual.beginEntry();
                }
                onTargetWChanged: {
                    if (root.audioPresentationPhase === root.audioPhaseCollapsing) {
                        wDuration = KeystoneMotion.audioCollapseDuration;
                        wBezier = KeystoneMotion.hoverBezier;
                        return;
                    }
                    if (targetW === root.activeLayout.audioWidth && root.audioGeometryActive) {
                        wDuration = KeystoneMotion.audioExpandDuration;
                        wBezier = KeystoneMotion.hoverBezier;
                        return;
                    }
                    if (root.isHoverWidthMotion(targetW)) {
                        wDuration = KeystoneMotion.hoverDuration;
                        wBezier = KeystoneMotion.hoverBezier;
                        return;
                    }
                    const isExpanding = targetW > width;
                    wDuration = isExpanding ? KeystoneMotion.expandingDuration :
                                              KeystoneMotion.shrinkingDuration;
                    wBezier = isExpanding ? KeystoneMotion.expandingBezier : KeystoneMotion.shrinkingBezier;
                }
                onTargetHChanged: {
                    if (root.audioPresentationPhase === root.audioPhaseCollapsing) {
                        hDuration = KeystoneMotion.audioCollapseDuration;
                        hBezier = KeystoneMotion.hoverBezier;
                        return;
                    }
                    if (targetH === root.activeLayout.audioHeight && root.audioGeometryActive) {
                        hDuration = KeystoneMotion.audioExpandDuration;
                        hBezier = KeystoneMotion.hoverBezier;
                        return;
                    }
                    if (root.isHoverHeightMotion(targetH)) {
                        hDuration = KeystoneMotion.hoverDuration;
                        hBezier = KeystoneMotion.hoverBezier;
                        return;
                    }
                    const isExpanding = targetH > height;
                    hDuration = isExpanding ? KeystoneMotion.expandingDuration :
                                              KeystoneMotion.shrinkingDuration;
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
                states: [
                    State {
                        name: "top"

                        AnchorChanges {
                            target: root
                            anchors.top: maskContainer.top
                            anchors.bottom: undefined
                            anchors.left: undefined
                            anchors.right: undefined
                            anchors.horizontalCenter: maskContainer.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                    },
                    State {
                        name: "bottom"

                        AnchorChanges {
                            target: root
                            anchors.top: undefined
                            anchors.bottom: maskContainer.bottom
                            anchors.left: undefined
                            anchors.right: undefined
                            anchors.horizontalCenter: maskContainer.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                    },
                    State {
                        name: "left"

                        AnchorChanges {
                            target: root
                            anchors.top: undefined
                            anchors.bottom: undefined
                            anchors.left: maskContainer.left
                            anchors.right: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: maskContainer.verticalCenter
                        }
                    },
                    State {
                        name: "right"

                        AnchorChanges {
                            target: root
                            anchors.top: undefined
                            anchors.bottom: undefined
                            anchors.left: undefined
                            anchors.right: maskContainer.right
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: maskContainer.verticalCenter
                        }
                    }
                ]

                HorizontalKeystoneLayout {
                    id: horizontalLayout

                    recordingActive: root.recordingPresentationActive
                    audioActive: root.audioGeometryActive
                    toolsActive: root.isToolsMode
                    hubActive: root.isHubMode
                    lyricsActive: root.isLyricsMode
                    expandedActive: root.expanded
                    expandedWidth: mediaWidget.panelWidth
                    expandedHeight: mediaWidget.panelHeight
                    volumeActive: root.isVolumeMode
                    notificationsActive: root.isNotifMode
                    collapsedHovered: root.isCollapsedHovered
                    recordingWidth: root.recordingVisualWidth
                    recordingHeight: root.recordingVisualHeight
                    toolsWidth: toolsWidget.implicitWidth
                    toolsHeight: toolsWidget.implicitHeight
                    hubWidth: hub.implicitWidth
                    hubHeight: hub.implicitHeight
                    lyricsWidth: lyricsWidget.implicitWidth
                    lyricsHeight: lyricsWidget.implicitHeight
                    notificationsWidth: root.notifW
                    notificationsHeight: root.notifH
                }

                VerticalKeystoneLayout {
                    id: verticalLayout

                    recordingActive: root.recordingPresentationActive
                    audioActive: root.audioGeometryActive
                    toolsActive: root.isToolsMode
                    hubActive: root.isHubMode
                    lyricsActive: root.isLyricsMode
                    expandedActive: root.expanded
                    expandedWidth: mediaWidget.panelWidth
                    expandedHeight: mediaWidget.panelHeight
                    volumeActive: root.isVolumeMode
                    notificationsActive: root.isNotifMode
                    collapsedHovered: root.isCollapsedHovered
                    recordingWidth: root.recordingVisualWidth
                    recordingHeight: root.recordingVisualHeight
                    toolsWidth: toolsWidget.implicitWidth
                    toolsHeight: toolsWidget.implicitHeight
                    hubWidth: hub.implicitWidth
                    hubHeight: hub.implicitHeight
                    lyricsWidth: lyricsWidget.implicitWidth
                    lyricsHeight: lyricsWidget.implicitHeight
                    notificationsWidth: root.notifW
                    notificationsHeight: root.notifH
                }

                ParallelAnimation {
                    id: recordingContentIn

                    NumberAnimation {
                        target: root
                        property: "processingContentProgress"
                        to: 0
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }

                    SequentialAnimation {
                        PauseAnimation {
                            duration: Appearance.animation.expressiveFastEffects.duration
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: root
                                property: "recordingInfoProgress"
                                to: 1
                                duration: Appearance.animation.expressiveSlowEffects.duration
                                easing.type: Appearance.animation.expressiveSlowEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                            }

                            NumberAnimation {
                                target: root
                                property: "recordingActionProgress"
                                to: 1
                                duration: Appearance.animation.expressiveSlowEffects.duration
                                easing.type: Appearance.animation.expressiveSlowEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                            }
                        }
                    }
                }

                NumberAnimation {
                    id: pillGeometryEntry

                    target: root
                    property: "pillMorphProgress"
                    to: 1
                    duration: root.pillEntryDuration
                    easing.type: Easing.Linear
                }

                NumberAnimation {
                    id: recordingActionOut

                    target: root
                    property: "recordingActionProgress"
                    to: 0
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }

                SequentialAnimation {
                    id: pillRecordingInfoOut

                    PauseAnimation {
                        duration: Math.max(0, root.pillActiveFusionDuration
                                           - Appearance.animation.expressiveSlowEffects.duration)
                    }

                    NumberAnimation {
                        target: root
                        property: "recordingInfoProgress"
                        to: 0
                        duration: Appearance.animation.expressiveSlowEffects.duration
                        easing.type: Appearance.animation.expressiveSlowEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                    }
                }

                NumberAnimation {
                    id: bangsRecordingInfoOut

                    target: root
                    property: "recordingInfoProgress"
                    to: 0
                    duration: Appearance.animation.emphasizedAccel.duration
                    easing.type: Appearance.animation.emphasizedAccel.type
                    easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
                }

                NumberAnimation {
                    id: pillGeometryExit

                    target: root
                    property: "pillMorphProgress"
                    to: 0
                    duration: root.pillActiveFusionDuration
                    easing.type: Easing.Linear
                    onFinished: {
                        const shouldShowProcessing = root.gifRecording && (root.backendFinalizing
                                                                           || RecordingService.isStopPending);
                        root.pillStopFusionMinimumActive = false;
                        if (shouldShowProcessing)
                            processingContentIn.restart();
                    }
                }

                NumberAnimation {
                    id: processingContentIn

                    target: root
                    property: "processingContentProgress"
                    to: root.gifRecording ? 1 : 0
                    duration: Appearance.animation.expressiveSlowEffects.duration
                    easing.type: Appearance.animation.expressiveSlowEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                }

                ParallelAnimation {
                    id: recordingPresentationOut

                    onFinished: {
                        root.recordingExitActive = false;
                        contentResetTimer.restart();
                    }

                    NumberAnimation {
                        target: root
                        property: "recordingInfoProgress"
                        to: 0
                        duration: Appearance.animation.emphasizedAccel.duration
                        easing.type: Appearance.animation.emphasizedAccel.type
                        easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
                    }

                    NumberAnimation {
                        target: root
                        property: "recordingActionProgress"
                        to: 0
                        duration: Appearance.animation.expressiveFastEffects.duration
                        easing.type: Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                    }

                    NumberAnimation {
                        target: root
                        property: "processingContentProgress"
                        to: 0
                        duration: Appearance.animation.emphasizedAccel.duration
                        easing.type: Appearance.animation.emphasizedAccel.type
                        easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
                    }
                }

                Timer {
                    id: contentResetTimer

                    interval: 60
                    onTriggered: {
                        if (root.recordingPresentationActive)
                            return;

                        recordingContentIn.stop();
                        recordingPresentationOut.stop();
                        recordingActionOut.stop();
                        pillRecordingInfoOut.stop();
                        bangsRecordingInfoOut.stop();
                        processingContentIn.stop();
                        pillGeometryEntry.stop();
                        pillGeometryExit.stop();
                        root.pillMorphProgress = 0;
                        root.recordingInfoProgress = 0;
                        root.recordingActionProgress = 0;
                        root.processingContentProgress = 0;
                    }
                }

                Rectangle {
                    id: dashboardKeyholeCutout

                    width: 340
                    height: 456
                    anchors.left: parent.horizontalCenter
                    anchors.leftMargin: hub.dashboardKeyholeCenterOffset + contentParallax.x
                    anchors.top: parent.top
                    anchors.topMargin: 132 + contentParallax.y
                    radius: 24
                    color: "transparent"
                    visible: root.showDashboardKeyhole
                }

                SurfaceShape {
                    id: rootSurface
                    surfaceColor: root.color
                    topLeftRadius: styleSurface.detached || (!keystoneWindow.topEdge &&
                                                             !keystoneWindow.leftEdge) ? root.radius : 0
                    topRightRadius: styleSurface.detached || (!keystoneWindow.topEdge &&
                                                              !keystoneWindow.rightEdge) ? root.radius : 0
                    bottomRightRadius: styleSurface.detached || (!keystoneWindow.bottomEdge &&
                                                                 !keystoneWindow.rightEdge) ? root.radius : 0
                    bottomLeftRadius: styleSurface.detached || (!keystoneWindow.bottomEdge &&
                                                                !keystoneWindow.leftEdge) ? root.radius : 0
                    cutoutVisible: root.showDashboardKeyhole
                    cutoutX: dashboardKeyholeCutout.x
                    cutoutY: dashboardKeyholeCutout.y
                    cutoutWidth: dashboardKeyholeCutout.width
                    cutoutHeight: dashboardKeyholeCutout.height
                    cutoutRadius: dashboardKeyholeCutout.radius

                    opacity: styleSurface.elongated || (styleSurface.splitRecording
                                                        && root.recordingPresentationActive) ? 0 : 1
                }

                Loader {
                    anchors.fill: parent
                    active: mediaWidget.visible && mediaWidget.backgroundCover
                    opacity: mediaWidget.opacity
                    sourceComponent: MediaBackdrop {
                        artUrl: mediaWidget.artUrl
                        sourceSize: Qt.size(Math.ceil(Math.min(mediaWidget.panelWidth,
                                                               mediaWidget.panelHeight * 1.5) * 2), Math.ceil(
                                                mediaWidget.panelHeight * 2))
                        topLeftRadius: styleSurface.elongated && longFrame.item ? longFrame.item.childRadius :
                                                                                  rootSurface.topLeftRadius
                        topRightRadius: styleSurface.elongated && longFrame.item ? longFrame.item.childRadius :
                                                                                   rootSurface.topRightRadius
                        bottomLeftRadius: styleSurface.elongated && longFrame.item
                                          ? longFrame.item.childRadius : rootSurface.bottomLeftRadius
                        bottomRightRadius: styleSurface.elongated && longFrame.item
                                           ? longFrame.item.childRadius : rootSurface.bottomRightRadius
                    }
                }

                Connections {
                    target: KeyboardLockService
                    function onAvailabilityChanged() {
                        root.locksInitialized = false;
                        root.updateKeyboardLocks();
                    }
                    function onLockStateChanged() {
                        root.updateKeyboardLocks();
                    }
                }

                Connections {
                    target: PersonalizationConfig
                    function onKeystoneHoverActionChanged() {
                        hoverIntent.cancel();
                        if (root.hoverOpened)
                            keystoneWindow.closeAllOthers();
                    }
                    function onKeystoneCapsLockOsdChanged() {
                        if (!PersonalizationConfig.keystoneCapsLockOsd && root.sliderMode === "capslock")
                            root.showVolume = false;
                    }
                    function onKeystoneNumLockOsdChanged() {
                        if (!PersonalizationConfig.keystoneNumLockOsd && root.sliderMode === "numlock")
                            root.showVolume = false;
                    }
                }

                PwObjectTracker {
                    objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
                }

                Timer {
                    id: volHideTimer

                    interval: 2000
                    onTriggered: {
                        if (!root.keyboardOsd && volumeWidget.isInteractionActive)
                            restart();
                        else
                            root.showVolume = false;
                    }
                }

                Connections {
                    function onVolumeChanged() {
                        root.triggerSliderOSD("volume");
                    }

                    function onMutedChanged() {
                        root.triggerSliderOSD("volume");
                    }

                    target: root.audioNode
                    ignoreUnknownSignals: true
                }

                Connections {
                    function onVolumeChanged() {
                        root.triggerSliderOSD("mic");
                    }

                    function onMutedChanged() {
                        root.triggerSliderOSD("mic");
                    }

                    target: root.sourceAudioNode
                    ignoreUnknownSignals: true
                }

                Connections {
                    function onBrightnessChanged() {
                        root.triggerSliderOSD("brightness");
                    }

                    target: Brightness
                }

                MouseArea {
                    id: keystoneMouseArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: !root.contentPresentationActive && !root.isNotifMode && !root.isVolumeMode
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        root.activateMouseAction(mouse.button === Qt.MiddleButton
                                                 ? PersonalizationConfig.keystoneMiddleClickAction :
                                                   PersonalizationConfig.keystoneLeftClickAction, true);
                        mouse.accepted = true;
                    }
                }

                Item {
                    id: staticCanvas

                    transform: Translate {
                        id: contentParallax

                        x: styleSurface.elongated && longFrame.item ? (keystoneWindow.leftEdge ? -1 :
                                                                                                 keystoneWindow.rightEdge
                                                                                                 ? 1 : 0)
                                                                      * longFrame.item.contentOffset : 0
                        y: styleSurface.elongated && longFrame.item ? (keystoneWindow.topEdge ? -1 :
                                                                                                keystoneWindow.bottomEdge
                                                                                                ? 1 : 0)
                                                                      * longFrame.item.contentOffset : 0
                    }
                    enabled: !styleSurface.elongated || root.opacity > 0.1
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1600
                    height: 1200

                    KeyboardLockIndicator {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: keystoneWindow.horizontalEdge ? 260 : 112
                        height: keystoneWindow.horizontalEdge ? 64 : 144
                        vertical: !keystoneWindow.horizontalEdge
                        capsLock: root.sliderMode === "capslock"
                        lockEnabled: root.lockEnabled
                        visible: root.isVolumeMode && root.keyboardOsd
                    }

                    VolumeContent {
                        id: volumeWidget

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.activeLayout.volumeWidth
                        height: root.activeLayout.volumeHeight
                        vertical: !keystoneWindow.horizontalEdge
                        mode: root.sliderMode
                        audioNode: root.sliderMode === "volume" ? root.audioNode : root.sliderMode === "mic"
                                                                  ? root.sourceAudioNode : null
                        externalValue: Brightness.brightnessValue
                        iconName: root.sliderMode === "brightness" ? "brightness_medium" : ""
                        opacity: root.isVolumeMode && !root.keyboardOsd ? 1 : 0
                        visible: opacity > 0.01
                        onMoved: value => {
                            if (root.sliderMode === "brightness")
                                Brightness.setBrightness(value);
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
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
                        width: implicitWidth
                        height: implicitHeight
                        player: root.currentPlayer
                        active: root.isLyricsMode
                        vertical: !keystoneWindow.horizontalEdge
                        edge: keystoneWindow.edge
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
                        id: mediaWidget
                        surfaceTopRightRadius: styleSurface.elongated && longFrame.item
                                               ? longFrame.item.childRadius : rootSurface.topRightRadius

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 20
                        width: root.activeLayout.expandedWidth - 40
                        height: root.activeLayout.expandedHeight - 40
                        opacity: (!root.contentPresentationActive && root.expanded && !root.isLyricsMode &&
                                  !root.isHubMode) ? 1 : 0
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
                        screen: keystoneWindow.screen
                        dragActive: cloudUploadDropArea.containsDrag || longCloudUploadDropArea.containsDrag
                        onCurrentIndexChanged: {
                            if (root.hubTabIndex !== currentIndex)
                                root.hubTabIndex = currentIndex;
                        }
                        Component.onCompleted: {
                            if (currentIndex !== root.hubTabIndex)
                                currentIndex = root.hubTabIndex;
                        }
                        onCloseRequested: root.showHub = false
                        onAvatarEditRequested: {
                            root.showHub = false;
                            styleSurface.avatarEditRequested(keystoneWindow.screen);
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

                        keyboardActive: root.isToolsMode && !root.recordingLaunchPending
                        retainForRecording: styleSurface.elongated
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: implicitWidth
                        height: implicitHeight
                        vertical: !keystoneWindow.horizontalEdge
                        edge: keystoneWindow.edge
                        opacity: root.isToolsMode ? 1 : 0
                        visible: opacity > 0.01
                        onRequestHideKeystone: {
                            root.showTools = false;
                        }
                        onRecordingRequested: {
                            // Keep the current child alive through selection
                            // and startup; cancellation leaves Tools usable.
                            root.hoverOpened = false;
                            hoverIntent.cancel();
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                }

                DropArea {
                    id: cloudUploadDropArea

                    anchors.fill: parent
                    z: 20000
                    enabled: root.cloudUploadDropEnabled
                    onEntered: drag => root.enterCloudUploadDrag(drag)
                    onDropped: drop => root.acceptCloudUploadDrop(drop)
                }

                Connections {
                    function onTransientSurfacesDismissRequested() {
                        root.closeKeystonePopups();
                    }

                    target: WidgetState
                }

                MouseArea {
                    id: collapsedInputArea

                    anchors.fill: parent
                    z: 10000
                    enabled: root.isCollapsedMode
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        root.activateMouseAction(mouse.button === Qt.MiddleButton
                                                 ? PersonalizationConfig.keystoneMiddleClickAction :
                                                   PersonalizationConfig.keystoneLeftClickAction, true);
                        mouse.accepted = true;
                    }
                }

                Behavior on width {
                    enabled: !styleSurface.elongated && !(styleSurface.splitRecording
                                                          && root.recordingPresentationActive
                                                          && keystoneWindow.horizontalEdge)

                    NumberAnimation {
                        duration: root.wDuration
                        easing.type: KeystoneMotion.type
                        easing.bezierCurve: root.wBezier
                    }
                }

                Behavior on height {
                    enabled: !styleSurface.elongated && !(styleSurface.splitRecording
                                                          && root.recordingPresentationActive &&
                                                          !keystoneWindow.horizontalEdge)

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
            }

            AudioRecordingVisual {
                id: audioRecordingVisual

                parent: styleSurface.elongated ? root : maskContainer
                anchors.centerIn: root
                width: root.width
                height: root.height
                sessionActive: root.audioPresentationActive
                recording: AudioRecordingService.isRecording
                stopping: AudioRecordingService.isStopPending
                sourceNodeName: AudioRecordingService.sourceNodeName
                captureSink: AudioRecordingService.captureSink
                elapsedMs: AudioRecordingService.elapsedMs
                vertical: !keystoneWindow.horizontalEdge
                edge: keystoneWindow.edge
                visible: root.audioPresentationActive || contentProgress > 0.01
                opacity: 1
                z: root.z + 3
                onStopRequested: AudioRecordingService.stop()
                onCollapseRequested: {
                    if (!root.audioSessionActive)
                        root.audioPresentationPhase = root.audioPhaseCollapsing;
                }
                onExitFinished: {
                    root.audioPresentationPhase = root.audioSessionActive ? root.audioPhaseExpanded :
                                                                            root.audioPhaseHidden;
                }
            }

            ClockContent {
                id: clockContent

                anchors.fill: root
                player: root.currentPlayer
                edge: keystoneWindow.edge
                opacity: !styleSurface.elongated && root.isCollapsedMode ? 1 : 0
                scale: 0.96 + 0.04 * opacity
                visible: opacity > 0.01
                z: root.z + 4

                transform: Translate {
                    y: (1 - clockContent.opacity) * 4
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.isCollapsedMode ? Appearance.animation.expressiveSlowEffects.duration :
                                                         Appearance.animation.expressiveFastEffects.duration
                        easing.type: root.isCollapsedMode ? Appearance.animation.expressiveSlowEffects.type :
                                                            Appearance.animation.expressiveFastEffects.type
                        easing.bezierCurve: root.isCollapsedMode
                                            ? Appearance.animation.expressiveSlowEffects.bezierCurve :
                                              Appearance.animation.expressiveFastEffects.bezierCurve
                    }
                }
            }

            Loader {
                id: pillRecordingPresenter

                anchors.fill: root
                visible: styleSurface.splitRecording && root.recordingPresentationActive
                sourceComponent: keystoneWindow.horizontalEdge ? horizontalPillRecordingComponent :
                                                                 verticalPillRecordingComponent
                z: root.z + 2
            }

            Component {
                id: horizontalPillRecordingComponent

                HorizontalPillRecordingVisual {
                    active: root.recordingPresentationActive
                    recording: root.isRecording
                    finalizing: root.isFinalizing
                    recordingType: RecordingService.recordingType
                    elapsedMs: RecordingService.elapsedMs
                    morphProgress: root.pillMorphProgress
                    recordingInfoProgress: root.recordingInfoProgress
                    recordingActionProgress: root.recordingActionProgress
                    processingContentProgress: root.processingContentProgress
                    baseMainWidth: horizontalLayout.collapsedWidth
                    layoutHeight: horizontalLayout.collapsedHeight
                    edge: keystoneWindow.edge
                }
            }

            Component {
                id: verticalPillRecordingComponent

                VerticalPillRecordingVisual {
                    active: root.recordingPresentationActive
                    recording: root.isRecording
                    finalizing: root.isFinalizing
                    recordingType: RecordingService.recordingType
                    elapsedMs: RecordingService.elapsedMs
                    morphProgress: root.pillMorphProgress
                    recordingInfoProgress: root.recordingInfoProgress
                    recordingActionProgress: root.recordingActionProgress
                    processingContentProgress: root.processingContentProgress
                    baseMainHeight: verticalLayout.collapsedHeight
                    layoutWidth: verticalLayout.collapsedWidth
                    edge: keystoneWindow.edge
                }
            }

            Connections {
                function onStopRequested() {
                    if (!RecordingService.stop())
                        return;

                    root.pillStopFusionMinimumActive = true;
                }

                target: pillRecordingPresenter.item
            }

            BangsRecordingVisual {
                id: bangsRecordingVisual

                parent: styleSurface.elongated ? root : maskContainer
                anchors.centerIn: root
                width: root.width
                height: root.height
                opacity: entryProgress
                active: !styleSurface.splitRecording && root.recordingPresentationActive
                recording: !styleSurface.splitRecording && root.isRecording
                finalizing: !styleSurface.splitRecording && root.isFinalizing
                recordingType: RecordingService.recordingType
                elapsedMs: RecordingService.elapsedMs
                recordingInfoProgress: root.recordingInfoProgress
                recordingActionProgress: root.recordingActionProgress
                processingContentProgress: root.processingContentProgress
                vertical: !keystoneWindow.horizontalEdge
                edge: keystoneWindow.edge
                visible: !styleSurface.splitRecording && (active || opacity > 0.01)
                z: root.z + 2
                onStopRequested: RecordingService.stop()
            }

            AttachedEdgeCurve {
                id: rightTopCurve

                visible: styleSurface.showAttachedEdgeCurves
                edge: keystoneWindow.edge
                after: true
                along: keystoneWindow.edgeCurveAlong
                depth: keystoneWindow.edgeCurveDepth
                sideControl: keystoneWindow.edgeCurveSideControl
                edgeControl: keystoneWindow.edgeCurveOuterControl
                fillColor: root.color

                anchors {
                    left: keystoneWindow.leftEdge ? root.left : (keystoneWindow.horizontalEdge ? root.right :
                                                                                                 undefined)

                    right: keystoneWindow.rightEdge ? root.right : undefined
                    top: keystoneWindow.topEdge ? root.top : (!keystoneWindow.horizontalEdge ? root.bottom :
                                                                                               undefined)
                    bottom: keystoneWindow.bottomEdge ? root.bottom : undefined
                }

                Connections {
                    function onColorChanged() {
                        rightTopCurve.requestPaint();
                    }

                    target: root
                }
            }

            CompositorBlurRegion {
                targetWindow: keystoneWindow
                backgroundItem: styleSurface.elongated || root.useRecordingBlurRegions ? null : root
                additionalBackgroundItems: styleSurface.elongated && longFrame.item
                                           ? longFrame.item.blurItems : root.recordingBlurBackgroundItems
                subtractedBackgroundItems: !root.showDashboardKeyhole ? [] : styleSurface.elongated
                                                                        && longFrame.item
                                                                        ? [longFrame.item.cutoutBlurItem] :
                                                                          [dashboardKeyholeCutout]
                postSubtractionBackgroundItems: root.showDashboardKeyhole && root.visible && root.opacity
                                                > 0.01 && hub.opacity > 0.01 ? hub.dashboardKeyholeGlassItems :
                                                                               []
                postSubtractionClipItem: styleSurface.elongated && longFrame.item
                                         ? longFrame.item.childBlurItem : root
                radius: root.radius
            }
        }

        mask: Region {
            Region {
                item: styleSurface.elongated ? (longFrame.item ? longFrame.item.mainItem : null) :
                                               maskContainer

                radius: styleSurface.elongated ? 21 : 0
            }
            Region {
                item: styleSurface.elongated && longFrame.item && longFrame.item.progress > 0.02 ? root : null
                radius: styleSurface.elongated && longFrame.item ? longFrame.item.childRadius : 0
            }
        }
    }

    component SurfaceShape: Canvas {

        required property color surfaceColor
        required property real topLeftRadius
        required property real topRightRadius
        required property real bottomRightRadius
        required property real bottomLeftRadius
        required property bool cutoutVisible
        required property real cutoutX
        required property real cutoutY
        required property real cutoutWidth
        required property real cutoutHeight
        required property real cutoutRadius

        function addRoundedRect(context, x, y, width, height, topLeft, topRight, bottomRight, bottomLeft) {
            const maxRadius = Math.min(width / 2, height / 2);
            const tl = Math.min(topLeft, maxRadius);
            const tr = Math.min(topRight, maxRadius);
            const br = Math.min(bottomRight, maxRadius);
            const bl = Math.min(bottomLeft, maxRadius);
            context.beginPath();
            context.moveTo(x + tl, y);
            context.lineTo(x + width - tr, y);
            context.quadraticCurveTo(x + width, y, x + width, y + tr);
            context.lineTo(x + width, y + height - br);
            context.quadraticCurveTo(x + width, y + height, x + width - br, y + height);
            context.lineTo(x + bl, y + height);
            context.quadraticCurveTo(x, y + height, x, y + height - bl);
            context.lineTo(x, y + tl);
            context.quadraticCurveTo(x, y, x + tl, y);
            context.closePath();
        }

        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.clearRect(0, 0, width, height);
            addRoundedRect(context, 0, 0, width, height, topLeftRadius, topRightRadius, bottomRightRadius,
                           bottomLeftRadius);
            context.fillStyle = surfaceColor;
            context.fill();
            if (cutoutVisible) {
                context.globalCompositeOperation = "destination-out";
                addRoundedRect(context, cutoutX, cutoutY, cutoutWidth, cutoutHeight, cutoutRadius,
                               cutoutRadius, cutoutRadius, cutoutRadius);
                context.fillStyle = "white";
                context.fill();
                context.globalCompositeOperation = "source-over";
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onSurfaceColorChanged: requestPaint()
        onTopLeftRadiusChanged: requestPaint()
        onTopRightRadiusChanged: requestPaint()
        onBottomRightRadiusChanged: requestPaint()
        onBottomLeftRadiusChanged: requestPaint()
        onCutoutVisibleChanged: requestPaint()
        onCutoutXChanged: requestPaint()
        onCutoutYChanged: requestPaint()
        onCutoutWidthChanged: requestPaint()
        onCutoutHeightChanged: requestPaint()
        onCutoutRadiusChanged: requestPaint()
    }
}
