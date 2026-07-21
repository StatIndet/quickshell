import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets.common

ToolTip {
    id: root

    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false

    function hierarchyAvailable(item) {
        let current = item;
        while (current !== null && current !== undefined) {
            if (current.enabled !== undefined && !current.enabled)
                return false;
            if (current.visible !== undefined && !current.visible)
                return false;
            if (current.opacity !== undefined && current.opacity <= 0.001)
                return false;
            current = current.parent;
        }
        return true;
    }

    readonly property bool parentHierarchyAvailable: root.hierarchyAvailable(root.parent)
    readonly property bool internalVisibleCondition: parentHierarchyAvailable
        && ((extraVisibleCondition && (parent === null || parent.hovered === undefined || parent.hovered))
            || alternativeVisibleCondition)

    verticalPadding: 5
    horizontalPadding: 10
    background: null
    delay: 0
    visible: internalVisibleCondition

    font {
        family: Sizes.fontFamily
        pixelSize: 12
        hintingPreference: Font.PreferNoHinting
    }

    contentItem: StyledToolTipContent {
        text: root.text
        shown: root.internalVisibleCondition
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
        font: root.font
    }
}
