import QtQuick
import qs.Common
import qs.Components

Item {
    id: root

    required property var fields
    property bool dragActive: false
    property string componentId: ""
    property string componentLabel: ""
    property string componentIcon: "widgets"
    property string sourceZone: ""
    property string targetZone: ""
    property int targetIndex: -1
    property real dragWidth: 0
    property real pointerX: 0
    property real pointerY: 0
    property var activeTargetField: null

    signal dropped(string componentId, string targetZone, int targetIndex)

    function beginDrag(sourceField, id, label, icon, width, point) {
        root.dragActive = true;
        root.componentId = id;
        root.componentLabel = label;
        root.componentIcon = icon;
        root.sourceZone = sourceField.zone;
        root.dragWidth = width;
        sourceField.closeMenu();
        root.updateDrag(point);
    }

    function fieldAt(sceneX, sceneY) {
        for (let index = 0; index < root.fields.length; index += 1) {
            const field = root.fields[index];
            if (field && field.containsScenePoint(root, sceneX, sceneY))
                return field;

        }
        return null;
    }

    function forEachField(callback) {
        for (let index = 0; index < root.fields.length; index += 1) {
            const field = root.fields[index];
            if (field)
                callback(field);

        }
    }

    function updateFieldPreviews(targetZone, targetIndex) {
        root.forEachField((field) => {
            field.showDropPreview(root.componentId, root.sourceZone, targetZone, targetIndex);
        });
    }

    function updateDrag(point) {
        if (!root.dragActive)
            return ;

        const mapped = root.mapFromItem(null, point.x, point.y);
        root.pointerX = mapped.x;
        root.pointerY = mapped.y;
        root.updateTarget();
    }

    function updateTarget() {
        const targetField = root.fieldAt(root.pointerX, root.pointerY);
        root.activeTargetField = targetField;
        root.forEachField((field) => {
            field.autoScrollVelocity = 0;
        });
        if (!targetField) {
            const previewChanged = root.targetZone !== "" || root.targetIndex !== -1;
            root.targetZone = "";
            root.targetIndex = -1;
            if (previewChanged)
                root.updateFieldPreviews("", -1);

            return ;
        }
        const nextZone = targetField.zone;
        const nextIndex = targetField.insertionIndexAt(root, root.pointerX, root.pointerY);
        const previewChanged = nextZone !== root.targetZone || nextIndex !== root.targetIndex;
        root.targetZone = nextZone;
        root.targetIndex = nextIndex;
        if (previewChanged)
            root.updateFieldPreviews(root.targetZone, root.targetIndex);

        targetField.updateAutoScroll(root, root.pointerX);
    }

    function finishDrag() {
        if (!root.dragActive)
            return ;

        const id = root.componentId;
        const zone = root.targetZone;
        const index = root.targetIndex;
        if (zone !== "" && index >= 0)
            root.dropped(id, zone, index);

        root.dragActive = false;
        root.forEachField((field) => {
            field.clearDropPreview();
        });
        root.activeTargetField = null;
        root.componentId = "";
        root.componentIcon = "widgets";
        root.sourceZone = "";
        root.targetZone = "";
        root.targetIndex = -1;
    }

    FrameAnimation {
        running: root.dragActive && root.activeTargetField !== null && root.activeTargetField.autoScrollVelocity !== 0
        onTriggered: {
            if (root.activeTargetField) {
                root.activeTargetField.stepAutoScroll();
                root.updateTarget();
            }
        }
    }

    Rectangle {
        visible: root.dragActive
        x: root.pointerX - width / 2
        y: root.pointerY - height / 2
        width: root.dragWidth
        height: 30
        z: 1000
        radius: Appearance.rounding.small
        color: Appearance.colors.colPrimaryContainerHover
        scale: 1.04

        MaterialSymbol {
            id: dragIcon

            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: root.componentIcon
            iconSize: 17
            fill: 1
            color: Appearance.colors.colOnPrimaryContainer
        }

        Text {
            text: root.componentLabel
            color: Appearance.colors.colOnPrimaryContainer
            font.family: Fonts.ui
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight

            anchors {
                left: dragIcon.right
                right: parent.right
                leftMargin: 6
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }

        }

    }

}
