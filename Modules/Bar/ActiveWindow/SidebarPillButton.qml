import QtQuick
import qs.Common
import qs.Widgets.common

BarCircularButton {
    id: root

    property string viewName: "info"
    property string sidebarIconName: "notifications"
    property color activeColor: Appearance.colors.colSecondaryContainer
    property color activeContentColor: Appearance.colors.colOnSecondaryContainer
    readonly property bool isActive: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView
                                     === root.viewName

    function toggleView() {
        if (root.isActive) {
            WidgetState.leftSidebarOpen = false;
            return;
        }
        WidgetState.leftSidebarView = root.viewName;
        WidgetState.leftSidebarOpen = true;
    }

    selected: root.isActive
    iconName: root.sidebarIconName
    containerColor: root.activeColor
    rippleColor: root.activeContentColor
    iconColor: root.activeContentColor
    tooltipText: root.viewName === "drawer" ? qsTr("Drawer") : qsTr("Notification center")
    onClicked: root.toggleView()
}
