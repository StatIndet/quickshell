import QtQuick
import qs.Common
import qs.Services
import "../../Common/functions/DisplayConfiguration.js" as Config

Rectangle {
    id: root
    property var rows: DisplayConfigService.draft.filter(r => r.connected && r.settings.enabled !== false)
    property var outputKeys: []
    onRowsChanged: {
        const next = rows.map(row => row.key);
        if (dragging && next.indexOf(draggedKey) < 0)
            dragging = false;
        if (JSON.stringify(next) !== JSON.stringify(outputKeys))
            outputKeys = next;
    }
    Component.onCompleted: outputKeys = rows.map(row => row.key)
    property string draggedKey: ""
    property point dragPosition
    property var snapPreview: null
    property bool dragging: false
    onDraggingChanged: {
        if (!dragging) {
            draggedKey = "";
            snapPreview = null;
        }
    }
    property var heldBounds: null
    readonly property var bounds: {
        if (dragging && heldBounds)
            return heldBounds;
        let left = 0, top = 0, right = 1, bottom = 1;
        for (const row of rows) {
            const pos = row.settings.position || {
                x: 0,
                y: 0
            }, size = Config.size(row);
            left = Math.min(left, pos.x);
            top = Math.min(top, pos.y);
            right = Math.max(right, pos.x + size.width);
            bottom = Math.max(bottom, pos.y + size.height);
        }
        return {
            left: left,
            top: top,
            width: right - left,
            height: bottom - top
        };
    }
    readonly property real canvasScale: Math.max(0.0001, Math.min((width - Metrics.spacingXL * 2)
                                                                  / bounds.width, (height - Metrics.spacingXL
                                                                                   * 2) / bounds.height))
    readonly property real offsetX: (width - bounds.width * canvasScale) / 2 - bounds.left * canvasScale
    readonly property real offsetY: (height - bounds.height * canvasScale) / 2 - bounds.top * canvasScale
    implicitHeight: Math.max(200, Math.min(300, width * 0.48))
    radius: Appearance.rounding.normal
    color: Appearance.colors.colSurfaceContainer
    clip: true
    function move(row, x, y) {
        const size = Config.size(row), distance = 12 / canvasScale;
        let sx = x, sy = y, bestX = distance, bestY = distance;
        for (const other of rows) {
            if (other.key === row.key)
                continue;
            const p = other.settings.position, s = Config.size(other);
            for (const edge of [p.x, p.x + s.width, p.x - size.width, p.x + s.width - size.width]) {
                if (Math.abs(x - edge) < bestX) {
                    sx = edge;
                    bestX = Math.abs(x - edge);
                }
            }
            for (const edge of [p.y, p.y + s.height, p.y - size.height, p.y + s.height - size.height]) {
                if (Math.abs(y - edge) < bestY) {
                    sy = edge;
                    bestY = Math.abs(y - edge);
                }
            }
        }
        dragPosition = Qt.point(x, y);
        snapPreview = bestX < distance || bestY < distance ? {
                                                                 x: Math.round(sx),
                                                                 y: Math.round(sy),
                                                                 width: size.width,
                                                                 height: size.height
                                                             } : null;
        DisplayConfigService.edit(row.key, "position", {
                                      x: Math.round(sx),
                                      y: Math.round(sy)
                                  });
    }
    // The outline marks the snapped draft position while the dragged object follows the pointer.
    Rectangle {
        visible: root.dragging && root.snapPreview !== null
        x: root.offsetX + (root.snapPreview ? root.snapPreview.x : 0) * root.canvasScale
        y: root.offsetY + (root.snapPreview ? root.snapPreview.y : 0) * root.canvasScale
        width: root.snapPreview ? root.snapPreview.width * root.canvasScale : 0
        height: root.snapPreview ? root.snapPreview.height * root.canvasScale : 0
        radius: Appearance.rounding.small
        color: "transparent"
        border.width: 2
        border.color: Appearance.colors.colPrimary
        opacity: 0.6
    }
    Repeater {
        model: root.outputKeys
        delegate: Rectangle {
            id: monitor
            required property string modelData
            readonly property var row: root.rows.find(r => r.key === modelData) || ({
                                                                                        key: modelData,
                                                                                        name: "",
                                                                                        settings: {
                                                                                            position: {
                                                                                                x: 0,
                                                                                                y: 0
                                                                                            }
                                                                                        },
                                                                                        editable: false,
                                                                                        live: null
                                                                                    })
            readonly property var logical: Config.size(row)
            readonly property bool beingDragged: root.dragging && root.draggedKey === row.key
            z: beingDragged ? 2 : 1
            x: root.offsetX + (beingDragged ? root.dragPosition.x : (row.settings.position?.x || 0))
               * root.canvasScale

            y: root.offsetY + (beingDragged ? root.dragPosition.y : (row.settings.position?.y || 0))
               * root.canvasScale

            width: logical.width * root.canvasScale
            height: logical.height * root.canvasScale
            radius: Appearance.rounding.small
            color: DisplayConfigService.selection === row.key ? Appearance.colors.colPrimaryContainer :
                                                                Appearance.colors.colSurfaceContainerHigh
            border.width: activeFocus ? 3 : DisplayConfigService.selection === row.key ? 2 : 1
            border.color: DisplayConfigService.selection === row.key || activeFocus
                          ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
            activeFocusOnTab: true
            onActiveFocusChanged: {
                if (activeFocus)
                    DisplayConfigService.selection = row.key;
            }
            Accessible.role: Accessible.Button
            Accessible.name: row.label
            Keys.onPressed: event => {
                if (!row.editable || DisplayConfigService.busy)
                    return;
                const p = row.settings.position, step = event.modifiers & Qt.ShiftModifier ? 10 : 1;
                if (event.key === Qt.Key_Left)
                    DisplayConfigService.edit(row.key, "position", {
                                                  x: p.x - step,
                                                  y: p.y
                                              });
                else if (event.key === Qt.Key_Right)
                    DisplayConfigService.edit(row.key, "position", {
                                                  x: p.x + step,
                                                  y: p.y
                                              });
                else if (event.key === Qt.Key_Up)
                    DisplayConfigService.edit(row.key, "position", {
                                                  x: p.x,
                                                  y: p.y - step
                                              });
                else if (event.key === Qt.Key_Down)
                    DisplayConfigService.edit(row.key, "position", {
                                                  x: p.x,
                                                  y: p.y + step
                                              });
                else
                    return;
                event.accepted = true;
            }
            Text {
                anchors.fill: parent
                anchors.margins: Metrics.spacingXS
                text: monitor.row.name + "\n" + monitor.logical.width + " × " + monitor.logical.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.family: Fonts.ui
                font.pixelSize: Typography.labelLarge.pixelSize
                font.weight: Typography.labelLarge.weight
                color: DisplayConfigService.selection === monitor.row.key
                       ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                // Own the gesture before the surrounding Flickable reaches its drag threshold.
                preventStealing: true
                cursorShape: pressed && root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point startPointer
                property point startPosition
                onPressed: mouse => {
                    DisplayConfigService.selection = monitor.row.key;
                    monitor.forceActiveFocus();
                    if (!monitor.row.editable || DisplayConfigService.busy)
                        return;
                    root.heldBounds = root.bounds;
                    startPointer = mapToItem(root, mouse.x, mouse.y);
                    const p = monitor.row.settings.position;
                    startPosition = Qt.point(p.x, p.y);
                    root.dragPosition = startPosition;
                    root.draggedKey = monitor.row.key;
                    root.snapPreview = null;
                    root.dragging = true;
                }
                onPositionChanged: mouse => {
                    if (!pressed || !root.dragging || !monitor.row.editable || DisplayConfigService.busy)
                        return;
                    const pointer = mapToItem(root, mouse.x, mouse.y);
                    root.move(monitor.row, startPosition.x + (pointer.x - startPointer.x) / root.canvasScale,
                              startPosition.y + (pointer.y - startPointer.y) / root.canvasScale);
                }
                onReleased: root.dragging = false
                onCanceled: root.dragging = false
            }
        }
    }
}
