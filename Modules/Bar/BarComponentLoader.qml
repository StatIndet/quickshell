import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.ActiveWindow
import qs.Modules.Bar.Tray
import qs.Modules.Bar.SysMonitor
import qs.Modules.Bar.QuickSettings

Loader {
    id: root

    required property string componentId
    required property var screen
    required property var axis
    required property Item barVisualItem
    property bool vertical: false

    sourceComponent: {
        switch (root.componentId) {
        case "workspaces":
            return workspacesComponent;
        case "information":
            return informationComponent;
        case "activeWindow":
            return activeWindowComponent;
        case "tray":
            return trayComponent;
        case "systemMonitor":
            return systemMonitorComponent;
        case "quickSettings":
            return quickSettingsComponent;
        default:
            return null;
        }
    }

    Component {
        id: workspacesComponent

        Workspaces {
            screenName: root.screen.name
            vertical: root.vertical
        }

    }

    Component {
        id: informationComponent

        SidebarButton {
            vertical: root.vertical
        }

    }

    Component {
        id: activeWindowComponent

        ActiveWindow {
            vertical: root.vertical
        }

    }

    Component {
        id: trayComponent

        Tray {
            screen: root.screen
            edge: root.axis.edge
            vertical: root.vertical
            barVisualItem: root.barVisualItem
        }

    }

    Component {
        id: systemMonitorComponent

        SysMonitor {
            ownerId: "bar-sysmonitor:" + root.screen.name
            vertical: root.vertical
        }

    }

    Component {
        id: quickSettingsComponent

        QuickSettings {
            screen: root.screen
            vertical: root.vertical
        }

    }

}
