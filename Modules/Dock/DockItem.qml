pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../Common/functions/DockMotion.js" as DockMotion

Item {
    id: root

    required property string entryKey
    required property string kind
    required property string name
    required property string icon
    required property string symbol
    required property bool pinned
    required property bool focused
    required property bool launching
    required property bool available
    required property int windowCount
    required property string edge
    required property real iconSize
    required property real restingIconSize
    property bool directMagnification: false
    readonly property bool spacer: kind === "spacer" || kind === "small-spacer"
    readonly property alias pointerArea: pointer
    readonly property bool pointerHovered: pointer.containsMouse
    property bool dragged: false
    property bool contextActive: false
    property bool folderExpanded: false
    property real folderOpenProgress: folderExpanded ? 1 : 0
    readonly property alias folderButtonBackground: folderButton
    property bool dropTarget: false
    property string dropHint: ""
    property bool showTooltip: false
    readonly property string popupEdge: edge
    readonly property alias artworkItem: artwork
    readonly property bool trashIconAvailable: {
        const revision = ThemeService.iconThemeRevision;
        return kind === "trash" && Quickshell.hasThemeIcon(icon);
    }
    property real presence: 1
    readonly property bool horizontal: edge === "bottom"
    property real bounce: 0
    property bool moved: false
    property point pressPoint
    property point grabOffset

    signal hovered(string key)
    signal hoverLeft(string key)
    signal pressStarted
    signal activated(string key)
    signal contextRequested(string key)
    signal dragMoved(string key, point position, point offset, real size)
    signal dragReleased(string key, point position)
    signal dragCancelled

    opacity: dragged ? 0 : presence

    Behavior on folderOpenProgress {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Behavior on iconSize {
        enabled: !root.directMagnification
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    // A launch gets one acknowledgement, independent of how long the app
    // takes to map its first window. Finish the arc even if it maps early.
    function animateLaunch() {
        if (launching && DockService.launchBounce && kind === "app")
            launchAnimation.start();
    }
    onLaunchingChanged: animateLaunch()
    Component.onCompleted: animateLaunch()
    SequentialAnimation {
        id: launchAnimation
        NumberAnimation {
            target: root
            property: "bounce"
            from: 0
            to: 19
            duration: 220
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bounce"
            to: 0
            duration: 340
            easing.type: Easing.OutBounce
        }
        onStopped: root.bounce = 0
    }

    Item {
        id: artwork
        width: root.iconSize
        height: width
        x: root.horizontal ? (root.width - width) / 2 : root.edge === "left" ? 10 + root.bounce : root.width
                                                                               - width - 10 - root.bounce
        y: root.horizontal ? root.height - height - 12 - root.bounce : (root.height - height) / 2
        transformOrigin: Item.Center
        scale: DockMotion.iconScale(root.presence)
        property real pressShade: (pointer.pressed && !root.moved) || root.contextActive || root.dropTarget
                                  ? 0.3 : 0
        Behavior on pressShade {
            NumberAnimation {
                duration: 90
            }
        }
        layer.enabled: pressShade > 0
        layer.effect: MultiEffect {
            brightness: -artwork.pressShade
        }
        opacity: root.available || root.windowCount > 0 || root.spacer ? 1 : 0.45

        ThemeIcon {
            anchors.fill: parent
            visible: (root.kind === "app" || root.trashIconAvailable) && !root.symbol
            iconSource: visible ? ApplicationService.iconSource(root.icon) : ""
            sourceSize: Qt.size(160, 160)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.kind === "app" && !!root.symbol || root.kind === "trash" && !root.trashIconAvailable
            text: root.kind === "trash" ? "delete" : root.symbol
            iconSize: root.iconSize * 0.82
            color: Appearance.colors.colPrimary
        }
        DockFileArtwork {
            anchors.fill: parent
            visible: root.kind === "file" || root.kind === "folder"
            entryKey: root.entryKey
            opacity: 1 - root.folderOpenProgress
        }
        Rectangle {
            id: folderButton
            anchors.fill: parent
            visible: root.kind === "folder" && opacity > 0
            opacity: root.folderOpenProgress
            radius: width * 0.23
            color: BlurService.backgroundColor(Appearance.colors.colSurfaceContainer)
            border.width: 1
            border.color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.2)
            MaterialSymbol {
                anchors.centerIn: parent
                anchors.alignWhenCentered: false
                text: root.edge === "bottom" ? "expand_more" : root.edge === "left" ? "chevron_left" :
                                                                                      "chevron_right"

                // Magnify one glyph continuously instead of changing hinted
                // pixel sizes and optical font variants during pointer motion.
                iconSize: 32
                scale: parent.width / (iconSize * 2)
                renderType: Text.QtRendering
                color: Appearance.colors.colOnSurface
            }
        }
        StyledToolTip {
            text: root.dropTarget ? root.dropHint : root.name
            textFormat: Text.PlainText
            extraVisibleCondition: root.dropTarget || root.showTooltip && pointer.containsMouse &&
                                   !pointer.pressed && !root.dragged && !root.contextActive
        }
    }

    Rectangle {
        visible: root.kind === "app" && root.windowCount > 0 && DockService.showIndicators
        // Scale with the resting icons, so hover magnification does not pulse the dot.
        width: Math.round(Math.max(5, Math.min(8, root.restingIconSize / 8)))
        height: width
        radius: width / 2
        x: root.horizontal ? (root.width - width) / 2 : root.edge === "left" ? 8 - width : root.width - 8
        y: root.horizontal ? root.height - 10 : (root.height - height) / 2
        color: Appearance.applyAlpha(Appearance.colors.colOnSurface, root.focused ? 1 : 0.8)
    }
    MouseArea {
        id: pointer
        // Keep the tray clickable, but exclude the empty magnification headroom.
        x: root.horizontal || root.edge === "left" ? 0 : Math.min(artwork.x, root.width - root.restingIconSize
                                                                  - 22)
        y: root.horizontal ? Math.min(artwork.y, root.height - root.restingIconSize - 22) : 0
        width: root.horizontal ? root.width : root.edge === "left" ? Math.max(artwork.x + artwork.width,
                                                                              root.restingIconSize + 22) :
                                                                     root.width - x
        height: root.horizontal ? root.height - y : root.height
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.spacer ? Qt.ArrowCursor : Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: root.name
        Accessible.onPressAction: root.activated(root.entryKey)
        onEntered: root.hovered(root.entryKey)
        onExited: root.hoverLeft(root.entryKey)
        onPressed: mouse => {
            root.pressStarted();
            root.moved = false;
            root.pressPoint = pointer.mapToItem(null, mouse.x, mouse.y);
            const center = artwork.mapToItem(null, artwork.width / 2, artwork.height / 2);
            root.grabOffset = Qt.point(root.pressPoint.x - center.x, root.pressPoint.y - center.y);
        }
        onPositionChanged: mouse => {
            if (root.kind === "trash" || !(pressedButtons & Qt.LeftButton))
                return;
            const position = pointer.mapToItem(null, mouse.x, mouse.y);
            if (!root.moved && Math.hypot(position.x - root.pressPoint.x, position.y - root.pressPoint.y)
                    < 10)

                return;
            root.moved = true;
            root.dragMoved(root.entryKey, position, root.grabOffset, root.iconSize);
        }
        onReleased: mouse => {
            if (root.moved)
                root.dragReleased(root.entryKey, pointer.mapToItem(null, mouse.x, mouse.y));
        }
        onCanceled: {
            root.moved = true;
            root.dragCancelled();
        }
        onClicked: mouse => {
            if (root.moved)
                return;
            if (mouse.button === Qt.RightButton)
                root.contextRequested(root.entryKey);
            else
                root.activated(root.entryKey);
        }
        onPressAndHold: {
            if (!root.moved)
                root.contextRequested(root.entryKey);
        }
    }
}
