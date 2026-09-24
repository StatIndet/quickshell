pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.Common
import qs.Services
import qs.Widgets.common
import "../../Common/functions/DockLayout.js" as DockLayout
import "../../Common/functions/DockBubble.js" as DockBubble
import "../../Common/functions/DockMedia.js" as DockMedia

Item {
    id: root

    required property string entryKey
    required property string outputName
    required property real maximumWidth
    property real maximumHeight: 600
    property bool contextMenu: false
    property string edge: "bottom"
    readonly property string popupEdge: edge
    property real anchorOffset: width / 2
    readonly property var entry: {
        const revision = DockService.revision;
        return DockService.entryFor(root.entryKey);
    }
    readonly property var windows: {
        const revision = DockService.revision;
        return DockService.windowsFor(root.entryKey);
    }
    readonly property bool hovered: popupHover.hovered
    readonly property bool thumbnails: DockService.showThumbnails && DockService.supportsThumbnails
    readonly property var matchingPlayers: DockMedia.matchingPlayers(MediaManager.list, entry
                                                                     ? entry.desktopId : "")
    property var mediaPlayer: null
    onMatchingPlayersChanged: mediaPlayer = DockMedia.selectPlayer(matchingPlayers, mediaPlayer)
    property string previewConsumer: ""
    readonly property var captureTargets: !visible || contextMenu || !thumbnails ||
                                          !WindowPreviewService.connected ? [] : windows.map(window => String(
                                                                                                           window.id))
    onCaptureTargetsChanged: WindowPreviewService.setTargets(previewConsumer, captureTargets)
    Component.onCompleted: {
        mediaPlayer = DockMedia.selectPlayer(matchingPlayers, mediaPlayer);
        previewConsumer = WindowPreviewService.createConsumer();
        WindowPreviewService.setTargets(previewConsumer, captureTargets);
    }
    Component.onDestruction: WindowPreviewService.release(previewConsumer)
    readonly property string entryName: entry ? String(entry.name || "") : ""
    readonly property bool canLaunch: !!entry && entry.kind === "app" && entry.available && String(
                                          entry.desktopId || "").length > 0
    readonly property var desktopActions: contextMenu && canLaunch ? ApplicationService.actionsForApplication(
                                                                         entry.desktopId) : []
    readonly property bool canChangePin: !!entry && (entry.pinned || (DockService.contextPinning
                                                                      && canLaunch))

    readonly property var rowLayout: DockLayout.windowPreviewRow(windows.length, thumbnails
                                                                 ? DockService.previewSize * 1.6 + 16 : 220,
                                                                 maximumWidth)
    readonly property real contentMargin: contextMenu ? 6 : rowLayout.margin

    readonly property real tailSize: contextMenu ? 10 : 0
    readonly property real bodyX: contextMenu && edge === "left" ? tailSize : 0
    readonly property real bodyWidth: width - (edge === "bottom" ? 0 : tailSize)
    readonly property real bodyHeight: contextMenu ? Math.min(menuContent.height + contentMargin * 2, Math.max(
                                                                  0, maximumHeight - tailSize)) :
                                                     windowRow.height + contentMargin * 2

    readonly property color surfaceColor: BlurService.backgroundColor(Appearance.colors.colSurfaceContainer)
    readonly property color outlineColor: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.18)

    signal dismissed

    width: contextMenu ? Math.min(Math.max(0, maximumWidth), 280) : rowLayout.width
    height: bodyHeight + (edge === "bottom" ? tailSize : 0)

    HoverHandler {
        id: popupHover
    }

    readonly property var bubbleOutline: DockBubble.outline(width, bodyHeight, edge, tailSize, anchorOffset)
    readonly property var blurRectangles: visible ? DockBubble.regionRects(bubbleOutline, height) : []
    property var blurBackgroundItems: []

    function updateBlurItems() {
        const items = [];
        for (let i = 0; i < blurStrips.count; ++i) {
            const item = blurStrips.itemAt(i);
            if (item)
                items.push(item);
        }
        blurBackgroundItems = items;
    }

    // Empty geometry items supply exact scanline regions to the existing blur
    // publisher. Adjacent identical rows are merged, including the flat body.
    Repeater {
        id: blurStrips
        model: root.blurRectangles
        onItemAdded: Qt.callLater(root.updateBlurItems)
        onItemRemoved: Qt.callLater(root.updateBlurItems)
        delegate: Item {
            required property var modelData
            readonly property real radius: 0
            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: modelData.height
        }
    }

    Canvas {
        id: bubble
        anchors.fill: parent
        antialiasing: true
        readonly property var outline: root.bubbleOutline
        readonly property color fillColor: root.surfaceColor
        readonly property color lineColor: root.outlineColor
        onOutlineChanged: requestPaint()
        onFillColorChanged: requestPaint()
        onLineColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            DockBubble.paint(ctx, outline);
            ctx.fillStyle = fillColor;
            ctx.fill();
            ctx.strokeStyle = lineColor;
            ctx.lineWidth = 1;
            ctx.stroke();
        }
    }

    Row {
        id: windowRow
        visible: !root.contextMenu
        x: root.bodyX + root.contentMargin
        y: root.contentMargin
        spacing: root.rowLayout.gap
        Repeater {
            model: root.contextMenu ? [] : root.windows
            delegate: DockWindowCard {
                required property var modelData
                windowData: modelData
                applicationName: root.entryName
                applicationIcon: String(root.entry && root.entry.icon || "")
                mediaPlayer: root.mediaPlayer
                width: root.rowLayout.cardWidth
                showThumbnail: root.thumbnails
                capture: {
                    const revision = WindowPreviewService.revision;
                    return root.visible && root.thumbnails ? WindowPreviewService.captureFor(modelData.id) :
                                                             null;
                }
                previewFrame: {
                    const revision = WindowPreviewService.revision;
                    return root.visible && root.thumbnails ? WindowPreviewService.frameFor(modelData.id) :
                                                             null;
                }
                onActivated: {
                    DockService.focusWindow(modelData.id, root.outputName);
                    root.dismissed();
                }
                onCloseRequested: DockService.closeWindow(modelData.id)
            }
        }
    }

    Flickable {
        id: menuViewport
        visible: root.contextMenu
        x: root.bodyX + root.contentMargin
        y: root.contentMargin
        width: Math.max(0, root.bodyWidth - root.contentMargin * 2)
        height: Math.max(0, root.bodyHeight - root.contentMargin * 2)
        contentHeight: menuContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StyledScrollBar {}
        onVisibleChanged: contentY = 0
        Connections {
            target: root
            function onEntryKeyChanged() {
                menuViewport.contentY = 0;
            }
        }
        Column {
            id: menuContent
            width: menuViewport.width
            spacing: 4

            Text {
                width: parent.width - 16
                x: 8
                height: 32
                visible: root.windows.length === 0
                text: root.entryName
                textFormat: Text.PlainText
                font.family: Fonts.ui
                font.pixelSize: 12
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Item {
                width: parent.width
                height: windowMenu.height
                visible: root.windows.length > 0
                Column {
                    id: windowMenu
                    width: parent.width
                    Repeater {
                        model: root.contextMenu ? root.windows : []
                        delegate: StyledMenuItem {
                            required property var modelData
                            width: windowMenu.width
                            implicitHeight: 32
                            leftPadding: 8
                            rightPadding: 8
                            text: String(modelData.title || root.entryName)
                            checkable: true
                            checked: !!modelData.isFocused
                            onTriggered: {
                                DockService.focusWindow(modelData.id, root.outputName);
                                root.dismissed();
                            }
                        }
                    }
                }
            }
            Rectangle {
                x: 8
                width: Math.max(0, parent.width - 16)
                height: 1
                color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.16)
            }
            Column {
                width: parent.width
                visible: root.desktopActions.length > 0
                Repeater {
                    model: root.desktopActions
                    delegate: StyledMenuItem {
                        id: desktopActionItem
                        required property DesktopAction modelData
                        width: menuContent.width
                        implicitHeight: 32
                        leftPadding: 8
                        rightPadding: 8
                        text: modelData.name
                        contentItem: RowLayout {
                            spacing: 8
                            ThemeIcon {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                visible: desktopActionItem.modelData.icon !== ""
                                iconSource: visible ? ApplicationService.iconSource(
                                                          desktopActionItem.modelData.icon) : ""
                                sourceSize: Qt.size(32, 32)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: desktopActionItem.text
                                textFormat: Text.PlainText
                                font.family: Fonts.ui
                                font.pixelSize: Typography.labelLarge.pixelSize
                                font.weight: Typography.labelLarge.weight
                                color: desktopActionItem.foreground
                                elide: Text.ElideRight
                            }
                        }
                        onTriggered: {
                            if (!root.canLaunch)
                                return;
                            if (ApplicationService.launchApplicationAction(root.entry.desktopId,
                                                                           modelData.id))
                                root.dismissed();
                        }
                    }
                }
            }
            Rectangle {
                visible: root.desktopActions.length > 0
                x: 8
                width: Math.max(0, parent.width - 16)
                height: 1
                color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.16)
            }
            Text {
                width: parent.width - 16
                x: 8
                visible: !!root.entry && root.entry.kind === "app" && !root.entry.available
                         && root.windows.length === 0
                text: qsTr("Application is unavailable")
                font.family: Fonts.ui
                font.pixelSize: 12
                color: Appearance.colors.colOnSurfaceVariant
                wrapMode: Text.Wrap
            }
            Column {
                id: actions
                width: parent.width
                StyledMenuItem {
                    width: parent.width
                    implicitHeight: 32
                    leftPadding: 8
                    rightPadding: 8
                    visible: root.canLaunch
                    text: qsTr("Open application")
                    onTriggered: {
                        if (!root.canLaunch)
                            return;
                        DockService.launch(root.entryKey);
                        root.dismissed();
                    }
                }
                StyledMenuItem {
                    width: parent.width
                    implicitHeight: 32
                    leftPadding: 8
                    rightPadding: 8
                    visible: root.canChangePin
                    text: root.entry && root.entry.pinned ? qsTr("Remove from Dock") : qsTr("Pin to Dock")
                    onTriggered: {
                        const entry = DockService.entryFor(root.entryKey);
                        if (!entry)
                            return;
                        if (entry.pinned)
                            DockService.unpin(root.entryKey);
                        else if (root.canChangePin)
                            DockService.pin(entry.desktopId);
                        root.dismissed();
                    }
                }
                StyledMenuItem {
                    width: parent.width
                    implicitHeight: 32
                    leftPadding: 8
                    rightPadding: 8
                    text: qsTr("Dock settings")
                    onTriggered: {
                        ControlCenterService.openSearch("general.dock");
                        root.dismissed();
                    }
                }
            }
        }
    }
}
