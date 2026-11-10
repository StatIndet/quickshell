import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Widgets.common
import "./notifications"
import "./infoTools"

SidebarFlickable {
    id: root
    contentWidth: width
    contentHeight: infoContent.height + contentTopInset

    property bool foreground: false
    readonly property bool isForeground: root.foreground

    onIsForegroundChanged: {
        if (isForeground) {
            NotificationManager.hideAllPopups();
            NotificationManager.markAllRead();
            Time.refreshNow();
        }
    }

    ColumnLayout {
        id: infoContent
        y: root.contentTopInset
        width: root.width
        height: root.height + root.sectionExpansion
        spacing: 12 + root.sectionExpansion

        NotificationList {

            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        InfoToolDrawer {

            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            active: root.isForeground
        }
    }
}
