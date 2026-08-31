import QtQuick
import Quickshell
import qs.Services
import qs.Widgets.common

StyledListView {
    id: root

    property bool popup: false
    property int dragIndex: -1
    property real dragDistance: 0

    function resetDrag() {
        root.dragIndex = -1;
        root.dragDistance = 0;
    }

    spacing: 3
    animateMovement: false

    remove: Transition {
    }

    removeDisplaced: Transition {
        ElementMoveAnimation {
            property: "y"
        }

    }

    model: ScriptModel {
        values: root.popup ? NotificationGroups.popupGroups : NotificationGroups.groups
        objectProp: "key"
    }

    delegate: NotificationGroup {
        required property int index
        required property var modelData

        delegateIndex: index
        dragHost: root
        popup: root.popup
        width: ListView.view.width
        notificationGroup: modelData
    }

}
