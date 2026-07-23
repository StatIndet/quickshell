pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services

Item {
    id: root

    property bool shortcutsEnabled: false

    readonly property var tabs: [
        { "name": "Pomodoro", "icon": "search_activity" },
        { "name": "Stopwatch", "icon": "timer" }
    ]

    focus: true

    function toggleCurrentTimer() {
        if (tabBar.currentIndex === 0)
            TimerService.togglePomodoro();
        else
            TimerService.toggleStopwatch();
    }

    function resetCurrentTimer() {
        if (tabBar.currentIndex === 0)
            TimerService.resetPomodoro();
        else
            TimerService.stopwatchReset();
    }

    Shortcut {
        enabled: root.shortcutsEnabled
        sequence: "Space"
        context: Qt.WindowShortcut
        autoRepeat: false
        onActivated: root.toggleCurrentTimer()
    }

    Shortcut {
        enabled: root.shortcutsEnabled
        sequence: "S"
        context: Qt.WindowShortcut
        autoRepeat: false
        onActivated: root.toggleCurrentTimer()
    }

    Shortcut {
        enabled: root.shortcutsEnabled
        sequence: "R"
        context: Qt.WindowShortcut
        autoRepeat: false
        onActivated: root.resetCurrentTimer()
    }

    Shortcut {
        enabled: root.shortcutsEnabled
        sequence: "L"
        context: Qt.WindowShortcut
        autoRepeat: false
        onActivated: TimerService.stopwatchRecordLap()
    }

    Shortcut {
        enabled: root.shortcutsEnabled
        sequence: "PgDown"
        context: Qt.WindowShortcut
        autoRepeat: false
        onActivated: tabBar.incrementCurrentIndex()
    }

    Shortcut {
        enabled: root.shortcutsEnabled
        sequence: "PgUp"
        context: Qt.WindowShortcut
        autoRepeat: false
        onActivated: tabBar.decrementCurrentIndex()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ToolSecondaryTabBar {
            id: tabBar

            Layout.fillWidth: true

            onCurrentIndexChanged: {
                if (swipeView.currentIndex !== currentIndex)
                    swipeView.setCurrentIndex(currentIndex);
            }

            Repeater {
                model: root.tabs

                delegate: ToolSecondaryTabButton {
                    required property var modelData

                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        SwipeView {
            id: swipeView

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 10
            spacing: 10
            clip: true

            onCurrentIndexChanged: {
                if (tabBar.currentIndex !== currentIndex)
                    tabBar.setCurrentIndex(currentIndex);
            }

            PomodoroTimer {}
            Stopwatch {}
        }
    }
}
