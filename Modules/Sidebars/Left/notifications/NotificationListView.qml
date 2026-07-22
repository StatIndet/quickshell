import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Services
import qs.Widgets.common

StyledListView {
    id: root

    property bool popup: false
    property int dragIndex: -1
    property real dragDistance: 0

    spacing: 3
    animateMovement: false

    model: ScriptModel {
        values: root.popup ? NotificationManager.popupAppNameList : NotificationManager.appNameList
    }

    function resetDrag() {
        root.dragIndex = -1;
        root.dragDistance = 0;
    }

    delegate: NotificationGroup {
        required property int index
        required property var modelData

        delegateIndex: index
        dragHost: root
        popup: root.popup
        width: ListView.view.width
        notificationGroup: root.popup
            ? NotificationManager.popupGroupsByAppName[modelData]
            : NotificationManager.groupsByAppName[modelData]
    }
}
