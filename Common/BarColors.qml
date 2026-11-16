pragma Singleton
import QtQuick

QtObject {
    // Bar content sits directly on wallpaper; adapt foreground contrast to the active theme mode.
    readonly property bool isLight: Appearance.effectiveMatugenMode === "light"
    readonly property color foreground: isLight ? "#1a1b20" : "#f2f2f2"
    readonly property color selected: isLight ? "#000000" : "#ffffff"
    readonly property color inactiveWorkspace: isLight ? "#555861" : "#d0d0d0"
    readonly property color emptyWorkspace: isLight ? "#991a1b20" : "#b8ffffff"
    readonly property color track: isLight ? "#33000000" : "#66ffffff"
    readonly property color indicatorTrack: isLight ? "#666973" : "#b0b0b0"
    readonly property color onIndicator: isLight ? "#f8f9fa" : "#242424"
    readonly property color error: isLight ? "#ba1a1a" : "#ffb4ab"
}
