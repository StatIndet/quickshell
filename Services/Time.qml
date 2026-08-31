pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property double now: Date.now()
    readonly property string day: {
        Qt.formatDateTime(clock.date, "d");
    }
    readonly property string month: {
        Qt.formatDateTime(clock.date, "MMM");
    }
    readonly property string hours: {
        Qt.formatDateTime(clock.date, "hh");
    }
    readonly property string minutes: {
        Qt.formatDateTime(clock.date, "mm");
    }

    function refreshNow() {
        root.now = Date.now();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.refreshNow()
    }

}
