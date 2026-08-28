import QtQuick
import Quickshell

Scope {
    Variants {
        model: Quickshell.screens

        delegate: Loader {
            id: powerMenuLoader

            required property var modelData

            active: true

            sourceComponent: PowerMenuWindow {
                targetScreen: powerMenuLoader.modelData
            }

        }

    }

}
