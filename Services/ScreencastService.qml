pragma Singleton

import QtQuick
import Quickshell
import Clavis.Niri 1.0

Singleton {
    id: root

    readonly property var casts: Niri.casts
    readonly property bool anyCastPresent: Niri.anyCastPresent
    readonly property bool anyCastActive: Niri.anyCastActive
    readonly property int activeCastCount: Niri.activeCastCount
    readonly property string statusText: anyCastActive ? "屏幕正在被捕获" : ""
}
