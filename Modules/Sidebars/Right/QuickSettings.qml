import QtQuick
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    property bool foreground: false
    property string displayedView: ""
    readonly property string activeView: {
        switch (WidgetState.qsView) {
        case "network":
        case "bluetooth":
        case "idle":
        case "audio":
        case "microphone":
        case "settings":
            return WidgetState.qsView;
        default:
            return "settings";
        }
    }
    readonly property var activeViewLoader: activeView === "network"
        ? networkLoader
        : activeView === "bluetooth"
            ? bluetoothLoader
            : activeView === "idle"
                ? idleLoader
                : activeView === "audio"
                    ? audioLoader
                    : activeView === "microphone"
                        ? microphoneLoader : settingsLoader
    readonly property bool readyForPresentation:
        activeViewLoader.active
            && activeViewLoader.status === Loader.Ready
            && activeViewLoader.item !== null
            && displayedView === activeView

    function syncDisplayedView() {
        if (activeViewLoader.active
                && activeViewLoader.status === Loader.Ready
                && activeViewLoader.item !== null) {
            displayedView = activeView;
        }
    }

    Component.onCompleted: syncDisplayedView()
    onActiveViewChanged: syncDisplayedView()

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "network"
        transitionsEnabled: root.foreground

        Loader {
            id: networkLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "network" || loadedOnce
            asynchronous: true
            sourceComponent: networkComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "bluetooth"
        transitionsEnabled: root.foreground

        Loader {
            id: bluetoothLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "bluetooth" || loadedOnce
            asynchronous: true
            sourceComponent: bluetoothComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "idle"
        transitionsEnabled: root.foreground

        Loader {
            id: idleLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "idle" || loadedOnce
            asynchronous: true
            sourceComponent: idleComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "audio"
        transitionsEnabled: root.foreground

        Loader {
            id: audioLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "audio" || loadedOnce
            asynchronous: true
            sourceComponent: audioComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "microphone"
        transitionsEnabled: root.foreground

        Loader {
            id: microphoneLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "microphone" || loadedOnce
            asynchronous: true
            sourceComponent: microphoneComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    PageTransitionLayer {
        anchors.fill: parent
        active: root.displayedView === "settings"
        hubPage: true
        transitionsEnabled: root.foreground

        Loader {
            id: settingsLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.activeView === "settings" || loadedOnce
            asynchronous: true
            sourceComponent: settingsComponent
            onLoaded: {
                loadedOnce = true;
                root.syncDisplayedView();
            }
        }
    }

    Component {
        id: networkComponent

        NetworkContent {
            foreground: root.foreground && root.activeView === "network"
        }
    }

    Component {
        id: bluetoothComponent

        BluetoothContent {
            foreground: root.foreground && root.activeView === "bluetooth"
        }
    }

    Component {
        id: idleComponent

        IdleContent {
            foreground: root.foreground && root.activeView === "idle"
        }
    }

    Component {
        id: audioComponent

        AudioContent {
            foreground: root.foreground && root.activeView === "audio"
        }
    }

    Component {
        id: microphoneComponent

        MicrophoneContent {
            foreground: root.foreground && root.activeView === "microphone"
        }
    }

    Component {
        id: settingsComponent

        SettingsContent {
            screen: root.screen
        }
    }
}
