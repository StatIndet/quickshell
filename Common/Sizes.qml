pragma Singleton
import Quickshell

Singleton {
    readonly property real cornerRadius: 10
    readonly property real barPillThickness: 36
    readonly property real barPillHorizontalPadding: 8
    // Transparent groups: 28px controls with breathing room between targets.
    readonly property real barItemSpacing: 6
    readonly property real barLabelSpacing: 6
    readonly property real barIconSize: 20
    readonly property real barControlCircleSize: 28
    readonly property real barPopupGap: 8
    readonly property real barPopupScreenMargin: 10
    readonly property real sidebarScrollableListMaxHeight: 224
    readonly property real lockHeightMult: 0.7
    readonly property real lockRatio: 16 / 9
}
