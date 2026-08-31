import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Modules.Sidebars.Left
import qs.Modules.Sidebars.Right
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    function sidebarOpen(side) {
        const normalized = String(side || "").toLowerCase();
        if (normalized === "left")
            return WidgetState.leftSidebarOpen;
        if (normalized === "right")
            return WidgetState.qsOpen;
        return null;
    }

    function setSidebarOpen(side, open) {
        const normalized = String(side || "").toLowerCase();
        if (normalized === "left") {
            WidgetState.leftSidebarOpen = open;
            return open ? "LEFT_OPEN" : "LEFT_CLOSED";
        }
        if (normalized === "right") {
            WidgetState.qsOpen = open;
            return open ? "RIGHT_OPEN" : "RIGHT_CLOSED";
        }
        return "INVALID_SIDE";
    }

    readonly property bool anySidebarOpen:
        WidgetState.leftSidebarOpen || WidgetState.qsOpen
    readonly property var fallbackScreen: Brightness.activeScreen
        || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    // DPMS cycles can replace the Screen instance while preserving its name.
    property string retainedScreenName: ""
    readonly property var retainedScreen:
        Brightness.getScreenByName(retainedScreenName)

    screen: retainedScreen || fallbackScreen
    visible: retainedScreen !== null || fallbackScreen !== null
    color: "transparent"
    exclusiveZone: 0

    anchors {
        left: true
        top: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-sidebars"
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: root.anySidebarOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    IpcHandler {
        target: "sidebar"

        function open(side: string): string {
            return root.setSidebarOpen(side, true);
        }

        function close(side: string): string {
            return root.setSidebarOpen(side, false);
        }

        function toggle(side: string): string {
            const current = root.sidebarOpen(side);
            if (current === null)
                return "INVALID_SIDE";
            return root.setSidebarOpen(side, !current);
        }

    }

    mask: Region {
        item: root.anySidebarOpen ? interactionRegion : null
    }

    Component.onCompleted: {
        if (root.fallbackScreen)
            root.retainedScreenName = root.fallbackScreen.name;
    }

    Connections {
        target: WidgetState

        function onQsScreenNameChanged() {
            const requestedScreen =
                Brightness.getScreenByName(WidgetState.qsScreenName);
            if (requestedScreen)
                root.retainedScreenName = requestedScreen.name;
        }

        function onLeftSidebarOpenChanged() {
            if (WidgetState.leftSidebarOpen && !WidgetState.qsOpen
                    && Brightness.activeScreen)
                root.retainedScreenName = Brightness.activeScreen.name;
        }
    }

    Item {
        id: interactionRegion

        anchors.fill: parent
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.anySidebarOpen
        acceptedButtons: Qt.LeftButton

        onClicked: mouse => {
            if (WidgetState.leftSidebarOpen
                    && !leftSidebar.containsPoint(mouse.x, mouse.y))
                WidgetState.leftSidebarOpen = false;

            if (WidgetState.qsOpen
                    && !rightSidebar.containsPoint(mouse.x, mouse.y))
                WidgetState.qsOpen = false;
        }
    }

    LeftSidebarWindow {
        id: leftSidebar

        anchors.fill: parent
        panelScreen: root.screen
    }

    RightSidebar {
        id: rightSidebar

        anchors.fill: parent
        panelScreen: root.screen
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: leftSidebar.blurBackgroundItem
        additionalBackgroundItems: [
            rightSidebar.blurBackgroundItem
        ]
    }

    Shortcut {
        sequence: "Esc"
        context: Qt.WindowShortcut
        enabled: root.anySidebarOpen
        onActivated: {
            if (SystemCardDragSession.active) {
                SystemCardDragSession.requestCancel();
                return;
            }

            WidgetState.closeAllPopups();
        }
    }
}
