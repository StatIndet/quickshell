import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services as Services
import qs.Widgets.common

Item {
    id: root

    property var screen: null
    property bool vertical: false

    function componentFor(componentId) {
        switch (componentId) {
        case "network":
            return networkComponent;
        case "bluetooth":
            return bluetoothComponent;
        case "brightness":
            return brightnessComponent;
        case "volume":
            return volumeComponent;
        case "microphone":
            return microphoneComponent;
        case "battery":
            return batteryComponent;
        case "settings":
            return settingsComponent;
        case "power":
            return powerComponent;
        default:
            return null;
        }
    }

    implicitHeight: vertical ? layout.implicitHeight + 16 : Sizes.barPillThickness
    implicitWidth: vertical ? Sizes.barVisualThickness : layout.implicitWidth + 2 * Sizes.barPillHorizontalPadding

    TopBarPillBackground {
        anchors.fill: parent
        fillColor: Services.BlurService.backgroundColor(Appearance.colors.colLayer0)
    }

    GridLayout {
        id: layout

        anchors.centerIn: parent
        rowSpacing: 8
        columnSpacing: 8
        columns: root.vertical ? 1 : 8

        Repeater {
            model: Services.PersonalizationConfig.quickSettingsComponents

            Loader {
                id: componentLoader

                required property string modelData

                sourceComponent: root.componentFor(componentLoader.modelData)
            }

        }

    }

    Component {
        id: networkComponent

        Network {
            screen: root.screen
            vertical: root.vertical
        }

    }

    Component {
        id: bluetoothComponent

        BluetoothButton {
            screen: root.screen
        }

    }

    Component {
        id: brightnessComponent

        Brightness {
            screen: root.screen
        }

    }

    Component {
        id: volumeComponent

        Volume {
            screen: root.screen
        }

    }

    Component {
        id: microphoneComponent

        Microphone {
            screen: root.screen
        }

    }

    Component {
        id: batteryComponent

        Battery {
            vertical: root.vertical
        }

    }

    Component {
        id: settingsComponent

        SettingsButton {
            screen: root.screen
        }

    }

    Component {
        id: powerComponent

        PowerButton {
        }

    }

}
