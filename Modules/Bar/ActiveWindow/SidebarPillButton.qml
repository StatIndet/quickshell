import QtQuick
import qs.Common
import qs.Widgets.common

BarCircularButton {
    id: root

    property string viewName: "info"
    property string sidebarIconName: "notifications"
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
    containerColor: "transparent"
    rippleColor: BarColors.foreground
    iconColor: BarColors.foreground
    tooltipText: root.viewName === "drawer" ? qsTr("Drawer") : qsTr("Notification center")
    onClicked: root.toggleView()
}
