import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property var panelScreen: null
    property int sidebarWidth: 540
    property int gap: 24
    readonly property alias blurBackgroundItem: blurRegionAnchor
    readonly property int sidebarY: Sizes.barHeight + gap
    readonly property real closedSlideOffset: -(sidebarWidth + gap)
    readonly property int enterDuration:
        Animations.animation.expressiveFastSpatial.duration
    readonly property int exitDuration:
        Animations.animation.emphasizedAccel.duration
    readonly property int qsTargetHeight:
        Math.max(0, height - sidebarY - gap)
    property bool panelPresented: false
    property bool contentRetained: false
    property bool blurActive: false
    property bool contentActive: false
    readonly property bool panelActive:
        WidgetState.leftSidebarOpen || panelPresented

    function beginPresentation() {
        panelPresented = true
        contentRetained = true
        blurActive = false
        contentActive = false
        contentActivationTimer.stop()
    }

    function finishOpening() {
        if (!WidgetState.leftSidebarOpen)
            return

        // Submit the final, stationary blur region first, then wake services
        // and content animations on a later frame instead of piling all work
        // onto the last frame of the slide transition.
        blurActive = true
        contentActivationTimer.restart()
    }

    function finishClosing() {
        if (WidgetState.leftSidebarOpen)
            return

        // Hide the already off-screen surface before releasing its layout tree.
        panelPresented = false
        if (!PersonalizationConfig.keepSidebarsLoaded)
            contentRetained = false
    }

    Component.onCompleted: {
        panelPresented = WidgetState.leftSidebarOpen
        contentRetained = WidgetState.leftSidebarOpen
            || PersonalizationConfig.keepSidebarsLoaded
        blurActive = WidgetState.leftSidebarOpen
        contentActive = WidgetState.leftSidebarOpen
    }

    Connections {
        target: WidgetState

        function onLeftSidebarOpenChanged() {
            if (WidgetState.leftSidebarOpen)
                root.beginPresentation()
            else {
                contentActivationTimer.stop()
                root.blurActive = false
                root.contentActive = false
            }
        }
    }

    Connections {
        target: PersonalizationConfig

        function onKeepSidebarsLoadedChanged() {
            if (PersonalizationConfig.keepSidebarsLoaded) {
                root.contentRetained = true
            } else if (!WidgetState.leftSidebarOpen
                    && !root.panelPresented) {
                root.contentRetained = false
            }
        }
    }

    function containsPoint(hostX, hostY) {
        const localPosition =
            sidebarContentFrame.mapFromItem(root, hostX, hostY);
        return localPosition.x >= 0
            && localPosition.x <= sidebarContentFrame.width
            && localPosition.y >= 0
            && localPosition.y <= sidebarContentFrame.height;
    }

    Timer {
        id: contentActivationTimer

        interval: 50
        repeat: false
        onTriggered: {
            if (WidgetState.leftSidebarOpen)
                root.contentActive = true
        }
    }

    Item {
        id: animController

        property real slideOffset: root.closedSlideOffset

        state: WidgetState.leftSidebarOpen ? "open" : "closed"

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

                SequentialAnimation {
                    NumberAnimation {
                        target: animController
                        property: "slideOffset"
                        duration: root.enterDuration
                        easing.type:
                            Animations.animation.expressiveFastSpatial.type
                        easing.bezierCurve:
                            Animations.animation.expressiveFastSpatial.bezierCurve
                    }

                    ScriptAction {
                        script: root.finishOpening()
                    }
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
                        easing.type:
                            Animations.animation.emphasizedAccel.type
                        easing.bezierCurve:
                            Animations.animation.emphasizedAccel.bezierCurve
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

        visible: root.panelActive
        x: animController.slideOffset + root.gap
        y: root.sidebarY
        width: root.sidebarWidth
        height: root.qsTargetHeight
        color: BlurService.backgroundColor(
            Appearance.colors.colLayer0)
        radius: Appearance.rounding.large
    }

    // Keep compositor blur out of slide animations. Updating a moving
    // blur region every frame is considerably more expensive than moving the
    // already rendered panel surface.
    Item {
        id: blurRegionAnchor

        visible: root.blurActive
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height
        property real radius: panelSurface.radius
    }

    Item {
        id: sidebarContentFrame

        visible: root.panelActive
        x: panelSurface.x
        y: panelSurface.y
        width: panelSurface.width
        height: panelSurface.height
        clip: true

        Loader {
            anchors.fill: parent
            active: PersonalizationConfig.keepSidebarsLoaded
                || WidgetState.leftSidebarOpen
                || root.contentRetained
            sourceComponent: leftSidebarContentComponent
        }
    }

    Component {
        id: leftSidebarContentComponent

        LeftSidebarContent {
            anchors.fill: parent
            screenName: root.panelScreen ? root.panelScreen.name : ""
            foreground: root.contentActive
            presentationActive: root.contentActive
        }
    }
}
