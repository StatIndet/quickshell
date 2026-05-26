import QtQuick
import Quickshell
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

    readonly property bool internalVisibleCondition: (extraVisibleCondition && (parent === null || parent.hovered === undefined || parent.hovered)) || alternativeVisibleCondition

    function updateAnchor() {
        if (tooltipLoader.item)
            tooltipLoader.item.anchor.updateAnchor();
    }

    onInternalVisibleConditionChanged: {
        if (!internalVisibleCondition)
            contentItem.shown = false;
    }

    property Item contentItem: StyledToolTipContent {
        anchors.centerIn: parent
        text: root.text
        shown: false
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }

    Loader {
        id: tooltipLoader

        anchors.fill: parent
        active: root.internalVisibleCondition

        sourceComponent: PopupWindow {
            visible: true
            color: "transparent"
            implicitWidth: root.contentItem.implicitWidth + root.horizontalMargin * 2
            implicitHeight: root.contentItem.implicitHeight + root.verticalMargin * 2

            Component.onCompleted: root.contentItem.shown = true

            anchor {
                window: root.QsWindow.window
                item: root.parent
                edges: root.anchorEdges
                gravity: root.anchorGravity
            }

            mask: Region {
                item: null
            }

            data: [root.contentItem]
        }
    }
}
