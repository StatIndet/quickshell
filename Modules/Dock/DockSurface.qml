pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Clavis.Files
import Clavis.Niri
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../Common/functions/DockLayout.js" as DockLayout
import "../../Common/functions/DockMotion.js" as DockMotion

PanelWindow {
    id: root

    required property string edge

    NiriAnimationTargets {
        id: animationTargets
        enabled: Niri.supportsMinimizeAnimation && !WindowPreviewService.suspended && root.visible
        onEnabledChanged: root.updateAnimationTargets()
    }
    // Geometry notifications arrive once per animated property, not once per
    // frame. Coalesce before walking the row and converting the IPC payload;
    // the native publisher's send throttle happens too late to save that work.
    readonly property var animationTargetGeometry: [band.x, band.y, band.width, band.height, hideTranslation.x,
        hideTranslation.y, scrollOffset, width, height, screen ? screen.name : "", edge]
    onAnimationTargetGeometryChanged: scheduleAnimationTargets()

    function scheduleAnimationTargets() {
        if (animationTargets.enabled)
            Qt.callLater(root.updateAnimationTargets);
    }
    function updateAnimationTargets() {
        const result = [];
        if (animationTargets.enabled && root.screen) {
            for (let i = 0; i < iconItems.count; ++i) {
                const item = iconItems.itemAt(i) as DockItem;
                if (!item || item.kind !== "app" || visualEntries.get(i).retiring || item.dragged)
                    continue;
                const artwork = item.artworkItem;
                const start = artwork.mapToItem(content, 0, 0);
                const end = artwork.mapToItem(content, artwork.width, artwork.height);
                if (![start.x, start.y, end.x, end.y].every(value => isFinite(value)) || end.x <= start.x
                        || end.y <= start.y)
                    continue;
                for (const window of DockService.windowsFor(item.entryKey)) {
                    result.push({
                                    id: window.id,
                                    output: root.screen.name,
                                    layer_namespace: "clavis-shell-dock",
                                    edge: root.edge,
                                    rect: [start.x, start.y, end.x - start.x, end.y - start.y]
                                });
                }
            }
        }
        animationTargets.targets = result;
    }
    readonly property bool horizontal: edge === "bottom"
    readonly property real axisLength: horizontal ? width : height
    readonly property real availableLength: Math.max(80, axisLength - 32)
    readonly property real edgeOffset: 8
    readonly property var kinds: {
        const revision = DockService.revision;
        const result = [];
        for (let i = 0; i < DockService.model.count; ++i)
            result.push(DockService.model.get(i).kind);
        return result;
    }
    readonly property real magnification: DockService.magnification ? DockService.magnificationScale : 1
    readonly property var baseLayout: DockLayout.layout(kinds, DockService.iconSize, availableLength,
                                                        magnification, 16, NaN, DockLayout.sectionBoundaries(
                                                            kinds, DockService.pinnedAppCount))
    readonly property real scrollOffset: horizontal ? icons.contentX - icons.originX : icons.contentY
                                                      - icons.originY
    readonly property real pointerInBase: pointerAxis - (axisLength - Math.min(baseLayout.baseLength,
                                                                               availableLength)) / 2
                                          + scrollOffset
    readonly property bool dragInside: dragKey !== "" && insideDropBand(dragPoint)
    readonly property int previewSource: dragKey ? DockService.rowIndex(dragKey) : externalOver &&
                                                   !externalFiles && !dropTargetKey ? DockService.rowIndex(
                                                                                          externalSourceKey) :
                                                                                      -1
    readonly property var preview: DockLayout.previewOrder(kinds, previewSource, (dragInside || externalOver
                                                                                  && !externalFiles) &&
                                                           !dropTargetKey ? insertion : -1, draggedEntry
                                                           ? draggedEntry.kind : externalKind)
    readonly property bool magnificationRequested: magnification > 1 && (dragInside || externalOver
                                                                         || handoffKey !== "" || (!dragKey
                                                                                                  && magnificationActive
                                                                                                  && !DockService.externalDragActive))
    // One continuous envelope for hover and drag, including an interrupted
    // entrance/exit. Never ease the moving centre or each derived icon slot.
    property real magnificationProgress: magnificationRequested ? 1 : 0
    Behavior on magnificationProgress {
        NumberAnimation {
            duration: DockMotion.reflowDuration
            easing.type: Easing.OutCubic
        }
    }
    readonly property bool directMagnification: magnificationRequested || magnificationProgress > 0
    readonly property var layout: DockLayout.layout(preview.kinds, baseLayout.size, availableLength,
                                                    magnification, 16, pointerInBase,
                                                    DockLayout.sectionBoundaries(preview.kinds,
                                                                                 DockService.pinnedAppCount,
                                                                                 preview.order),
                                                    magnificationProgress)
    readonly property var slotsByIndex: {
        const result = [];
        for (let i = 0; i < preview.order.length; ++i) {
            if (preview.order[i] >= 0)
                result[preview.order[i]] = layout.slots[i];
        }
        return result;
    }
    readonly property real bandLength: Math.min(availableLength, Math.max(96, layout.length))
    readonly property real bandThickness: baseLayout.size * magnification + 36
    readonly property real restingThickness: baseLayout.size + 22
    readonly property bool shown: !DockService.autoHide || revealed || DockService.externalDragActive
                                  || dragKey !== "" || popupKey !== "" || dragGhost.active || handoffKey
                                  !== ""

    readonly property bool interacting: root.pointerOverDock || edgeHover.hovered || popup.hovered
                                        || filePopup.hovered && filePopup.visible || dropArea.containsDrag
                                        || dragKey !== "" || DockService.externalDragActive
                                        || dragGhost.active || handoffKey !== ""
    property bool revealed: false
    property real pointerAxis: 0
    property bool magnificationActive: false
    // Track the pointer above the popup/delegate hierarchy. Disabling a closing
    // fan must not look like leaving the Dock when the pointer hasn't moved.
    readonly property bool pointerOverDock: shown && surfaceHover.hovered && surfaceHover.point.position.x
                                            >= dockInputArea.x && surfaceHover.point.position.x
                                            < dockInputArea.x + dockInputArea.width
                                            && surfaceHover.point.position.y >= dockInputArea.y
                                            && surfaceHover.point.position.y < dockInputArea.y
                                            + dockInputArea.height
    onPointerOverDockChanged: {
        if (pointerOverDock) {
            if (!trackingFileDrag)
                pointerAxis = horizontal ? surfaceHover.point.scenePosition.x :
                                           surfaceHover.point.scenePosition.y;
            magnificationExit.stop();
            magnificationActive = true;
        } else {
            magnificationExit.restart();
        }
    }
    property string hoverKey: ""
    property string pendingPopupKey: ""
    property string popupKey: ""
    property bool contextMenu: false
    property real popupAxis: axisLength / 2
    property real popupCross: 0
    property point popupSourceCenter: Qt.point(width / 2, height)
    property real popupIconSize: baseLayout.size
    readonly property var folderButtonItems: {
        if (!filePopupActive || contextMenu || filePopup.list)
            return [];
        for (let i = 0; i < iconItems.count; ++i) {
            const item = iconItems.itemAt(i);
            if (item && item.entryKey === popupKey)
                return [item.folderButtonBackground];
        }
        return [];
    }
    property string dragKey: ""
    property bool dragCancelled: false
    property point dragPoint: Qt.point(0, 0)
    property point dropPoint: Qt.point(0, 0)
    property int insertion: -1
    property bool externalOver: false
    property string externalKind: "app"
    property string externalSourceKey: ""
    property string dropTargetKey: ""
    property var externalEntries: []
    readonly property bool externalFiles: externalEntries.some(entry => entry.kind === "file" || entry.kind
                                                                        === "folder")
    readonly property bool trackingFileDrag: externalOver && externalFiles && DockService.magnification
    property bool fileDragPositionPending: false
    onTrackingFileDragChanged: {
        if (!trackingFileDrag)
            fileDragPositionPending = false;
    }
    // Native drag motion can arrive more often than frames. Keep only its
    // newest surface position and apply the whole wave in one frame, without
    // restarting independent size/slot animations for every motion event.
    FrameAnimation {
        running: root.trackingFileDrag && root.fileDragPositionPending
        onTriggered: {
            root.fileDragPositionPending = false;
            root.pointerAxis = root.horizontal ? root.dropPoint.x : root.dropPoint.y;
            root.updateDropTarget();
        }
    }
    readonly property bool filePopupActive: {
        const revision = DockService.revision;
        const entry = DockService.entryFor(popupKey);
        return !!entry && (entry.kind === "file" || entry.kind === "folder" || entry.kind === "trash");
    }
    property string handoffKey: ""
    property int handoffSerial: 0
    property point dragGrabOffset: Qt.point(0, 0)
    readonly property var draggedEntry: {
        return dragKey && dragGhost.entry ? dragGhost.entry : null;
    }
    readonly property bool removeOnRelease: !!draggedEntry && draggedEntry.pinned
                                            && DockLayout.removalDistance(edge, dragPoint.x, dragPoint.y,
                                                                          width, height, edgeOffset)
                                            > bandThickness + 48

    function targetAt(point) {
        if (!insideDropBand(point))
            return null;
        const axis = (horizontal ? point.x : point.y) - (axisLength - Math.min(baseLayout.baseLength,
                                                                               availableLength)) / 2
              + scrollOffset;
        for (let i = 0; i < baseLayout.slots.length; ++i) {
            const slot = baseLayout.slots[i];
            if (Math.abs(axis - slot.center) < slot.span * 0.3)
                return DockService.model.get(i);
        }
        return null;
    }
    // Files follow the pointer without making room for a provisional Dock
    // entry. Only artwork actually under the pointer is an open-with target.
    function fileTargetAt(point) {
        for (let i = 0; i < iconItems.count; ++i) {
            const item = iconItems.itemAt(i) as DockItem;
            if (!item || visualEntries.get(i).retiring || item.dragged || (item.kind !== "app" && item.kind
                                                                           !== "trash"))
                continue;
            const artwork = item.artworkItem;
            const local = artwork.mapFromItem(content, point.x, point.y);
            if (local.x >= 0 && local.x < artwork.width && local.y >= 0 && local.y < artwork.height)
                return DockService.entryFor(item.entryKey);
        }
        return null;
    }
    function updateDropTarget() {
        const candidate = root.externalFiles ? root.fileTargetAt(root.dropPoint) : null;
        root.dropTargetKey = candidate && !DesktopFiles.busy && (candidate.kind === "trash"
                                                                 && DesktopFiles.trashAvailable
                                                                 || candidate.kind === "app"
                                                                 && DesktopFiles.canOpenWith(
                                                                     candidate.desktopId)) ? candidate.key :
                                                                                             "";
        root.insertion = root.dropTargetKey ? -1 : root.insertionAt(root.dropPoint);
    }
    property var fileRegions: []
    function updateFileRegions() {
        for (const region of fileRegions)
            region.destroy();
        fileRegions = filePopup.inputItems.map(item => fileRegionComponent.createObject(fileInputRegion, {
                                                                                            sourceItem: item
                                                                                        }));
        fileInputRegion.regions = fileRegions;
    }
    Component {
        id: fileRegionComponent
        Region {
            required property Item sourceItem
            item: sourceItem
        }
    }
    Connections {
        target: filePopup
        function onInputItemsChanged() {
            Qt.callLater(root.updateFileRegions);
        }
    }
    Connections {
        target: DockService
        function onFileDragActiveChanged() {
            if (!DockService.fileDragActive)
                root.dismissPopup();
        }
        function onFileErrorChanged() {
            if (DockService.fileError)
                root.showPopup("trash", true);
        }
    }

    function updateInteraction() {
        if (interacting || filePopupActive) {
            revealed = true;
            hideTimer.stop();
            closeTimer.stop();
        } else {
            if (revealed || popupKey)
                hideTimer.restart();
            if (popupKey)
                closeTimer.restart();
            hoverTimer.stop();
        }
    }
    function hoverEntry(key) {
        if (WindowPreviewService.suspended || dragKey || dragGhost.active || handoffKey
                || DockService.externalDragActive || contextMenu || filePopupActive)
            return;
        hoverKey = key;
        closeTimer.stop();
        // Changing the layer-shell input region or animating the icon slots
        // can deliver leave/enter again without a different app being hovered.
        // Keep that preview and its capture session alive across re-entry.
        if (popupKey === key) {
            pendingPopupKey = "";
            hoverTimer.stop();
            return;
        }
        const entry = DockService.entryFor(key);
        if (entry && entry.kind !== "app") {
            root.dismissPopup();
            return;
        }
        if (pendingPopupKey === key && hoverTimer.running)
            return;
        pendingPopupKey = key;
        hoverTimer.restart();
    }
    function leaveEntry(key) {
        if (hoverKey !== key)
            return;
        hoverKey = "";
        pendingPopupKey = "";
        hoverTimer.stop();
    }
    function showPopup(key, context, folderClick) {
        if (WindowPreviewService.suspended)
            return;
        const entry = DockService.entryFor(key);
        if (!entry || (!context && entry.kind !== "app" && !(folderClick && entry.kind === "folder")))
            return;
        hoverTimer.stop();
        const slot = slotForKey(key);
        popupIconSize = slot ? slot.size : baseLayout.size;
        popupAxis = slot ? (axisLength - bandLength) / 2 + slot.start + slot.span / 2 - scrollOffset :
                           pointerAxis;
        // Anchor to visible artwork / tray, not the oversized interaction band.
        // Snapshot the edge so the popup stays put when the pointer moves into
        // it and the dock's hover magnification subsequently settles down.
        const trayStart = glass.mapToItem(content, 0, 0);
        const trayEnd = glass.mapToItem(content, glass.width, glass.height);
        popupCross = horizontal ? trayStart.y : edge === "left" ? trayEnd.x : trayStart.x;
        popupSourceCenter = horizontal ? Qt.point(popupAxis, (trayStart.y + trayEnd.y) / 2) : Qt.point((
                                                                                                           trayStart.x
                                                                                                           + trayEnd.x)
                                                                                                       / 2, popupAxis);
        for (let i = 0; i < iconItems.count; ++i) {
            const item = iconItems.itemAt(i);
            if (!item || item.entryKey !== key)
                continue;
            const artwork = item.artworkItem;
            popupIconSize = Math.max(popupIconSize, artwork.width);
            const start = artwork.mapToItem(content, 0, 0);
            const end = artwork.mapToItem(content, artwork.width, artwork.height);
            popupSourceCenter = Qt.point((start.x + end.x) / 2, (start.y + end.y) / 2);
            popupAxis = horizontal ? (start.x + end.x) / 2 : (start.y + end.y) / 2;
            popupCross = horizontal ? Math.min(popupCross, start.y) : edge === "left" ? Math.max(popupCross,
                                                                                                 end.x) : Math.min(
                                                                                            popupCross,
                                                                                            start.x);
            break;
        }
        popupKey = key;
        contextMenu = context;
        if (context || folderClick)
            content.forceActiveFocus();
    }
    function dismissPopup() {
        if (DockService.fileDragActive)
            return;
        if (filePopup.visible && filePopup.closePopup())
            return;
        finishDismissPopup();
    }
    function finishDismissPopup() {
        popupKey = "";
        contextMenu = false;
        pendingPopupKey = "";
        hoverTimer.stop();
        updateInteraction();
    }
    // Hit testing stays in the unchanged model's coordinate system. Animated
    // neighbours and the provisional gap must not move their own thresholds.
    function insertionAt(point) {
        const origin = (axisLength - Math.min(baseLayout.baseLength, availableLength)) / 2;
        const coordinate = (horizontal ? point.x : point.y) - origin + scrollOffset;
        const kind = draggedEntry ? draggedEntry.kind : externalKind;
        const files = kind === "file" || kind === "folder";
        const candidate = Math.max(files ? DockService.fileStartIndex : 0, Math.min(files
                                                                                    ? DockService.model.count
                                                                                      - 1 : DockService.pinnedAppCount,
                                                                                    DockLayout.insertionIndex(
                                                                                        baseLayout.slots,
                                                                                        coordinate)));
        if (insertion >= 0 && Math.abs(candidate - insertion) === 1) {
            const crossed = baseLayout.slots[Math.min(candidate, insertion)];
            if (crossed && Math.abs(coordinate - crossed.center) < 6)
                return insertion;
        }
        return candidate;
    }
    function insideDropBand(point) {
        const major = horizontal ? point.x : point.y;
        return major >= 0 && major <= axisLength && DockLayout.removalDistance(edge, point.x, point.y, width, height,
                                                                               edgeOffset) <= bandThickness
                + 24;
    }
    function slotForKey(key) {
        const revision = DockService.revision;
        return slotsByIndex[DockService.rowIndex(key)] || null;
    }
    function copyEntry(entry) {
        const value = {};
        for (const role of ["key", "kind", "name", "icon", "symbol", "pinned", "focused", "launching",
                            "available", "windowCount"])
            value[role] = entry[role];
        value.url = String(entry.url || "");
        return value;
    }
    function syncVisualEntries() {
        const wanted = new Set();
        for (let i = 0; i < DockService.model.count; ++i) {
            const entry = DockService.model.get(i);
            wanted.add(entry.key);
            let found = -1;
            for (let j = 0; j < visualEntries.count; ++j) {
                if (visualEntries.get(j).key === entry.key) {
                    found = j;
                    break;
                }
            }
            const row = copyEntry(entry);
            row.retiring = false;
            if (found < 0)
                visualEntries.append(row);
            else
                visualEntries.set(found, row);
        }
        for (let i = 0; i < visualEntries.count; ++i) {
            if (!wanted.has(visualEntries.get(i).key) && !visualEntries.get(i).retiring) {
                const item = iconItems.itemAt(i);
                if (item)
                    item.freezeRetirement();
                visualEntries.setProperty(i, "retiring", true);
            }
        }
    }
    function removeRetired() {
        for (let i = visualEntries.count - 1; i >= 0; --i) {
            const item = iconItems.itemAt(i);
            if (visualEntries.get(i).retiring && item && item.presence === 0)
                visualEntries.remove(i);
        }
    }
    function prepareExternalHandoff(entry, source) {
        root.cancelExternalHandoff(root.handoffSerial);
        const serial = ++root.handoffSerial;
        root.handoffKey = entry.key;
        if (source && typeof source.registerDockHandoff === "function" && source.nativeDragActive)
            source.registerDockHandoff(root, serial);
        else
            Qt.callLater(() => root.finishExternalHandoff(serial));
    }
    function finishExternalHandoff(serial) {
        if (serial !== root.handoffSerial || !root.handoffKey)
            return;
        // The platform has already removed its drag image. Recreating it here
        // would flash a second icon before the real Dock entry appears.
        root.handoffKey = "";
    }
    function cancelExternalHandoff(serial) {
        if (serial !== root.handoffSerial || !root.handoffKey)
            return;
        root.handoffKey = "";
        ++root.handoffSerial;
    }
    function moveDrag(key, point, offset, size) {
        if (dragCancelled)
            return;
        if (dragKey !== key) {
            root.cancelExternalHandoff(root.handoffSerial);
            const entry = DockService.entryFor(key);
            if (!entry)
                return;
            dragGrabOffset = offset;
            dragGhost.begin(copyEntry(entry), Qt.point(point.x - offset.x, point.y - offset.y), size);
            dragKey = key;
            dismissPopup();
            content.forceActiveFocus();
        }
        dragPoint = point;
        pointerAxis = horizontal ? point.x : point.y;
        insertion = insertionAt(point);
        dragGhost.follow(Qt.point(point.x - dragGrabOffset.x, point.y - dragGrabOffset.y));
        dragGhost.removalArmed = removeOnRelease;
        revealed = true;
    }
    function finishDrag(key, point) {
        if (dragCancelled || dragKey !== key) {
            cancelDrag();
            dragCancelled = false;
            return;
        }
        dragPoint = point;
        const entry = DockService.entryFor(key);
        let removed = false;
        if (removeOnRelease || targetAt(point)?.kind === "trash")
            removed = DockService.unpin(key);
        else if (entry && insideDropBand(point)) {
            const target = DockService.pinIndexForSlot(insertionAt(point), entry.kind);
            if (entry.pinned)
                DockService.movePinned(key, target);
            else if (entry.desktopId)
                DockService.pin(entry.desktopId, target);
        }
        dragKey = "";
        insertion = -1;
        if (removed)
            dragGhost.remove();
        else
            Qt.callLater(root.landGhost);
        dragCancelled = false;
        updateInteraction();
    }
    function landGhost() {
        if (!dragGhost.active || dragKey)
            return;
        const slot = slotForKey(dragGhost.entry.key);
        if (!slot) {
            dragGhost.remove();
            return;
        }
        const major = (axisLength - bandLength) / 2 + slot.start + slot.span / 2 - scrollOffset;
        const cross = horizontal ? height - edgeOffset - 12 - slot.size / 2 : edge === "left" ? edgeOffset
                                                                                                + 10 + slot.size
                                                                                                / 2 : width
                                                                                                - edgeOffset
                                                                                                - 10 - slot.size
                                                                                                / 2;
        dragGhost.land(horizontal ? Qt.point(major, cross) : Qt.point(cross, major), slot.size);
    }
    function cancelDrag() {
        if (!dragKey)
            return;
        dragKey = "";
        insertion = -1;
        Qt.callLater(root.landGhost);
        updateInteraction();
    }
    function scrollBy(amount) {
        if (horizontal)
            icons.contentX = Math.max(icons.originX, Math.min(icons.originX + Math.max(0, icons.contentWidth
                                                                                       - icons.width),
                                                              icons.contentX + amount));
        else
            icons.contentY = Math.max(icons.originY, Math.min(icons.originY + Math.max(0, icons.contentHeight
                                                                                       - icons.height),
                                                              icons.contentY + amount));
    }

    ListModel {
        id: visualEntries
    }
    Connections {
        target: DockService
        function onRevisionChanged() {
            // Drop commits also clear the provisional gap in this event turn.
            // Create delegates only after that final slot layout has settled.
            Qt.callLater(root.syncVisualEntries);
            root.scheduleAnimationTargets();
        }
    }
    Connections {
        target: WindowPreviewService
        function onSuspendedChanged() {
            if (WindowPreviewService.suspended)
                root.dismissPopup();
        }
    }
    Component.onCompleted: root.syncVisualEntries()

    // The surface supplies animation/drag space. Input stays in the revealed
    // dock's footprint and edge corridor; hidden docks keep only the trigger.
    implicitWidth: screen ? screen.width : 1280
    implicitHeight: screen ? screen.height : 720
    color: "transparent"
    anchors.left: horizontal || edge === "left"
    anchors.right: horizontal || edge === "right"
    anchors.top: !horizontal
    anchors.bottom: true
    exclusiveZone: DockService.autoHide ? 0 : restingThickness + edgeOffset
    WlrLayershell.namespace: "clavis-shell-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: dragKey || contextMenu || filePopupActive ? WlrKeyboardFocus.Exclusive :
                                                                             WlrKeyboardFocus.None

    onInteractingChanged: updateInteraction()
    onFilePopupActiveChanged: updateInteraction()
    onShownChanged: {
        if (!shown)
            dismissPopup();
    }

    // Region changes can briefly reset HoverHandler during popup creation.
    // Preserve the last scene position and absorb that transient leave.
    Timer {
        id: magnificationExit
        interval: 80
        onTriggered: {
            if (!root.pointerOverDock)
                root.magnificationActive = false;
        }
    }
    Timer {
        id: hideTimer
        interval: 650
        onTriggered: {
            if (!root.interacting) {
                root.revealed = false;
                root.dismissPopup();
            }
        }
    }
    Timer {
        id: closeTimer
        interval: 350
        onTriggered: {
            if (!root.interacting)
                root.dismissPopup();
        }
    }
    Timer {
        id: hoverTimer
        interval: 450
        onTriggered: {
            if (root.pendingPopupKey && root.pendingPopupKey === root.hoverKey && root.pointerOverDock &&
                    !root.dragKey && !dragGhost.active)
                root.showPopup(root.pendingPopupKey, false);
        }
    }
    Timer {
        interval: 40
        repeat: true
        running: (root.dragKey !== "" || dropArea.containsDrag) && root.layout.overflow
        onTriggered: {
            const position = root.dragKey ? root.dragPoint : root.dropPoint;
            const local = icons.mapFromItem(content, position.x, position.y);
            const coordinate = root.horizontal ? local.x : local.y;
            if (coordinate < 28)
                root.scrollBy(-12);
            else if (coordinate > root.bandLength - 28)
                root.scrollBy(12);
            root.insertion = root.insertionAt(position);
        }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: event => {
            root.dragCancelled = true;
            root.cancelDrag();
            root.dismissPopup();
            event.accepted = true;
        }

        HoverHandler {
            id: surfaceHover
            onPointChanged: {
                if (root.pointerOverDock && !root.trackingFileDrag)
                    root.pointerAxis = root.horizontal ? point.scenePosition.x : point.scenePosition.y;
            }
        }

        // Click-opened file stacks stay open while browsing. Consume the
        // outside press like a menu, but release the screen for native drags.
        MouseArea {
            id: fileDismissArea
            anchors.fill: parent
            visible: root.filePopupActive && !DockService.fileDragActive
            acceptedButtons: Qt.AllButtons
            onPressed: event => {
                const inPopup = filePopup.mapFromItem(fileDismissArea, event.x, event.y);
                const inBand = band.mapFromItem(fileDismissArea, event.x, event.y);
                if (!filePopup.contains(inPopup) && !band.contains(inBand))
                    root.dismissPopup();
            }
        }

        Item {
            id: edgeTrigger
            width: root.horizontal ? Math.max(96, Math.min(root.availableLength, root.baseLayout.baseLength)) :
                                     3
            height: root.horizontal ? 3 : Math.max(96, Math.min(root.availableLength,
                                                                root.baseLayout.baseLength))
            x: root.horizontal ? (parent.width - width) / 2 : root.edge === "left" ? 0 : parent.width - width
            y: root.horizontal ? parent.height - height : (parent.height - height) / 2
            HoverHandler {
                id: edgeHover
                onHoveredChanged: {
                    if (hovered)
                        root.revealed = true;
                }
            }
            DropArea {
                anchors.fill: parent
                onEntered: drag => {
                    if (drag.formats.indexOf("application/x-clavis-dock") >= 0 || drag.hasUrls) {
                        root.revealed = true;
                        drag.accepted = true;
                    } else {
                        drag.accepted = false;
                    }
                }
            }
        }

        Item {
            id: dockInputArea
            // Region.item observes item geometry, not Translate animations.
            // Publish the destination footprint immediately and bridge the
            // edge gap, so entering/leaving the animated tray cannot unmap
            // its input or strand the pointer on the desktop underneath.
            x: root.horizontal ? band.x : root.edge === "left" ? 0 : band.x
            y: band.y
            width: band.width + (root.horizontal ? 0 : root.edgeOffset)
            height: band.height + (root.horizontal ? root.edgeOffset : 0)
        }

        Item {
            id: band
            width: root.horizontal ? root.bandLength : root.bandThickness
            height: root.horizontal ? root.bandThickness : root.bandLength
            x: root.horizontal ? (parent.width - width) / 2 : root.edge === "left" ? root.edgeOffset :
                                                                                     parent.width - width
                                                                                     - root.edgeOffset
            y: root.horizontal ? parent.height - height - root.edgeOffset : (parent.height - height) / 2
            opacity: root.shown ? 1 : 0
            // Keep effective visibility (and image sources/folder loaders)
            // alive while hidden. Opacity/translation hide the visuals; the
            // input mask and enabled state make them non-interactive.
            enabled: root.shown
            // Animate the centered tray with its slots, including app arrival
            // and removal; otherwise its origin would jump by half an icon.
            Behavior on width {
                enabled: root.horizontal && !root.directMagnification
                NumberAnimation {
                    duration: DockMotion.reflowDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: !root.horizontal && !root.directMagnification
                NumberAnimation {
                    duration: DockMotion.reflowDuration
                    easing.type: Easing.OutCubic
                }
            }
            transform: Translate {
                id: hideTranslation
                x: root.horizontal ? 0 : root.shown ? 0 : root.edge === "left" ? -band.width
                                                                                 - root.edgeOffset :
                                                                                 band.width + root.edgeOffset
                y: root.horizontal && !root.shown ? band.height + root.edgeOffset : 0
                Behavior on x {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            Rectangle {
                id: glass
                x: root.horizontal ? 0 : root.edge === "left" ? 0 : parent.width - width
                y: root.horizontal ? parent.height - height : 0
                width: root.horizontal ? parent.width : root.restingThickness
                height: root.horizontal ? root.restingThickness : parent.height
                radius: 20
                color: BlurService.backgroundColor(Appearance.colors.colSurfaceContainer)
                border.color: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.65)
                border.width: 1
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: {
                        const entry = DockService.model.count ? DockService.model.get(0) : null;
                        if (entry)
                            root.showPopup(entry.key, true);
                        else
                            ControlCenterService.openSearch("general.dock");
                    }
                }
            }

            Flickable {
                id: icons
                anchors.fill: parent
                contentWidth: root.horizontal ? root.layout.length : width
                contentHeight: root.horizontal ? height : root.layout.length
                // Let the last retiring icon finish outside the shrinking
                // tray. Overflow still needs a clipped scrolling viewport.
                clip: root.baseLayout.overflow || root.layout.overflow
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                onContentWidthChanged: root.scrollBy(0)
                onContentHeightChanged: root.scrollBy(0)

                Repeater {
                    model: root.layout.dividers
                    delegate: Rectangle {
                        required property real modelData
                        visible: true
                        width: root.horizontal ? 2 : root.restingThickness - 20
                        height: root.horizontal ? root.restingThickness - 20 : 2
                        x: root.horizontal ? modelData - width / 2 : glass.x + 10
                        y: root.horizontal ? glass.y + 10 : modelData - height / 2
                        radius: 1
                        color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.4)
                        Behavior on x {
                            enabled: !root.directMagnification
                            NumberAnimation {
                                duration: DockMotion.reflowDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            enabled: !root.directMagnification
                            NumberAnimation {
                                duration: DockMotion.reflowDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Repeater {
                    id: iconItems
                    model: visualEntries
                    onCountChanged: root.scheduleAnimationTargets()
                    delegate: DockItem {
                        id: dockItem
                        required property string key
                        required property bool retiring
                        property bool appeared: false
                        // mapToItem() does not track transform dependencies. Each
                        // delegate only invalidates the shared deferred snapshot.
                        readonly property var animationTargetGeometry: [x, y, width, height, artworkItem.x,
                            artworkItem.y, artworkItem.width, artworkItem.height, artworkItem.scale, kind, key,
                            retiring, dragged]
                        onAnimationTargetGeometryChanged: root.scheduleAnimationTargets()
                        readonly property bool awaitingHandoff: root.handoffKey === key
                        property real retirementAxis: 0
                        property real retirementSpan: 0
                        property real retirementSize: 0
                        function freezeRetirement() {
                            // Keep the exit centered where it was seen, even
                            // while the centered tray and neighbours close up.
                            retirementAxis = (root.horizontal ? x + band.x : y + band.y) - root.scrollOffset;
                            retirementSpan = root.horizontal ? width : height;
                            retirementSize = iconSize;
                        }
                        // Position is keyed by application, never by the order
                        // in which presentation objects happened to be created.
                        property var lastSlot: ({
                                                    start: 12,
                                                    span: 0,
                                                    size: root.baseLayout.size
                                                })
                        readonly property int slotIndex: {
                            const revision = DockService.revision;
                            const index = DockService.rowIndex(key);
                            return index < 0 ? -1 : root.preview.order.indexOf(index);
                        }
                        // Ease only discrete reordering. Sample the live wave at
                        // that fractional position so pointer motion never
                        // restarts a coordinate animation or trails the cursor.
                        property real visualSlotIndex: Math.max(0, slotIndex)
                        Behavior on visualSlotIndex {
                            enabled: dockItem.appeared && !dockItem.retiring && dockItem.slotIndex >= 0
                                     && root.directMagnification
                            NumberAnimation {
                                id: reorderAnimation
                                duration: DockMotion.reflowDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        readonly property var slot: {
                            const target = root.slotForKey(key);
                            if (!target)
                                return lastSlot;
                            if (!root.directMagnification && !reorderAnimation.running)
                                return target;
                            const slots = root.layout.slots;
                            const position = Math.max(0, Math.min(slots.length - 1, visualSlotIndex));
                            const lower = slots[Math.floor(position)];
                            const upper = slots[Math.ceil(position)];
                            if (!lower || !upper)
                                return target;
                            const fraction = position - Math.floor(position);
                            return {
                                start: lower.start + (upper.start - lower.start) * fraction,
                                span: lower.span + (upper.span - lower.span) * fraction,
                                size: lower.size + (upper.size - lower.size) * fraction
                            };
                        }
                        onSlotChanged: {
                            if (!retiring && root.slotForKey(key))
                                lastSlot = slot;
                        }
                        entryKey: key
                        edge: root.edge
                        x: root.horizontal ? retiring ? retirementAxis - band.x + root.scrollOffset :
                                                        slot.start : 0
                        y: root.horizontal ? 0 : retiring ? retirementAxis - band.y + root.scrollOffset :
                                                            slot.start
                        width: root.horizontal ? retiring ? retirementSpan : slot.span : icons.width
                        height: root.horizontal ? icons.height : retiring ? retirementSpan : slot.span
                        iconSize: retiring ? retirementSize : slot.size
                        directMagnification: root.directMagnification
                        restingIconSize: root.baseLayout.size
                        contextActive: root.popupKey === key && (root.contextMenu || kind === "folder"
                                                                 && filePopup.list)
                        folderExpanded: kind === "folder" && root.popupKey === key && !root.contextMenu &&
                                        !filePopup.list && !filePopup.closing

                        showTooltip: !root.contextMenu && !WindowPreviewService.suspended && (kind === "app"
                                                                                              ? root.popupKey
                                                                                                === key && (
                                                                                                    windowCount
                                                                                                    === 0 ||
                                                                                                    !DockService.showThumbnails) :
                                                                                                !spacer
                                                                                                && root.hoverKey
                                                                                                === key
                                                                                                && root.popupKey
                                                                                                !== key)
                        dragged: key === root.dragKey || (dragGhost.entry && dragGhost.entry.key === key) || (
                                     root.externalOver && !root.externalFiles && !root.dropTargetKey
                                     && root.externalSourceKey === key)
                        enabled: !retiring && !awaitingHandoff
                        presence: 0
                        function animatePresence() {
                            presenceAnimation.stop();
                            if (awaitingHandoff) {
                                presence = 0;
                                return;
                            }
                            presenceAnimation.to = retiring ? 0 : 1;
                            presenceAnimation.duration = retiring ? DockMotion.exitDuration :
                                                                    DockMotion.enterDuration;
                            presenceAnimation.start();
                        }
                        onAwaitingHandoffChanged: {
                            if (appeared)
                                animatePresence();
                        }
                        Component.onCompleted: {
                            appeared = true;
                            animatePresence();
                        }
                        onPresenceChanged: {
                            if (retiring && presence === 0)
                                Qt.callLater(root.removeRetired);
                        }
                        onRetiringChanged: {
                            if (appeared)
                                animatePresence();
                            if (retiring)
                                Qt.callLater(root.removeRetired);
                        }
                        NumberAnimation {
                            id: presenceAnimation
                            target: dockItem
                            property: "presence"
                            easing.type: Easing.OutCubic
                        }
                        Behavior on x {
                            enabled: dockItem.appeared && !dockItem.retiring && !root.directMagnification
                            NumberAnimation {
                                duration: DockMotion.reflowDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            enabled: dockItem.appeared && !dockItem.retiring && !root.directMagnification
                            NumberAnimation {
                                duration: DockMotion.reflowDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on width {
                            enabled: dockItem.appeared && !dockItem.retiring && root.horizontal &&
                                     !root.directMagnification

                            NumberAnimation {
                                duration: DockMotion.reflowDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on height {
                            enabled: dockItem.appeared && !dockItem.retiring && !root.horizontal &&
                                     !root.directMagnification
                            NumberAnimation {
                                duration: DockMotion.reflowDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                        onPressStarted: {
                            root.dragCancelled = false;
                            if (kind !== "folder" || root.popupKey !== key || root.contextMenu)
                                root.dismissPopup();
                        }
                        onHovered: key => root.hoverEntry(key)
                        onHoverLeft: key => root.leaveEntry(key)
                        dropTarget: root.dropTargetKey === key || !!root.dragKey && root.targetAt(root.dragPoint)
                                    ?.key === key && kind === "trash"
                        dropHint: kind === "trash" ? qsTr("Move to Trash") : qsTr("Open with %1").arg(name)
                        onActivated: key => {
                            root.dragCancelled = false;
                            if (kind === "folder") {
                                if (root.popupKey === key && !root.contextMenu) {
                                    if (filePopup.closing)
                                        filePopup.reopenPopup();
                                    else
                                        root.dismissPopup();
                                } else
                                    root.showPopup(key, false, true);
                            } else {
                                DockService.activate(key, root.screen.name);
                                root.dismissPopup();
                            }
                        }
                        onContextRequested: key => root.showPopup(key, true)
                        onDragMoved: (key, position, offset, size) => root.moveDrag(key, position, offset,
                                                                                    size)
                        onDragReleased: (key, position) => root.finishDrag(key, position)
                        onDragCancelled: {
                            root.cancelDrag();
                            root.dragCancelled = false;
                        }
                    }
                }
                ScrollBar.horizontal: StyledScrollBar {
                    visible: root.horizontal && root.layout.overflow
                }
                ScrollBar.vertical: StyledScrollBar {
                    visible: !root.horizontal && root.layout.overflow
                }
                WheelHandler {
                    target: null
                    onWheel: event => {
                        const delta = event.pixelDelta.y || event.pixelDelta.x || event.angleDelta.y
                              || event.angleDelta.x;
                        root.scrollBy(-delta);
                        event.accepted = true;
                    }
                }
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                onEntered: drag => {
                    // Foreign file data is validated on drop. In-process app
                    // drags can already preview their existing grouped identity.
                    drag.accepted = drag.formats.indexOf(DockService.dragMimeType) >= 0 || drag.hasUrls;
                    if (!drag.accepted)
                        return;
                    root.cancelExternalHandoff(root.handoffSerial);
                    root.externalEntries = DockService.dropEntries(drag.getDataAsString(
                                                                       DockService.dragMimeType), drag.urls);
                    root.externalKind = root.externalEntries.length ? root.externalEntries[0].kind : "app";
                    root.externalSourceKey = root.externalEntries.length === 1 ? (root.externalKind === "app"
                                                                                  ? "app:"
                                                                                    + root.externalEntries[0].desktopId :
                                                                                    root.externalFiles
                                                                                    ? "file:"
                                                                                      + root.externalEntries[0].url :
                                                                                      "") : "";
                    root.dropPoint = band.mapToItem(content, drag.x, drag.y);
                    root.externalOver = true;
                    root.pointerAxis = root.horizontal ? root.dropPoint.x : root.dropPoint.y;
                    root.updateDropTarget();
                    root.dismissPopup();
                    root.revealed = true;
                }
                onPositionChanged: drag => {
                    root.dropPoint = band.mapToItem(content, drag.x, drag.y);
                    if (root.trackingFileDrag) {
                        root.fileDragPositionPending = true;
                    } else {
                        root.pointerAxis = root.horizontal ? root.dropPoint.x : root.dropPoint.y;
                        root.updateDropTarget();
                    }
                }
                onExited: {
                    root.dropTargetKey = "";
                    root.externalEntries = [];
                    root.externalOver = false;
                    root.externalSourceKey = "";
                    root.insertion = -1;
                }
                onDropped: drop => {
                    root.dropPoint = band.mapToItem(content, drop.x, drop.y);
                    const text = drop.getDataAsString(DockService.dragMimeType);
                    const incoming = DockService.dropEntries(text, drop.urls);
                    const before = new Set();
                    for (let i = 0; i < DockService.model.count; ++i)
                        before.add(DockService.model.get(i).key);
                    root.externalEntries = incoming;
                    root.updateDropTarget();
                    if (root.dropTargetKey && root.externalFiles) {
                        const target = DockService.entryFor(root.dropTargetKey);
                        const urls = Array.from(drop.urls);
                        const trash = target.kind === "trash";
                        const desktopId = String(target.desktopId);
                        const operation = () => {
                            const ok = trash ? DesktopFiles.moveToTrash(urls) : DesktopFiles.openWith(
                                                   desktopId, urls);
                            if (!ok)
                                DockService.fileError = qsTr("The file operation could not be started.");
                        };
                        if (drop.source && typeof drop.source.deferDrop === "function")
                            drop.source.deferDrop(operation);
                        else
                            operation();
                        drop.accept(target.kind === "trash" ? Qt.MoveAction : Qt.CopyAction);
                        root.dropTargetKey = "";
                        root.externalEntries = [];
                        root.externalOver = false;
                        root.externalSourceKey = "";
                        root.insertion = -1;
                        return;
                    }
                    const accepted = DockService.acceptDrop(text, drop.urls, DockService.pinIndexForSlot(
                                                                root.insertion, root.externalKind));
                    let landingEntry = null;
                    if (accepted && incoming.length === 1) {
                        if (incoming[0].kind === "app")
                            landingEntry = DockService.entryFor("app:" + incoming[0].desktopId);
                        else if (incoming[0].kind === "file" || incoming[0].kind === "folder")
                            landingEntry = DockService.entryFor("file:" + incoming[0].url);
                        else {
                            for (let i = 0; i < DockService.model.count; ++i) {
                                const candidate = DockService.model.get(i);
                                if (!before.has(candidate.key)) {
                                    landingEntry = candidate;
                                    break;
                                }
                            }
                        }
                    }
                    // Keep new and reused entries hidden until the native drag
                    // ends, then let the actual delegate animate in once.
                    if (landingEntry)
                        root.prepareExternalHandoff(landingEntry, drop.source);
                    root.dropTargetKey = "";
                    root.externalEntries = [];
                    root.externalOver = false;
                    root.externalSourceKey = "";
                    root.insertion = -1;
                    if (accepted) {
                        drop.accept(Qt.CopyAction);
                    }
                    root.updateInteraction();
                }
            }

            Text {
                anchors.centerIn: glass
                visible: DockService.model.count === 0
                text: qsTr("Drop apps here")
                font.family: Fonts.ui
                font.pixelSize: 12
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        DockPreviewPopup {
            id: popup
            visible: !root.filePopupActive && root.popupKey !== "" && !!entry && (root.contextMenu || (
                                                                                      DockService.showThumbnails
                                                                                      && windows.length > 0))
            entryKey: root.popupKey
            outputName: root.screen.name
            maximumWidth: root.horizontal ? Math.max(0, root.width - 32) : Math.max(0, (root.edge === "left"
                                                                                        ? root.width
                                                                                          - root.popupCross :
                                                                                          root.popupCross)
                                                                                    - 24)
            contextMenu: root.contextMenu
            edge: root.edge
            anchorOffset: root.popupAxis - (root.horizontal ? x : y)
            readonly property real dockGap: root.contextMenu ? 4 : 8
            maximumHeight: root.horizontal ? Math.max(0, root.popupCross - dockGap - 16) : Math.max(0, root.height
                                                                                                    - 32)
            x: root.horizontal ? Math.max(16, Math.min(root.width - width - 16, root.popupAxis - (
                                                           root.contextMenu ? 26 : width / 2))) : root.edge
                                 === "left" ? root.popupCross + dockGap : root.popupCross - width - dockGap
            y: root.horizontal ? root.popupCross - height - dockGap : Math.max(16, Math.min(root.height
                                                                                            - height - 16,
                                                                                            root.popupAxis - (
                                                                                                root.contextMenu
                                                                                                ? 26 : height
                                                                                                  / 2)))
            onDismissed: root.dismissPopup()
        }

        DockFilePopup {
            id: filePopup
            visible: root.filePopupActive
            entryKey: root.popupKey
            contextMenu: root.contextMenu
            edge: root.edge
            labelsLeft: root.edge === "right" || root.horizontal && root.popupAxis > root.width / 2
            anchorOffset: root.popupAxis - (root.horizontal ? x : y)
            sourceCenter: Qt.point(root.popupSourceCenter.x - x, root.popupSourceCenter.y - y)
            iconSize: root.popupIconSize
            maximumFanOutset: labelsLeft ? root.width - root.popupAxis - 16 : root.popupAxis - 16
            readonly property real iconInset: fan ? fanIconInset : contextMenu || list ? 68 : width / 2
            maximumWidth: root.horizontal ? root.width - 32 : (root.edge === "left" ? root.width
                                                                                      - root.popupCross :
                                                                                      root.popupCross) - 24
            maximumHeight: root.horizontal ? root.popupCross - 24 : root.height - 32
            x: root.horizontal ? Math.max(16, Math.min(root.width - width - 16, root.popupAxis - (labelsLeft
                                                                                                  ? width - iconInset :
                                                                                                    iconInset))) :
                                 root.edge === "left" ? root.popupCross + 6 : root.popupCross - width - 6
            y: root.horizontal ? root.popupCross - height - 6 : Math.max(16, Math.min(root.height - height - 16,
                                                                                      root.popupAxis - height
                                                                                      / 2))
            onDismissed: root.finishDismissPopup()
        }

        DockDragVisual {
            id: dragGhost
            onActiveChanged: root.updateInteraction()
        }
    }

    mask: Region {
        Region {
            item: root.filePopupActive && !DockService.fileDragActive ? content : null
        }
        Region {
            item: root.shown ? dockInputArea : null
        }
        Region {
            item: edgeTrigger
        }
        Region {
            item: popup.visible ? popup : null
        }
        Region {
            id: fileInputRegion
        }
    }
    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: glass
        additionalBackgroundItems: (popup.visible ? popup.blurBackgroundItems : []).concat(
                                       filePopup.blurBackgroundItems, root.folderButtonItems)
        additionalRegions: filePopup.blurRegions
        blurEnabled: root.shown
        radius: 20
    }
}
