pragma Singleton
import QtQuick

QtObject {
    // Bar content sits directly on wallpaper, independent of the generated theme.
    readonly property color foreground: "#f2f2f2"
    readonly property color selected: "#ffffff"
    readonly property color inactiveWorkspace: "#d0d0d0"
    readonly property color emptyWorkspace: "#b8ffffff"
    readonly property color track: "#66ffffff"
    readonly property color indicatorTrack: "#b0b0b0"
    readonly property color onIndicator: "#242424"
    readonly property color error: "#ffb4ab"
}
