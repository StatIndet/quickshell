import QtQuick
import qs.Common
import qs.Widgets.common

BarCircularButton {
    id: root

    property string viewName: "info"
    property string sidebarIconName: "notifications"
    property color activeColor: Appearance.colors.colSecondaryContainer
    property color activeContentColor: Appearance.colors.colOnSecondaryContainer
    readonly property bool isActive: WidgetState.dashboardSidebarOpen && WidgetState.dashboardSidebarView
                                     === root.viewName

    function toggleView() {
        if (root.isActive) {
            WidgetState.dashboardSidebarOpen = false;
            return;
        }
        WidgetState.dashboardSidebarView = root.viewName;
        WidgetState.dashboardSidebarOpen = true;
    }

    selected: root.isActive
    iconName: root.sidebarIconName
    containerColor: root.activeColor
    rippleColor: root.activeContentColor
    iconColor: root.activeContentColor
    tooltipText: root.viewName === "drawer" ? qsTr("Drawer") : qsTr("Notification center")
    onClicked: root.toggleView()
}
