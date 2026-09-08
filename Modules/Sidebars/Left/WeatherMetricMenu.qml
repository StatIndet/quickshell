import QtQuick
import QtQml.Models
import qs.Common
import qs.Widgets.common

StyledMenu {
    id: root

    required property Item anchorItem
    property var options: []
    property int selectedValue: -1
    property bool openAbove: false
    signal valueSelected(int value)

    parent: root.anchorItem
    x: root.anchorItem.width - width
    y: root.openAbove ? -height - Metrics.spacingXS : root.anchorItem.height + Metrics.spacingXS
    transformOrigin: root.openAbove ? Item.BottomRight : Item.TopRight

    Instantiator {
        model: root.options
        delegate: StyledMenuItem {
            required property var modelData
            text: modelData.label
            iconName: modelData.icon
            checkable: true
            checked: root.selectedValue === Number(modelData.value)
            onTriggered: root.valueSelected(Number(modelData.value))
        }
        onObjectAdded: (index, object) => root.insertItem(index, object)
        onObjectRemoved: (index, object) => root.removeItem(object)
    }
}
