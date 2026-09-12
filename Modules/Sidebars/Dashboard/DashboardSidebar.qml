import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    signal presentationClosed

    property var panelScreen: null
    readonly property bool onLeft: PersonalizationConfig.dashboardSidebarSide === "left"
    property real sidebarWidth: Math.min(Metrics.sidebarWidthComfortable, Math.max(0, width - gap * 2))
    property int gap: Math.min(Metrics.pageMargin, Math.max(Metrics.spacingS, Math.min(width, height)
                                                            * 0.025))
    readonly property alias blurBackgroundItem: panelSurface
    // The host window already starts inside layer-shell's usable geometry.
    readonly property int sidebarY: gap
    readonly property real closedSlideOffset: (onLeft ? -1 : 1) * (sidebarWidth + gap)
    readonly property int enterDuration: Animations.durations.sidebarEnter
    readonly property int exitDuration: Animations.durations.sidebarExit
    readonly property int panelTargetHeight: Math.max(0, height - sidebarY - gap)
    readonly property bool requestedOpen: WidgetState.dashboardSidebarOpen
    property bool panelPresented: false
    property bool contentRetained: false
    property bool presentationOpen: false
    property bool keepLoaded: PersonalizationConfig.keepSidebarsLoaded
    property var weatherSourceOverride: null
    readonly property bool contentReady: sidebarContentLoader.status === Loader.Ready
                                         && sidebarContentLoader.item !== null
                                         && sidebarContentLoader.item.readyForPresentation
    // A presented surface is only created after contentReady. It remains
    // operational during closing so its contents leave with the panel.
    readonly property bool contentOperational: panelPresented
    readonly property bool panelVisuallyPresent: panelPresented
    readonly property string activeView: WidgetState.dashboardSidebarView
    readonly property int instantiatedViewCount: sidebarContentLoader.item
                                                 ? sidebarContentLoader.item.instantiatedViewCount : 0
    readonly property var weatherView: sidebarContentLoader.item ? sidebarContentLoader.item.weatherView :
                                                                   null
    function preparePresentation() {
        contentRetained = true;
        startPresentation();
    }

    function startPresentation() {
        if (!requestedOpen || !contentReady)
            return;
        panelPresented = true;
        presentationOpen = true;
    }

    function beginClosing() {
        presentationOpen = false;
        if (panelPresented)
            return;
        if (!keepLoaded)
            contentRetained = false;
        root.presentationClosed();
    }

    function finishClosing() {
        if (requestedOpen)
            return;

        // Hide the already off-screen surface before releasing its layout tree.
        panelPresented = false;
        if (!root.keepLoaded)
            contentRetained = false;
        root.presentationClosed();
    }

    Component.onCompleted: {
        // Retain after the first open; keeping content warm must not
        // instantiate the entire sidebar during shell startup.
        if (requestedOpen)
            preparePresentation();
    }

    onRequestedOpenChanged: {
        if (requestedOpen)
            preparePresentation();
        else
            beginClosing();
    }

    onContentReadyChanged: {
        if (contentReady)
            startPresentation();
    }

    onKeepLoadedChanged: {
        if (!root.keepLoaded && !requestedOpen && !root.panelPresented) {
            root.contentRetained = false;
        }
    }

    function containsPoint(hostX, hostY) {
        const localPosition = sidebarContentFrame.mapFromItem(root, hostX, hostY);
        return localPosition.x >= 0 && localPosition.x <= sidebarContentFrame.width && localPosition.y >= 0
                && localPosition.y <= sidebarContentFrame.height;
    }

    Item {
        id: animController

        property real slideOffset: root.closedSlideOffset

        state: root.presentationOpen ? "open" : "closed"

        states: [
            State {
                name: "open"

                PropertyChanges {
                    target: animController
                    slideOffset: 0
                }
            },
            State {
                name: "closed"

                PropertyChanges {
                    target: animController
                    slideOffset: root.closedSlideOffset
                }
            }
        ]

        transitions: [
            Transition {
                id: openTransition
                to: "open"

                NumberAnimation {
                    target: animController
                    property: "slideOffset"
                    duration: root.enterDuration
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.3
                }
            },
            Transition {
                id: closeTransition
                to: "closed"

                SequentialAnimation {
                    NumberAnimation {
                        target: animController
                        property: "slideOffset"
                        duration: root.exitDuration
                        easing.type: Easing.InBack
                        easing.overshoot: 0.18
                    }

                    ScriptAction {
                        script: root.finishClosing()
                    }
                }
            }
        ]
    }

    Rectangle {
        id: panelSurface

        visible: root.panelVisuallyPresent
        x: (root.onLeft ? root.gap : root.width - root.sidebarWidth - root.gap) + animController.slideOffset
        y: root.sidebarY
        width: root.sidebarWidth
        height: root.panelTargetHeight
        color: BlurService.backgroundColor(Appearance.colors.colLayer0)
        radius: Appearance.rounding.large
    }

    Item {
        id: sidebarContentFrame

        visible: root.panelVisuallyPresent
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height
        clip: true

        Loader {
            id: sidebarContentLoader

            anchors.fill: parent
            active: root.contentRetained
            asynchronous: true
            sourceComponent: dashboardSidebarContentComponent
        }
    }

    Component {
        id: dashboardSidebarContentComponent

        DashboardSidebarContent {
            anchors.fill: parent
            screenName: root.panelScreen ? root.panelScreen.name : ""
            weatherSourceOverride: root.weatherSourceOverride
            foreground: root.contentOperational
            presentationActive: root.contentOperational
        }
    }
}
