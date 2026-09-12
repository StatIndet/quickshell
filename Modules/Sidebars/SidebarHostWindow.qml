import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import "../../Common/SidebarPolicy.js" as SidebarPolicy
import qs.Modules.Sidebars.Dashboard
import qs.Modules.Sidebars.QuickSettings
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    function sidebarOpen(target) {
        const role = SidebarPolicy.normalizeTarget(target);
        if (role === "dashboard")
            return WidgetState.dashboardSidebarOpen;
        if (role === "quicksettings")
            return WidgetState.quickSettingsOpen;
        return null;
    }

    function setSidebarOpen(target, open) {
        const role = SidebarPolicy.normalizeTarget(target);
        if (role === "")
            return "INVALID_SIDE";
        if (role === "dashboard")
            WidgetState.dashboardSidebarOpen = open;
        else
            WidgetState.quickSettingsOpen = open;
        const legacy = String(target || "").trim().toLowerCase();
        const label = legacy === "left" || legacy === "right" ? legacy : role;
        return label.toUpperCase() + (open ? "_OPEN" : "_CLOSED");
    }

    function opened(role) {
        const requested = role === "quicksettings" ? Brightness.getScreenByName(
                                                         WidgetState.quickSettingsScreenName) : null;
        const nextScreen = requested || Brightness.activeScreen;
        if (nextScreen)
            retainedScreenName = nextScreen.name;
    }

    readonly property bool anySidebarOpen: WidgetState.dashboardSidebarOpen || WidgetState.quickSettingsOpen
    readonly property var fallbackScreen: Brightness.activeScreen || (Quickshell.screens.length > 0
                                                                      ? Quickshell.screens[0] : null)
    // DPMS cycles can replace the Screen instance while preserving its name.
    property string retainedScreenName: ""
    readonly property var retainedScreen: Brightness.getScreenByName(retainedScreenName)

    screen: retainedScreen || fallbackScreen
    onScreenChanged: WidgetState.sidebarScreenName = screen ? screen.name : ""
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
    WlrLayershell.keyboardFocus: root.anySidebarOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    IpcHandler {
        target: "sidebar"

        function open(target: string): string {
            return root.setSidebarOpen(target, true);
        }

        function close(target: string): string {
            return root.setSidebarOpen(target, false);
        }

        function toggle(target: string): string {
            const current = root.sidebarOpen(target);
            if (current === null)
                return "INVALID_SIDE";
            return root.setSidebarOpen(target, !current);
        }
    }

    mask: Region {
        item: root.anySidebarOpen ? interactionRegion : null
    }

    Component.onCompleted: {
        if (root.fallbackScreen)
            root.retainedScreenName = root.fallbackScreen.name;
        WidgetState.sidebarScreenName = root.screen ? root.screen.name : "";
    }

    Connections {
        target: WidgetState

        function onQuickSettingsScreenNameChanged() {
            const requestedScreen = Brightness.getScreenByName(WidgetState.quickSettingsScreenName);
            if (requestedScreen)
                root.retainedScreenName = requestedScreen.name;
        }

        function onDashboardSidebarOpenChanged() {
            if (WidgetState.dashboardSidebarOpen)
                root.opened("dashboard");
        }

        function onQuickSettingsOpenChanged() {
            if (WidgetState.quickSettingsOpen)
                root.opened("quicksettings");
        }
    }

    Connections {
        target: PersonalizationConfig
        function onDashboardSidebarSideChanged() {
            if (SystemCardDragSession.active)
                SystemCardDragSession.requestCancel();
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
            if (WidgetState.dashboardSidebarOpen && !dashboardSidebar.containsPoint(mouse.x, mouse.y))
                WidgetState.dashboardSidebarOpen = false;

            if (WidgetState.quickSettingsOpen && !quickSettingsSidebar.containsPoint(mouse.x, mouse.y))
                WidgetState.quickSettingsOpen = false;
        }
    }

    DashboardSidebar {
        id: dashboardSidebar

        anchors.fill: parent
        panelScreen: root.screen
    }

    QuickSettingsSidebar {
        id: quickSettingsSidebar

        anchors.fill: parent
        panelScreen: root.screen
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: dashboardSidebar.blurBackgroundItem
        additionalBackgroundItems: [quickSettingsSidebar.blurBackgroundItem]
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
