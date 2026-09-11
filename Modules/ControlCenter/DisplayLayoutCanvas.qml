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
        if (JSON.stringify(next) !== JSON.stringify(outputKeys))
            outputKeys = next;
    }
    Component.onCompleted: outputKeys = rows.map(row => row.key)
    property bool dragging: false
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
    implicitHeight: 260
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
        DisplayConfigService.edit(row.key, "position", {
                                      x: Math.round(sx),
                                      y: Math.round(sy)
                                  });
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
            x: root.offsetX + (row.settings.position?.x || 0) * root.canvasScale
            y: root.offsetY + (row.settings.position?.y || 0) * root.canvasScale
            width: logical.width * root.canvasScale
            height: logical.height * root.canvasScale
            radius: Appearance.rounding.small
            color: DisplayConfigService.selection === row.key ? Appearance.colors.colPrimaryContainer :
                                                                Appearance.colors.colSecondaryContainer
            border.width: activeFocus ? 3 : 1
            border.color: Appearance.colors.colPrimary
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
                text: monitor.row.name
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.family: Fonts.ui
                color: DisplayConfigService.selection === monitor.row.key
                       ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
            }
            MouseArea {
                anchors.fill: parent
                property point startPointer
                property point startPosition
                onPressed: mouse => {
                    DisplayConfigService.selection = monitor.row.key;
                    monitor.forceActiveFocus();
                    root.heldBounds = root.bounds;
                    root.dragging = true;
                    startPointer = mapToItem(root, mouse.x, mouse.y);
                    const p = monitor.row.settings.position;
                    startPosition = Qt.point(p.x, p.y);
                }
                onPositionChanged: mouse => {
                    if (!pressed || !monitor.row.editable || DisplayConfigService.busy)
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
