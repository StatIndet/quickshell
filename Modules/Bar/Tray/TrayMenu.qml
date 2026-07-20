import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

PanelWindow {
    id: root

    property var trayItemMenuHandle: null
    property string trayItemId: ""
    property var anchorItem: null
    property real padding: 10
    property real edgeMargin: 10
    property real anchorGap: 4
    property real menuX: edgeMargin
    property real menuY: edgeMargin

    signal menuClosed()
    signal menuOpened(var qsWindow)

    visible: false
    color: "transparent"
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "clavis-tray-menu"
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    mask: Region { item: inputRegion }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function updatePosition() {
        const surfaceWidth = Math.max(1, menuSurface.implicitWidth);
        const surfaceHeight = Math.max(1, menuSurface.implicitHeight);
        const availableWidth = Math.max(surfaceWidth + root.edgeMargin * 2, root.width);
        const availableHeight = Math.max(surfaceHeight + root.edgeMargin * 2, root.height);

        if (!root.anchorItem) {
            root.menuX = root.clamp((availableWidth - surfaceWidth) / 2, root.edgeMargin, availableWidth - surfaceWidth - root.edgeMargin);
            root.menuY = root.edgeMargin;
            return;
        }

        const globalPos = root.anchorItem.mapToGlobal(0, 0);
        const screenX = root.screen ? (root.screen.x || 0) : 0;
        const screenY = root.screen ? (root.screen.y || 0) : 0;
        const anchorX = globalPos.x - screenX;
        const anchorY = globalPos.y - screenY;
        const anchorWidth = root.anchorItem.width || 0;
        const anchorHeight = root.anchorItem.height || 0;

        root.menuX = root.clamp(
            anchorX + anchorWidth / 2 - surfaceWidth / 2,
            root.edgeMargin,
            availableWidth - surfaceWidth - root.edgeMargin
        );

        const belowY = anchorY + anchorHeight + root.anchorGap;
        const aboveY = anchorY - surfaceHeight - root.anchorGap;
        const maxY = availableHeight - surfaceHeight - root.edgeMargin;
        root.menuY = belowY <= maxY || aboveY < root.edgeMargin
            ? root.clamp(belowY, root.edgeMargin, maxY)
            : root.clamp(aboveY, root.edgeMargin, maxY);
    }

    function open() {
        root.visible = true;
        root.menuOpened(root);
        Qt.callLater(() => {
            root.updatePosition();
            keyScope.forceActiveFocus();
        });
    }

    function close() {
        if (!root.visible && stackView.depth <= 1)
            return;

        root.visible = false;
        while (stackView.depth > 1)
            stackView.pop();
        root.menuClosed();
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => {
                root.updatePosition();
                keyScope.forceActiveFocus();
            });
    }

    Item {
        id: inputRegion
        anchors.fill: parent
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        z: -1

        onClicked: event => {
            const outsideMenu = event.x < menuSurface.x
                || event.x > menuSurface.x + menuSurface.width
                || event.y < menuSurface.y
                || event.y > menuSurface.y + menuSurface.height;
            if (outsideMenu)
                root.close();
        }
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: root.visible

        Keys.onEscapePressed: event => {
            if (stackView.depth > 1)
                stackView.pop();
            else
                root.close();
            event.accepted = true;
        }

        Item {
            id: menuSurface

            x: root.menuX
            y: root.menuY
            implicitWidth: popupBackground.implicitWidth + root.padding * 2
            implicitHeight: popupBackground.implicitHeight + root.padding * 2
            width: implicitWidth
            height: implicitHeight

            onImplicitWidthChanged: Qt.callLater(root.updatePosition)
            onImplicitHeightChanged: Qt.callLater(root.updatePosition)

            StyledRectangularShadow {
                target: popupBackground
                opacity: popupBackground.opacity
            }

            Rectangle {
                id: popupBackground

                readonly property real popupPadding: 4

                x: root.padding
                y: root.padding
                implicitWidth: stackView.implicitWidth + popupPadding * 2
                implicitHeight: stackView.implicitHeight + popupPadding * 2
                color: Appearance.colors.colLayer0
                radius: 18
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                clip: true
                opacity: 0

                Component.onCompleted: opacity = 1

                Behavior on opacity {
                    NumberAnimation {
                        alwaysRunToEnd: true
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
                Behavior on implicitWidth {
                    NumberAnimation {
                        alwaysRunToEnd: true
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                Behavior on implicitHeight {
                    NumberAnimation {
                        alwaysRunToEnd: true
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                StackView {
                    id: stackView

                    anchors {
                        fill: parent
                        margins: popupBackground.popupPadding
                    }

                    implicitWidth: currentItem ? currentItem.implicitWidth : 0
                    implicitHeight: currentItem ? currentItem.implicitHeight : 0

                    onImplicitWidthChanged: Qt.callLater(root.updatePosition)
                    onImplicitHeightChanged: Qt.callLater(root.updatePosition)

                    pushEnter: NoAnim {}
                    pushExit: NoAnim {}
                    popEnter: NoAnim {}
                    popExit: NoAnim {}

                    initialItem: SubMenu {
                        handle: root.trayItemMenuHandle
                    }
                }
            }
        }
    }

    component NoAnim: Transition {
        NumberAnimation { duration: 0 }
    }

    component SubMenu: ColumnLayout {
        id: submenu

        required property var handle
        property bool isSubMenu: false
        property bool shown: false
        readonly property var menuEntries: menuOpener.children ? menuOpener.children.values : []

        opacity: shown ? 1 : 0
        spacing: 0

        Behavior on opacity {
            NumberAnimation {
                alwaysRunToEnd: true
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }
        }

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        QsMenuOpener {
            id: menuOpener
            menu: submenu.handle ? (submenu.handle.menu || submenu.handle) : null
        }

        Loader {
            Layout.fillWidth: true
            visible: submenu.isSubMenu
            active: visible

            sourceComponent: MaterialRippleButton {
                id: backButton

                buttonRadius: popupBackground.radius - popupBackground.popupPadding
                colBackground: Appearance.transparentize(Appearance.colors.colLayer0, 1)
                colBackgroundHover: Appearance.colors.colSecondaryContainer
                colRipple: Appearance.colors.colSecondaryContainerActive
                rippleEnabled: false
                implicitWidth: backContent.implicitWidth + 24
                implicitHeight: 36
                Layout.fillWidth: true
                releaseAction: () => stackView.pop()

                contentItem: RowLayout {
                    id: backContent

                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 8

                    MaterialSymbol {
                        text: "chevron_left"
                        iconSize: 20
                        color: backButton.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                    }

                    Text {
                        text: "Back"
                        color: backButton.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                        font.family: Sizes.fontFamily
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                }
            }
        }

        MaterialRippleButton {
            id: pinEntry

            visible: root.trayItemId.length > 0 && stackView.depth === 1
            buttonRadius: popupBackground.radius - popupBackground.popupPadding
            colBackground: Appearance.transparentize(Appearance.colors.colLayer0, 1)
            colBackgroundHover: Appearance.colors.colSecondaryContainer
            colRipple: Appearance.colors.colSecondaryContainerActive
            rippleEnabled: false
            implicitWidth: pinContent.implicitWidth + 24
            implicitHeight: 36
            Layout.fillWidth: true
            releaseAction: () => TrayService.togglePin(root.trayItemId)

            contentItem: RowLayout {
                id: pinContent

                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 8

                MaterialSymbol {
                    text: "push_pin"
                    iconSize: 18
                    color: pinEntry.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                }

                Text {
                    text: TrayService.isPinned(root.trayItemId) ? "Unpin" : "Pin"
                    color: pinEntry.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colSubtext
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        Repeater {
            id: menuEntriesRepeater

            property bool iconColumnNeeded: {
                for (let i = 0; i < submenu.menuEntries.length; i += 1) {
                    if ((submenu.menuEntries[i].icon || "").length > 0)
                        return true;
                }
                return false;
            }
            property bool specialInteractionColumnNeeded: {
                for (let i = 0; i < submenu.menuEntries.length; i += 1) {
                    if (submenu.menuEntries[i].buttonType !== QsMenuButtonType.None)
                        return true;
                }
                return false;
            }

            model: menuOpener.children

            delegate: TrayMenuEntry {
                required property var modelData

                menuEntry: modelData
                forceIconColumn: menuEntriesRepeater.iconColumnNeeded
                forceSpecialInteractionColumn: menuEntriesRepeater.specialInteractionColumnNeeded
                buttonRadius: popupBackground.radius - popupBackground.popupPadding

                onDismiss: root.close()
                onOpenSubmenu: handle => {
                    const menuHandle = handle ? (handle.menu || handle) : null;
                    stackView.push(subMenuComponent.createObject(null, {
                        "handle": handle,
                        "isSubMenu": true
                    }));
                    Qt.callLater(() => {
                        if (menuHandle && typeof menuHandle.updateLayout === "function")
                            menuHandle.updateLayout();
                        root.updatePosition();
                    });
                }
            }
        }
    }

    Component {
        id: subMenuComponent
        SubMenu {}
    }
}
