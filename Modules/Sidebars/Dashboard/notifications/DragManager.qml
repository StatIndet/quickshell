import QtQuick

MouseArea {
    id: root

    property bool interactive: true
    property bool automaticallyReset: true
    readonly property real dragDiffX: _dragDiffX
    readonly property real dragDiffY: _dragDiffY
    property real startX: 0
    property real startY: 0
    property bool dragging: false
    property bool leftDragActive: false
    property real _dragDiffX: 0
    property real _dragDiffY: 0

    signal dragReleased(real diffX, real diffY)

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    function resetDrag() {
        _dragDiffX = 0;
        _dragDiffY = 0;
        dragging = false;
        leftDragActive = false;
    }

    onPressed: mouse => {
        if (!root.interactive) {
            mouse.accepted = false;
            return;
        }
        if (mouse.button !== Qt.LeftButton) {
            root.leftDragActive = false;
            return;
        }
        if (mouse.button === Qt.LeftButton) {
            startX = mouse.x;
            startY = mouse.y;
            root.leftDragActive = true;
        }
    }

    onReleased: mouse => {
        if (!root.interactive)
            return;
        if (mouse.button !== Qt.LeftButton || !root.leftDragActive)
            return;
        dragging = false;
        leftDragActive = false;
        root.dragReleased(_dragDiffX, _dragDiffY);
        if (root.automaticallyReset)
            root.resetDrag();
    }

    onPositionChanged: mouse => {
        if (!root.interactive)
            return;
        if (root.leftDragActive && (mouse.buttons & Qt.LeftButton)) {
            root._dragDiffX = mouse.x - startX;
            root._dragDiffY = mouse.y - startY;
            root.dragging = true;
        }
    }

    onCanceled: {
        if (!root.interactive)
            return;
        if (!root.leftDragActive)
            return;
        dragging = false;
        leftDragActive = false;
        root.dragReleased(_dragDiffX, _dragDiffY);
        if (root.automaticallyReset)
            root.resetDrag();
    }
}
