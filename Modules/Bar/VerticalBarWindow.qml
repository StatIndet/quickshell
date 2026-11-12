import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services
import qs.Common
import qs.Widgets.common

PanelWindow {
    id: root

    required property string edge
    readonly property real visualThickness: PersonalizationConfig.barThickness + 8
    readonly property real outerEdgeMargin: PersonalizationConfig.barEdgeSpacing
    readonly property real lengthPadding: Math.min(PersonalizationConfig.barLengthPadding, Math.max(0, (height
                                                                                                        - content.minimumLength)
                                                                                                    / 2))
    readonly property real surfaceThickness: outerEdgeMargin + visualThickness
    readonly property real exclusiveThickness: Math.max(0, outerEdgeMargin + visualThickness
                                                        + PersonalizationConfig.barExclusiveZoneOffset)

    implicitWidth: surfaceThickness
    color: "transparent"
    exclusiveZone: PersonalizationConfig.barOverlay ? 0 : exclusiveThickness
    // Floating changes desktop reservation, not stacking above fullscreen windows.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-shell-bar-vertical"
    WlrLayershell.exclusionMode: PersonalizationConfig.barOverlay ? ExclusionMode.Ignore :
                                                                    ExclusionMode.Normal

    BarAxis {
        id: axis

        edge: root.edge
    }

    anchors {
        top: true
        bottom: true
        left: axis.isLeft
        right: axis.isRight
    }

    Item {
        id: visualBand

        x: axis.isLeft ? root.outerEdgeMargin : 0
        y: root.lengthPadding
        width: root.visualThickness
        height: Math.max(0, parent.height - 2 * root.lengthPadding)

        VerticalBarContent {
            id: content

            anchors.fill: parent
            screen: root.screen
            axis: axis
        }
    }

    mask: Region {
        Region {
            item: content.leadingInputRegionItem
        }

        Region {
            item: content.trailingInputRegionItem
        }

        HotCornerExclusionRegion {
            surfaceWidth: root.width
            surfaceHeight: root.height
            leftEdge: axis.isLeft
            rightEdge: axis.isRight
        }
    }
}
