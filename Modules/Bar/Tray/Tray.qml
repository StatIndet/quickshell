import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

TopBarPill {
    id: root

    property bool trayOverflowOpen: false
    property bool vertical: false
    property string edge: "top"
    property var barVisualItem: null
    property var activeMenu: null
    property var screen: null
    property real overflowX: 10
    property real overflowY: 10
    property real overflowEdgeMargin: Sizes.barPopupScreenMargin
    property real overflowPopupGap: Sizes.barPopupGap
    property real overflowSurfacePadding: 10
    property real overflowAnchorX: 10
    property real overflowAnchorY: 10
    property real overflowAnchorWidth: 0
    property real overflowAnchorHeight: 0
    property bool overflowAnchorReady: false
    readonly property var pinnedItems: TrayService.pinnedItems
    readonly property var unpinnedItems: TrayService.unpinnedItems

    implicitHeight: vertical ? content.implicitHeight + 2 * root.pillPadding : root.pillThickness
    implicitWidth: vertical ? root.pillThickness : content.implicitWidth + 2 * root.pillPadding

    onUnpinnedItemsChanged: {
        if (root.unpinnedItems.length === 0) {
            root.trayOverflowOpen = false;
            root.overflowAnchorReady = false;
        } else if (root.trayOverflowOpen) {
            Qt.callLater(root.updateOverflowPosition);
        }
    }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function captureOverflowAnchor() {
        if (!trayOverflowButton.visible || trayOverflowButton.width <= 0 || trayOverflowButton.height <= 0) {
            root.overflowAnchorReady = false;
            return;
        }

        const globalPos = trayOverflowButton.mapToGlobal(0, 0);
        const screenX = root.screen ? (root.screen.x || 0) : 0;
        const screenY = root.screen ? (root.screen.y || 0) : 0;

        root.overflowAnchorX = globalPos.x - screenX;
        root.overflowAnchorY = globalPos.y - screenY;
        root.overflowAnchorWidth = trayOverflowButton.width || 0;
        root.overflowAnchorHeight = trayOverflowButton.height || 0;
        root.overflowAnchorReady = true;
    }

    function barVisualBounds() {
        if (!root.barVisualItem)
            return null;

        const globalPos = root.barVisualItem.mapToGlobal(0, 0);
        const screenX = root.screen ? (root.screen.x || 0) : 0;
        const screenY = root.screen ? (root.screen.y || 0) : 0;
        return {
            "x": globalPos.x - screenX,
            "y": globalPos.y - screenY,
            "width": root.barVisualItem.width || 0,
            "height": root.barVisualItem.height || 0
        };
    }

    function updateOverflowPosition() {
        const surfaceWidth = Math.max(1, overflowSurface.implicitWidth);
        const surfaceHeight = Math.max(1, overflowSurface.implicitHeight);
        const screenWidth = root.screen ? (root.screen.width || 0) : 0;
        const screenHeight = root.screen ? (root.screen.height || 0) : 0;
        const availableWidth = Math.max(surfaceWidth + root.overflowEdgeMargin * 2, overflowPopup.width,
                                        screenWidth);
        const availableHeight = Math.max(surfaceHeight + root.overflowEdgeMargin * 2, overflowPopup.height,
                                         screenHeight);
        const anchorX = root.overflowAnchorReady ? root.overflowAnchorX : root.overflowEdgeMargin;
        const anchorY = root.overflowAnchorReady ? root.overflowAnchorY : root.overflowEdgeMargin;
        const anchorWidth = root.overflowAnchorReady ? root.overflowAnchorWidth : 0;
        const anchorHeight = root.overflowAnchorReady ? root.overflowAnchorHeight : 0;
        const barBounds = root.barVisualBounds();

        const rightX = barBounds ? barBounds.x + barBounds.width + root.overflowPopupGap - root.overflowSurfacePadding :
                                   anchorX + anchorWidth + root.overflowPopupGap;
        const leftX = barBounds ? barBounds.x - surfaceWidth - root.overflowPopupGap
                                  + root.overflowSurfacePadding : anchorX - surfaceWidth
                                  - root.overflowPopupGap;
        const maxX = availableWidth - surfaceWidth - root.overflowEdgeMargin;
        root.overflowX = root.edge === "left" ? root.clamp(rightX, root.overflowEdgeMargin, maxX) : root.edge === "right"
                                                ? root.clamp(leftX, root.overflowEdgeMargin, maxX) :
                                                  root.clamp(anchorX + anchorWidth / 2 - surfaceWidth / 2,
                                                             root.overflowEdgeMargin, maxX);

        const belowY = barBounds ? barBounds.y + barBounds.height + root.overflowPopupGap - root.overflowSurfacePadding :
                                   anchorY + anchorHeight + root.overflowPopupGap;
        const aboveY = barBounds ? barBounds.y - surfaceHeight - root.overflowPopupGap
                                   + root.overflowSurfacePadding : anchorY - surfaceHeight
                                   - root.overflowPopupGap;
        const maxY = availableHeight - surfaceHeight - root.overflowEdgeMargin;
        root.overflowY = root.vertical ? root.clamp(anchorY + anchorHeight / 2 - surfaceHeight / 2,
                                                    root.overflowEdgeMargin, maxY) : root.edge === "bottom"
                                         ? root.clamp(aboveY, root.overflowEdgeMargin, maxY) : root.clamp(
                                               belowY, root.overflowEdgeMargin, maxY);
    }

    function setActiveMenu(window) {
        if (root.activeMenu && root.activeMenu !== window && typeof root.activeMenu.close === "function")
            root.activeMenu.close();
        root.activeMenu = window;
    }

    function releaseActiveMenu(window) {
        if (!window || root.activeMenu === window)
            root.activeMenu = null;
    }

    function closeActiveMenu() {
        if (root.activeMenu && typeof root.activeMenu.close === "function")
            root.activeMenu.close();
        root.activeMenu = null;
    }

    onTrayOverflowOpenChanged: {
        if (!root.trayOverflowOpen)
            root.overflowAnchorReady = false;
    }
    onEdgeChanged: {
        if (root.trayOverflowOpen)
            Qt.callLater(root.updateOverflowPosition);
    }

    GridLayout {
        id: content

        anchors.centerIn: parent
        rowSpacing: Sizes.barItemSpacing
        columnSpacing: Sizes.barItemSpacing
        columns: root.vertical ? 1 : Math.max(1, root.pinnedItems.length + 1)

        RippleButton {
            id: trayOverflowButton

            visible: root.unpinnedItems.length > 0
            toggled: root.trayOverflowOpen
            implicitWidth: Sizes.barControlCircleSize
            implicitHeight: Sizes.barControlCircleSize
            buttonRadius: Appearance.rounding.full
            containerColor: "transparent"
            stateLayerOpacity: Appearance.interaction.hoverStateLayerOpacity
            focusStateLayerOpacity: Appearance.interaction.focusStateLayerOpacity
            pressedStateLayerOpacity: Appearance.interaction.pressedStateLayerOpacity
            stateLayerColor: BarColors.foreground
            pressedStateLayerColor: BarColors.foreground
            rippleColor: BarColors.foreground
            Layout.alignment: Qt.AlignVCenter
            releaseAction: () => {
                if (root.trayOverflowOpen) {
                    root.trayOverflowOpen = false;
                    root.closeActiveMenu();
                    return;
                }

                root.closeActiveMenu();
                root.captureOverflowAnchor();
                root.updateOverflowPosition();
                root.trayOverflowOpen = true;
            }

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "expand_more"
                iconSize: Sizes.barIconSize
                color: root.trayOverflowOpen || trayOverflowButton.pointerHovered ? BarColors.selected :
                                                                                    BarColors.foreground
                rotation: (root.edge === "left" ? -90 : root.edge === "right" ? 90 : 0) + (
                              root.trayOverflowOpen ? 180 : 0)

                Behavior on rotation {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }
        }

        Repeater {
            model: root.pinnedItems

            delegate: TrayItem {
                screen: root.screen
                edge: root.edge
                barVisualItem: root.barVisualItem
                Layout.alignment: Qt.AlignVCenter
                onMenuOpened: window => root.setActiveMenu(window)
                onMenuClosed: root.releaseActiveMenu(null)
            }
        }
    }

    PanelWindow {
        id: overflowPopup

        visible: root.trayOverflowOpen && root.unpinnedItems.length > 0
        screen: root.screen
        color: "transparent"
        exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: root.QsWindow.window ? root.QsWindow.window.WlrLayershell.layer : WlrLayer.Top
        WlrLayershell.namespace: "clavis-shell-tray-overflow"
        WlrLayershell.keyboardFocus: overflowPopup.visible ? WlrKeyboardFocus.Exclusive :
                                                             WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        mask: Region {
            item: overflowInputRegion
        }

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => {
                    root.updateOverflowPosition();
                    overflowKeyScope.forceActiveFocus();
                });
        }

        Item {
            id: overflowInputRegion
            anchors.fill: parent
        }

        MouseArea {
            anchors.fill: parent
            enabled: overflowPopup.visible
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            z: -1

            onClicked: event => {
                const outsideMenu = event.x < overflowSurface.x || event.x > overflowSurface.x
                      + overflowSurface.width || event.y < overflowSurface.y || event.y > overflowSurface.y
                      + overflowSurface.height;
                if (outsideMenu) {
                    root.trayOverflowOpen = false;
                    root.closeActiveMenu();
                }
            }
        }

        FocusScope {
            id: overflowKeyScope

            anchors.fill: parent
            focus: overflowPopup.visible

            Keys.onEscapePressed: event => {
                root.trayOverflowOpen = false;
                root.closeActiveMenu();
                event.accepted = true;
            }

            Item {
                id: overflowSurface

                x: root.overflowX
                y: root.overflowY
                implicitWidth: popupBackground.implicitWidth + root.overflowSurfacePadding * 2
                implicitHeight: popupBackground.implicitHeight + root.overflowSurfacePadding * 2
                width: implicitWidth
                height: implicitHeight

                onImplicitWidthChanged: Qt.callLater(root.updateOverflowPosition)
                onImplicitHeightChanged: Qt.callLater(root.updateOverflowPosition)

                StyledRectangularShadow {
                    target: popupBackground
                    opacity: popupBackground.opacity
                }

                Rectangle {
                    id: popupBackground

                    readonly property real popupPadding: 4

                    x: root.overflowSurfacePadding
                    y: root.overflowSurfacePadding
                    implicitWidth: overflowLayout.implicitWidth + popupPadding * 2
                    implicitHeight: overflowLayout.implicitHeight + popupPadding * 2
                    color: BlurService.backgroundColor(Appearance.colors.colLayer0)
                    radius: 18
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true
                    opacity: overflowPopup.visible ? 1 : 0

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

                    GridLayout {
                        id: overflowLayout

                        anchors.centerIn: parent
                        columns: Math.max(1, Math.ceil(Math.sqrt(root.unpinnedItems.length)))
                        columnSpacing: 10
                        rowSpacing: 10

                        Repeater {
                            model: root.unpinnedItems

                            delegate: TrayItem {
                                screen: root.screen
                                edge: root.edge
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                onMenuOpened: window => root.setActiveMenu(window)
                                onMenuClosed: root.releaseActiveMenu(null)
                            }
                        }
                    }
                }
            }
        }

        CompositorBlurRegion {
            targetWindow: overflowPopup
            backgroundItem: popupBackground
        }
    }
}
