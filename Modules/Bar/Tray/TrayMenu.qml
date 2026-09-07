import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

PopupWindow {
    id: root

    required property QsMenuHandle trayItemMenuHandle
    property string trayItemId: ""
    property Item anchorItem: null
    property var barVisualItem: null
    property var screen: null
    property string edge: "top"
    property real padding: 10
    property bool opened: false
    readonly property real verticalAnchorPadding: {
        if (!root.anchorItem || !root.barVisualItem || (root.edge !== "left" && root.edge !== "right")
                || root.barVisualItem.QsWindow.window !== root.anchorItem.QsWindow.window)
            return 0;
        return Math.max(0, (root.barVisualItem.width - root.anchorItem.width) / 2 + Sizes.barPopupGap
                        - root.padding);
    }

    signal menuClosed
    signal menuOpened(var qsWindow)

    function open() {
        if (root.opened)
            return;

        root.opened = true;
        root.visible = true;
        root.menuOpened(root);
        keyScope.forceActiveFocus();
    }

    function close() {
        root.visible = false;
    }

    function finishClose() {
        if (!root.opened)
            return;

        root.opened = false;
        while (stackView.depth > 1)
            stackView.pop();
        root.menuClosed();
    }

    visible: false
    color: "transparent"
    grabFocus: ThemeService.isNiriSession
    implicitWidth: popupBackground.implicitWidth + root.padding * 2
    implicitHeight: popupBackground.implicitHeight + root.padding * 2
    onVisibleChanged: {
        if (!visible)
            root.finishClose();
    }

    anchor {
        item: root.anchorItem
        // Keep the native item anchor so Quickshell maps the icon into its
        // window before positioning the popup. Expand only the vertical bar's
        // cross-axis bounds to leave room between the pill and visible menu.
        rect.x: -root.verticalAnchorPadding
        rect.y: 0
        rect.width: Math.max(1, (root.anchorItem ? root.anchorItem.width : 1) + root.verticalAnchorPadding
                             * 2)
        rect.height: Math.max(1, root.anchorItem ? root.anchorItem.height : 1)
        edges: root.edge === "left" ? Edges.Right : root.edge === "right" ? Edges.Left : root.edge
                                                                            === "bottom" ? Edges.Top :
                                                                                           Edges.Bottom
        gravity: root.edge === "left" ? Edges.Right : root.edge === "right" ? Edges.Left : root.edge
                                                                              === "bottom" ? Edges.Top :
                                                                                             Edges.Bottom
        adjustment: root.edge === "left" || root.edge === "right" ? PopupAdjustment.SlideY :
                                                                    PopupAdjustment.SlideX

    }

    PanelWindow {
        visible: root.visible && ThemeService.isNiriSession
        screen: root.screen
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "clavis-shell-tray-menu-backdrop"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.close()
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

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.BackButton | Qt.RightButton
            onPressed: event => {
                if ((event.button === Qt.BackButton || event.button === Qt.RightButton) && stackView.depth
                        > 1) {
                    stackView.pop();
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }

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
                color: BlurService.backgroundColor(Appearance.colors.colLayer0)
                radius: 18
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                clip: true
                opacity: 0
                Component.onCompleted: opacity = 1

                StackView {
                    id: stackView

                    implicitWidth: currentItem ? currentItem.implicitWidth : 0
                    implicitHeight: currentItem ? currentItem.implicitHeight : 0

                    anchors {
                        fill: parent
                        margins: popupBackground.popupPadding
                    }

                    pushEnter: NoAnimation {}

                    pushExit: NoAnimation {}

                    popEnter: NoAnimation {}

                    popExit: NoAnimation {}

                    initialItem: SubMenu {
                        handle: root.trayItemMenuHandle
                    }
                }

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
            }
        }
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: popupBackground
    }

    Component {
        id: subMenuComponent

        SubMenu {}
    }

    component NoAnimation: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: ColumnLayout {
        id: submenu

        required property QsMenuHandle handle
        property bool isSubmenu: false
        property bool shown: false

        spacing: 0
        opacity: shown ? 1 : 0
        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false

        QsMenuOpener {
            id: menuOpener

            menu: submenu.handle
        }

        Loader {
            Layout.fillWidth: true
            visible: submenu.isSubmenu
            active: visible

            sourceComponent: RippleButton {
                id: backButton

                buttonRadius: popupBackground.radius - popupBackground.popupPadding
                containerColor: "transparent"
                stateLayerColor: Appearance.colors.colSecondaryContainer
                pressedStateLayerColor: Appearance.colors.colSecondaryContainerActive
                rippleColor: Appearance.colors.colOnSecondaryContainer
                implicitWidth: backContent.implicitWidth + 24
                implicitHeight: 36
                Layout.fillWidth: true
                releaseAction: () => {
                    return stackView.pop();
                }

                contentItem: RowLayout {
                    id: backContent

                    spacing: 8

                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        leftMargin: 12
                        rightMargin: 12
                    }

                    MaterialSymbol {
                        text: "chevron_left"
                        iconSize: 20
                        color: backButton.pointerHovered ? Appearance.colors.colOnSecondaryContainer :
                                                           Appearance.colors.colOnLayer0
                    }

                    Text {
                        text: qsTr("Back")
                        color: backButton.pointerHovered ? Appearance.colors.colOnSecondaryContainer :
                                                           Appearance.colors.colOnLayer0
                        font.family: Fonts.ui
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Repeater {
            id: menuEntriesRepeater

            property bool iconColumnNeeded: {
                const entries = menuOpener.children.values;
                for (let i = 0; i < entries.length; i += 1) {
                    const entry = entries[i];
                    if (entry && (entry.icon || "").length > 0)
                        return true;
                }
                return false;
            }
            property bool specialInteractionColumnNeeded: {
                const entries = menuOpener.children.values;
                for (let i = 0; i < entries.length; i += 1) {
                    const entry = entries[i];
                    if (entry && entry.buttonType !== QsMenuButtonType.None)
                        return true;
                }
                return false;
            }

            model: menuOpener.children

            delegate: TrayMenuEntry {
                required property QsMenuEntry modelData

                menuEntry: modelData
                forceIconColumn: menuEntriesRepeater.iconColumnNeeded
                forceSpecialInteractionColumn: menuEntriesRepeater.specialInteractionColumnNeeded
                buttonRadius: popupBackground.radius - popupBackground.popupPadding
                onDismiss: root.close()
                onOpenSubmenu: handle => {
                    stackView.push(subMenuComponent, {
                                       "handle": handle,
                                       "isSubmenu": true
                                   });
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                alwaysRunToEnd: true
                duration: Appearance.animation.expressiveEffects.duration
                easing.type: Appearance.animation.expressiveEffects.type
                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
            }
        }
    }
}
