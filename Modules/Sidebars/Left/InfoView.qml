import QtQuick
import QtQuick.Layouts
import Clavis.Sysmon 1.0
import qs.Common
import qs.Services
import qs.Widgets.common
import "./notifications"

Item {
    id: root

    readonly property int fetchCardHeight: 252

    readonly property bool isForeground: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "info"
    onIsForegroundChanged: {
        if (isForeground) {
            NotificationManager.timeoutAll();
            NotificationManager.markAllRead();
        }
    }

    StyledFlickable {
        id: flick
        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 2

        ColumnLayout {
            id: contentColumn
            width: flick.width
            spacing: 12

            SystemFetchCard {
                Layout.fillWidth: true
                Layout.preferredHeight: root.fetchCardHeight
                radius: 24
                cardPadding: 16
                systemUser: SysmonPlugin.systemUser
                hostName: SysmonPlugin.hostName
                chassis: SysmonPlugin.chassis
                uptime: SysmonPlugin.uptime
                osAge: SysmonPlugin.osAgeText
                kernelRelease: SysmonPlugin.kernelRelease
                wmName: SysmonPlugin.wmName
                shellName: SysmonPlugin.shellName
                distroId: SysmonPlugin.distroId
            }

            NotificationList {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(360, flick.height - root.fetchCardHeight - contentColumn.spacing)
            }
        }
    }

}
