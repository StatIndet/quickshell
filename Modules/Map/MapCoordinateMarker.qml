import QtQuick
import qs.Common

Item {
    id: root

    property bool draggable: false
    readonly property bool hovered: pointerArea.containsMouse
    readonly property bool dragging: pointerArea.dragging

    signal dragPositionChanged(real localX, real localY)
    signal nudgeRequested(real horizontalPixels, real verticalPixels)

    implicitWidth: 48
    implicitHeight: 48
    activeFocusOnTab: root.draggable
    Accessible.ignored: !root.draggable
    Accessible.name: qsTr("已选坐标")
    Accessible.description: root.draggable ? qsTr("拖动或使用方向键调整坐标") : ""
    Accessible.role: Accessible.Button
    Keys.onPressed: (event) => {
        if (!root.draggable)
            return ;

        const step = (event.modifiers & Qt.ShiftModifier) !== 0 ? 20 : 4;
        if (event.key === Qt.Key_Left)
            root.nudgeRequested(-step, 0);
        else if (event.key === Qt.Key_Right)
            root.nudgeRequested(step, 0);
        else if (event.key === Qt.Key_Up)
            root.nudgeRequested(0, -step);
        else if (event.key === Qt.Key_Down)
            root.nudgeRequested(0, step);
        else
            return ;
        event.accepted = true;
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.dragging ? 44 : root.hovered || root.activeFocus ? 40 : 36
        height: width
        radius: Appearance.rounding.full
        color: Appearance.applyAlpha(Appearance.colors.colPrimary, root.dragging ? 0.28 : root.hovered || root.activeFocus ? 0.2 : 0.12)

        Behavior on width {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }

        }

    }

    Rectangle {
        anchors.centerIn: parent
        width: 24
        height: 24
        radius: Appearance.rounding.full
        color: Appearance.colors.colSurface
        border.width: Metrics.dividerWidth
        border.color: Appearance.colors.colOutline

        Rectangle {
            anchors.centerIn: parent
            width: 16
            height: 16
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary
        }

    }

    MouseArea {
        id: pointerArea

        property bool dragging: false
        property real pressOffsetX: 0
        property real pressOffsetY: 0

        anchors.fill: parent
        enabled: root.draggable
        hoverEnabled: true
        preventStealing: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (mouse) => {
            root.forceActiveFocus();
            dragging = true;
            pressOffsetX = mouse.x - width / 2;
            pressOffsetY = mouse.y - height / 2;
        }
        onPositionChanged: (mouse) => {
            if (pressed)
                root.dragPositionChanged(mouse.x - pressOffsetX, mouse.y - pressOffsetY);

        }
        onReleased: dragging = false
        onCanceled: dragging = false
    }

}
