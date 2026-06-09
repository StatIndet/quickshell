pragma Singleton

import QtQuick

QtObject {
    id: root

    property bool qsOpen: false
    property string qsView: "network"
    property string qsScreenName: ""

    property bool leftSidebarOpen: false
    property string leftSidebarView: "info"

    property bool windowMenuOpen: false
    property real windowMenuX: 0
    property real windowMenuY: 0

    onQsOpenChanged: {
        if (!qsOpen)
            qsScreenName = "";
    }

    function closeAllPopups() {
        qsOpen = false;
        leftSidebarOpen = false;
        windowMenuOpen = false;
    }
}
