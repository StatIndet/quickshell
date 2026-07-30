import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property string text: ""
    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property real horizontalMargin: horizontalPadding
    property real verticalMargin: verticalPadding
    property var anchorEdges: Edges.Bottom
    property var anchorGravity: anchorEdges
    property bool respectParentHierarchy: false
    property font font

    font {
        family: Sizes.fontFamily
        pixelSize: 12
        hintingPreference: Font.PreferNoHinting
    }

    function hierarchyAvailable(item) {
        let current = item;
        while (current !== null && current !== undefined) {
            if (current.enabled !== undefined && !current.enabled)
                return false;
            if (current.visible !== undefined && !current.visible)
                return false;
            if (current.opacity !== undefined
                    && current.opacity <= 0.001)
                return false;
            current = current.parent;
        }
        return true;
    }

    readonly property bool parentHierarchyAvailable:
        !root.respectParentHierarchy
        // Starting at the tooltip itself makes its effective `visible`
        // depend on this property again through Loader activation.
        || root.hierarchyAvailable(root.parent)
    readonly property var anchorWindow: root.QsWindow.window
    readonly property bool anchorWindowReady:
        root.anchorWindow !== null
        && root.anchorWindow !== undefined
        && root.anchorWindow.backingWindowVisible
    readonly property bool usingFallback: fallbackTooltip.visible
    readonly property bool internalVisibleCondition:
        root.parentHierarchyAvailable
        && ((extraVisibleCondition
                && (parent === null
                    || parent.hovered === undefined
                    || parent.hovered))
            || alternativeVisibleCondition)
    readonly property var popupWindow: tooltipLoader.item

    function updateAnchor() {
        if (tooltipLoader.item)
            tooltipLoader.item.anchor.updateAnchor();
    }

    Loader {
        id: tooltipLoader

        anchors.fill: parent
        active: root.internalVisibleCondition
            && root.anchorWindowReady

        sourceComponent: PopupWindow {
            id: tooltipWindow

            readonly property alias tooltipContentItem: tooltipContent

            visible: true
            color: "transparent"
            implicitWidth: tooltipContent.implicitWidth
                + root.horizontalMargin * 2
            implicitHeight: tooltipContent.implicitHeight
                + root.verticalMargin * 2

            Component.onCompleted: tooltipContent.shown = true

            anchor {
                window: root.anchorWindow
                item: root.parent
                edges: root.anchorEdges
                gravity: root.anchorGravity
            }

            mask: Region {
                item: null
            }

            StyledToolTipContent {
                id: tooltipContent

                x: root.horizontalMargin
                y: root.verticalMargin
                text: root.text
                shown: false
                horizontalPadding: root.horizontalPadding
                verticalPadding: root.verticalPadding
                font: root.font
            }

            CompositorBlurRegion {
                targetWindow: tooltipWindow
                backgroundItem: tooltipContent.blurBackgroundItem
                blurEnabled: tooltipContent.shown
            }
        }
    }

    ToolTip {
        id: fallbackTooltip

        visible: root.internalVisibleCondition
            && (root.anchorWindow === null
                || root.anchorWindow === undefined)
        delay: 0
        padding: 0
        background: null

        contentItem: StyledToolTipContent {
            text: root.text
            shown: fallbackTooltip.visible
            horizontalPadding: root.horizontalPadding
            verticalPadding: root.verticalPadding
            font: root.font
        }
    }
}
