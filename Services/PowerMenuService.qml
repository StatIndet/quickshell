pragma Singleton
import QtQuick
import qs.Common

QtObject {
    id: root

    property bool active: false
    property string targetScreenName: ""

    signal actionRequested(string action)

    function open(screen) {
        if (!screen || !screen.name)
            return false;

        WidgetState.closeAllPopups();
        root.targetScreenName = screen.name;
        root.active = true;
        return true;
    }

    function close() {
        if (!root.active)
            return false;

        root.active = false;
        return true;
    }

    function trigger(action) {
        if (!root.active)
            return false;

        root.active = false;
        root.actionRequested(String(action || ""));
        return true;
    }

}
