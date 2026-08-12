import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Clavis.Niri 1.0
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property Item anchorItem: null
    property var workspaceId: 0
    property bool requestedVisible: false
    property bool popupHovered: previewHover.hovered
    property bool shown: false
    property var windows: []
    property real previewX: outerPadding
    property real previewY: outerPadding

    readonly property int invalidLayoutPosition: 999999
    readonly property real bridgeHeight: Appearance.spacing.small
    readonly property real outerPadding: Appearance.spacing.small
    readonly property real panelPadding: Appearance.spacing.small
    readonly property real cellSize: 40
    readonly property real iconSize: 24
    readonly property int closeDelay: 160
    readonly property real maximumSurfaceWidth: Math.max(
        cellSize + panelPadding * 2,
        previewWindow.width - outerPadding * 2)
    readonly property real maximumSurfaceHeight: Math.max(
        cellSize + panelPadding * 2,
        previewWindow.height - outerPadding * 2)

    signal dismissed()

    function validPosition(value) {
        const position = Number(value);
        return Number.isFinite(position)
            && position >= 0
            && position < root.invalidLayoutPosition;
    }

    function layoutWindows(source) {
        const items = source || [];
        const columns = [];
        const rowsByColumn = {};

        for (let i = 0; i < items.length; i += 1) {
            const window = items[i];
            if (!root.validPosition(window.layoutColumn))
                continue;

            const column = Number(window.layoutColumn);
            if (columns.indexOf(column) === -1)
                columns.push(column);

            if (!rowsByColumn[column])
                rowsByColumn[column] = [];
            if (root.validPosition(window.layoutRow)
                    && rowsByColumn[column].indexOf(Number(window.layoutRow)) === -1)
                rowsByColumn[column].push(Number(window.layoutRow));
        }

        columns.sort((left, right) => left - right);
        for (let columnKey in rowsByColumn)
            rowsByColumn[columnKey].sort((left, right) => left - right);

        const occupied = {};
        const result = [];
        let fallbackColumn = columns.length;

        for (let i = 0; i < items.length; i += 1) {
            const window = items[i];
            let previewColumn;
            let previewRow;

            if (root.validPosition(window.layoutColumn)) {
                const column = Number(window.layoutColumn);
                previewColumn = columns.indexOf(column);
                const rows = rowsByColumn[column] || [];
                previewRow = root.validPosition(window.layoutRow)
                    ? Math.max(0, rows.indexOf(Number(window.layoutRow)))
                    : 0;
            } else {
                previewColumn = fallbackColumn;
                previewRow = 0;
                fallbackColumn += 1;
            }

            let slot = previewColumn + ":" + previewRow;
            while (occupied[slot]) {
                previewRow += 1;
                slot = previewColumn + ":" + previewRow;
            }
            occupied[slot] = true;

            result.push({
                "id": window.id,
                "title": window.title || "",
                "appId": window.appId || "",
                "appName": window.appName || window.appId || "",
                "iconPath": window.iconPath || "",
                "isFocused": window.isFocused === true,
                "isFloating": window.isFloating === true,
                "isUrgent": window.isUrgent === true,
                "previewColumn": previewColumn,
                "previewRow": previewRow
            });
        }

        return result;
    }

    function refreshWindows() {
        root.windows = root.layoutWindows(Niri.windowsForWorkspace(root.workspaceId));
        if (root.windows.length === 0)
            root.shown = false;
    }

    function updateAnchor() {
        const surfaceWidth = Math.max(1, previewSurface.implicitWidth);
        const surfaceHeight = Math.max(1, previewSurface.implicitHeight);
        const availableWidth = Math.max(surfaceWidth + root.outerPadding * 2,
            previewWindow.width, previewWindow.screen ? previewWindow.screen.width : 0);
        const availableHeight = Math.max(surfaceHeight + root.outerPadding * 2,
            previewWindow.height, previewWindow.screen ? previewWindow.screen.height : 0);

        if (!root.anchorItem) {
            root.previewX = root.outerPadding;
            root.previewY = root.outerPadding;
            return;
        }

        const globalPos = root.anchorItem.mapToGlobal(0, 0);
        const screenX = previewWindow.screen ? (previewWindow.screen.x || 0) : 0;
        const screenY = previewWindow.screen ? (previewWindow.screen.y || 0) : 0;
        const anchorX = globalPos.x - screenX;
        const anchorY = globalPos.y - screenY;
        const anchorWidth = root.anchorItem.width || 0;
        const anchorHeight = root.anchorItem.height || 0;

        root.previewX = Math.max(root.outerPadding, Math.min(
            Math.round(anchorX + anchorWidth / 2 - surfaceWidth / 2),
            availableWidth - surfaceWidth - root.outerPadding));

        const belowY = anchorY + anchorHeight + root.bridgeHeight;
        const aboveY = anchorY - surfaceHeight - root.bridgeHeight;
        const maxY = availableHeight - surfaceHeight - root.outerPadding;
        root.previewY = belowY <= maxY || aboveY < root.outerPadding
            ? Math.max(root.outerPadding, Math.min(Math.round(belowY), maxY))
            : Math.max(root.outerPadding, Math.min(Math.round(aboveY), maxY));
    }

    function open() {
        closeTimer.stop();
        root.refreshWindows();
        root.shown = root.windows.length > 0;
        if (root.shown)
            Qt.callLater(root.updateAnchor);
    }

    function scheduleClose() {
        if (!root.requestedVisible && !root.popupHovered)
            closeTimer.restart();
    }

    function closeImmediately() {
        closeTimer.stop();
        root.shown = false;
    }

    onRequestedVisibleChanged: {
        if (requestedVisible)
            open();
        else
            scheduleClose();
    }

    onPopupHoveredChanged: {
        if (popupHovered)
            closeTimer.stop();
        else
            scheduleClose();
    }

    onAnchorItemChanged: {
        if (shown)
            Qt.callLater(root.updateAnchor);
    }

    onShownChanged: {
        if (shown)
            Qt.callLater(root.updateAnchor);
    }

    onWorkspaceIdChanged: {
        refreshWindows();
        if (requestedVisible)
            open();
    }

    Component.onCompleted: refreshWindows()

    Connections {
        target: Niri

        function onWindowsChanged() {
            root.refreshWindows();
            if (root.requestedVisible && root.windows.length > 0)
                root.shown = true;
        }
    }

    Timer {
        id: closeTimer
        interval: root.closeDelay
        repeat: false
        onTriggered: {
            if (!root.requestedVisible && !root.popupHovered)
                root.shown = false;
        }
    }

    PanelWindow {
        id: previewWindow

        visible: root.shown && root.windows.length > 0 && root.anchorItem !== null
        screen: root.QsWindow.window ? root.QsWindow.window.screen : null
        color: "transparent"
        exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "clavis-workspace-preview"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        onWidthChanged: {
            if (root.shown)
                Qt.callLater(root.updateAnchor);
        }

        onHeightChanged: {
            if (root.shown)
                Qt.callLater(root.updateAnchor);
        }

        mask: Region { item: popupInputRegion }

        Item {
            id: popupInputRegion

            x: root.previewX
            y: root.previewY
            width: previewSurface.implicitWidth
            height: previewSurface.implicitHeight

            HoverHandler {
                id: previewHover
            }

            StyledRectangularShadow {
                target: previewSurface
                opacity: previewSurface.opacity
            }

            Rectangle {
                id: previewSurface

                anchors.fill: parent
                implicitWidth: Math.min(root.maximumSurfaceWidth,
                    Math.max(root.cellSize + root.panelPadding * 2,
                        previewGrid.implicitWidth + root.panelPadding * 2))
                implicitHeight: Math.min(root.maximumSurfaceHeight,
                    previewGrid.implicitHeight + root.panelPadding * 2)
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                onImplicitWidthChanged: {
                    if (root.shown)
                        Qt.callLater(root.updateAnchor);
                }

                onImplicitHeightChanged: {
                    if (root.shown)
                        Qt.callLater(root.updateAnchor);
                }

                Flickable {
                    id: previewFlick

                    anchors.fill: parent
                    anchors.margins: root.panelPadding
                    contentWidth: Math.max(width, previewGrid.implicitWidth)
                    contentHeight: Math.max(height, previewGrid.implicitHeight)
                    clip: true
                    interactive: contentWidth > width || contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    GridLayout {
                        id: previewGrid

                        x: Math.max(0, (previewFlick.width - implicitWidth) / 2)
                        y: Math.max(0, (previewFlick.height - implicitHeight) / 2)
                        columns: Math.max(1, root.windows.reduce(
                            (maximum, window) => Math.max(maximum, window.previewColumn + 1), 1))
                        columnSpacing: Appearance.spacing.xSmall
                        rowSpacing: Appearance.spacing.xSmall

                        Repeater {
                            model: root.windows

                            delegate: Item {
                                id: windowCell

                                required property var modelData

                                Layout.column: modelData.previewColumn
                                Layout.row: modelData.previewRow
                                Layout.preferredWidth: root.cellSize
                                Layout.preferredHeight: root.cellSize

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Appearance.rounding.small
                                    color: cellMouse.containsPress
                                        ? Appearance.colors.colLayer2Active
                                        : cellMouse.containsMouse
                                            ? Appearance.colors.colLayer2Hover
                                            : Appearance.colors.colPrimaryContainer
                                    opacity: cellMouse.containsPress
                                        || cellMouse.containsMouse
                                        || windowCell.modelData.isFocused ? 1 : 0
                                    border.width: windowCell.modelData.isUrgent ? 1 : 0
                                    border.color: Appearance.colors.colError

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }
                                }

                                Image {
                                    id: appIcon

                                    anchors.centerIn: parent
                                    width: root.iconSize
                                    height: root.iconSize
                                    source: windowCell.modelData.iconPath
                                    sourceSize.width: root.iconSize * 2
                                    sourceSize.height: root.iconSize * 2
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    visible: source !== "" && status !== Image.Error
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    text: (windowCell.modelData.appName || "?").charAt(0).toUpperCase()
                                    color: windowCell.modelData.isFocused
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnLayer0
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: Sizes.typeLabelLarge
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: cellMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Niri.focusWindow(windowCell.modelData.id);
                                        root.closeImmediately();
                                        root.dismissed();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
