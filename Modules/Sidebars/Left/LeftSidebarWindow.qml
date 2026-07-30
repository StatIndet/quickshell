import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

Item {
    id: root

    property var panelScreen: null
    property int sidebarWidth: 540
    property int gap: 24
    readonly property alias blurBackgroundItem: panelSurface
    readonly property int sidebarY: Sizes.barHeight + gap
    readonly property real closedSlideOffset: -(sidebarWidth + gap)
    readonly property int enterDuration: Animations.durations.large
    readonly property int exitDuration: Animations.durations.large
    readonly property int qsTargetHeight:
        Math.max(0, height - sidebarY - gap)
    property bool panelPresented: false
    property bool contentRetained: false
    property bool contentAnimationsActive: false
    readonly property bool panelActive:
        WidgetState.leftSidebarOpen || panelPresented

    function beginPresentation() {
        panelPresented = true
        contentRetained = true
        contentAnimationsActive = false
    }

    function finishClosing() {
        if (WidgetState.leftSidebarOpen)
            return

        // Hide the already off-screen surface before releasing its layout tree.
        panelPresented = false
        contentAnimationsActive = false
        if (!PersonalizationConfig.keepSidebarsLoaded)
            contentRetained = false
    }

    Component.onCompleted: {
        panelPresented = WidgetState.leftSidebarOpen
        contentAnimationsActive = WidgetState.leftSidebarOpen
        contentRetained = WidgetState.leftSidebarOpen
            || PersonalizationConfig.keepSidebarsLoaded
    }

    Connections {
        target: WidgetState

        function onLeftSidebarOpenChanged() {
            if (WidgetState.leftSidebarOpen)
                root.beginPresentation()
            else
                root.contentAnimationsActive = false
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
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.3
                    }

                    ScriptAction {
                        script: {
                            if (WidgetState.leftSidebarOpen)
                                root.contentAnimationsActive = true
                        }
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

    MultiEffect {
        anchors.fill: panelSurface
        source: panelSurface
        visible: root.panelActive
            && !openTransition.running
            && !closeTransition.running
        shadowEnabled: true
        shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.44)
        shadowBlur: 0.72
        shadowHorizontalOffset: 2
        shadowVerticalOffset: 6
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
        border.width: 1
        border.color: Qt.alpha(
            Appearance.colors.colOutlineVariant, 0.58)
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
            foreground: WidgetState.leftSidebarOpen
            presentationActive: root.contentAnimationsActive
        }
    }
}
