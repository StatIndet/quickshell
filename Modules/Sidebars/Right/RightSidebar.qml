import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

Item {
    id: root

    property var panelScreen: null
    property int sidebarWidth: 420
    property int gap: 24
    readonly property alias blurBackgroundItem: panelSurface
    property int qsTargetHeight: 640
    readonly property int sidebarY: Sizes.barHeight + gap
    readonly property real closedSlideOffset: sidebarWidth + gap
    readonly property int enterDuration: Animations.durations.large
    readonly property int exitDuration: Animations.durations.large
    property bool panelPresented: false
    property bool contentRetained: false
    readonly property bool panelActive:
        WidgetState.qsOpen || panelPresented

    function beginPresentation() {
        panelPresented = true
        contentRetained = true
    }

    function finishClosing() {
        if (WidgetState.qsOpen)
            return

        // Hide the already off-screen surface before releasing its layout tree.
        panelPresented = false
        if (!PersonalizationConfig.keepSidebarsLoaded)
            contentRetained = false
    }

    Component.onCompleted: {
        panelPresented = WidgetState.qsOpen
        contentRetained = WidgetState.qsOpen
            || PersonalizationConfig.keepSidebarsLoaded
    }

    Connections {
        target: WidgetState

        function onQsOpenChanged() {
            if (WidgetState.qsOpen)
                root.beginPresentation()
        }
    }

    Connections {
        target: PersonalizationConfig

        function onKeepSidebarsLoadedChanged() {
            if (PersonalizationConfig.keepSidebarsLoaded) {
                root.contentRetained = true
            } else if (!WidgetState.qsOpen
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

        state: WidgetState.qsOpen ? "open" : "closed"

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

    MultiEffect {
        anchors.fill: panelSurface
        source: panelSurface
        // Render the shadow while the panel is moving as well as when it is
        // stationary so its border does not pop in at the end of the slide.
        visible: root.panelActive
        shadowEnabled: true
        shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.44)
        shadowBlur: 0.72
        shadowHorizontalOffset: -2
        shadowVerticalOffset: 6
    }

    Rectangle {
        id: panelSurface

        visible: root.panelActive
        x: root.width - root.sidebarWidth - root.gap
            + animController.slideOffset
        y: root.sidebarY
        width: root.sidebarWidth
        height: Math.min(root.qsTargetHeight,
            Math.max(0, root.height - root.sidebarY - root.gap))
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
                || WidgetState.qsOpen
                || root.contentRetained
            sourceComponent: quickSettingsComponent
        }
    }

    Component {
        id: quickSettingsComponent

        QuickSettings {
            anchors.fill: parent
            screen: root.panelScreen
            foreground: WidgetState.qsOpen
        }
    }
}
