import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import "./notifications"

Item {
    id: root

    property string screenName: ""

    readonly property bool isForeground: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "info"
    onIsForegroundChanged: {
        if (isForeground) {
            NotificationManager.timeoutAll();
            NotificationManager.markAllRead();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        ProfileHeaderCard {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            screenName: root.screenName
        }

        NotificationList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
