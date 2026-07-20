import QtQuick
import Quickshell

Scope {
    Variants {
        model: Quickshell.screens

        delegate: Loader {
            id: selectorLoader
            required property var modelData

            active: true
            sourceComponent: RegionSelectionWindow {
                targetScreen: selectorLoader.modelData
            }
        }
    }
}
