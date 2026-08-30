import QtQuick
pragma Singleton

QtObject {
    id: root

    property bool qsOpen: false
    property string qsView: "settings"
    property string qsScreenName: ""
    property bool leftSidebarOpen: false
    property string leftSidebarView: "info"

    signal transientSurfacesDismissRequested()

    function closeAllPopups() {
        qsOpen = false;
        leftSidebarOpen = false;
        transientSurfacesDismissRequested();
    }

    onQsOpenChanged: {
        if (!qsOpen)
            qsScreenName = "";

    }
}
