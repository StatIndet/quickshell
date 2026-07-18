pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property int type: Easing.BezierSpline

    readonly property int expandingDuration: 500
    readonly property int shrinkingDuration: 360
    readonly property int radiusDuration: 350
    readonly property int hoverDuration: 360

    readonly property var expandingBezier: [0.1, 0.68, 0.28, 1.02, 0.64, 1.035, 0.78, 1.035, 0.96, 1, 1, 1]
    readonly property var shrinkingBezier: [0.16, 0.68, 0.36, 1, 1, 1]
    readonly property var hoverBezier: [0.2, 0, 0, 1, 1, 1]
    readonly property var radiusBezier: shrinkingBezier

    readonly property int hoverWidthDelta: 20
    readonly property int hoverHeightDelta: 8
    readonly property int hoverRadiusDelta: 3
}
