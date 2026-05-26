import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets.common

ToolTip {
    id: root

    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false

    readonly property bool internalVisibleCondition: (extraVisibleCondition && (parent === null || parent.hovered === undefined || parent.hovered)) || alternativeVisibleCondition

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
