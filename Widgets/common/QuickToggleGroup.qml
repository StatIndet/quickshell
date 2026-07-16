import QtQuick
import QtQuick.Layouts
import qs.Common

Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    property alias clickIndex: row.clickIndex
    property alias childrenCount: row.childrenCount
    property real padding: 0

    function firstButtonRadius() {
        const buttons = row.buttonItems();
        return buttons.length > 0 ? buttons[0].radius + root.padding : Appearance.rounding.small;
    }

    function lastButtonRadius() {
        const buttons = row.buttonItems();
        return buttons.length > 0 ? buttons[buttons.length - 1].radius + root.padding : Appearance.rounding.small;
    }

    color: "transparent"
    topLeftRadius: firstButtonRadius()
    bottomLeftRadius: topLeftRadius
    topRightRadius: lastButtonRadius()
    bottomRightRadius: topRightRadius
    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: row.implicitHeight + padding * 2
    width: implicitWidth

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 6

        property int clickIndex: -1
        property int childrenCount: 0

        function buttonItems() {
            let buttons = [];
            for (let i = 0; i < children.length; i += 1) {
                const child = children[i];
                if (child && child.materialQuickToggleButton && child.visible)
                    buttons.push(child);
            }
            return buttons;
        }

        function indexOfButton(button) {
            return buttonItems().indexOf(button);
        }

        function refreshChildrenCount() {
            childrenCount = buttonItems().length;
        }

        Component.onCompleted: refreshChildrenCount()
        onChildrenChanged: refreshChildrenCount()
    }
}
