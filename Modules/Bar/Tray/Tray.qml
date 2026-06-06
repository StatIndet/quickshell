import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property bool trayOverflowOpen: false
    property var activeMenu: null
    property var screen: null
    property real overflowX: 10
    property real overflowY: 10
    property real overflowEdgeMargin: 10
    property real overflowAnchorGap: 4
    property real overflowAnchorX: 10
    property real overflowAnchorY: 10
    property real overflowAnchorWidth: 0
    property real overflowAnchorHeight: 0
    property bool overflowAnchorReady: false
    readonly property var pinnedItems: TrayService.pinnedItems
    readonly property var unpinnedItems: TrayService.unpinnedItems

    implicitHeight: 36
    implicitWidth: content.implicitWidth + 24

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

    function updateOverflowPosition() {
        const surfaceWidth = Math.max(1, overflowSurface.implicitWidth);
        const surfaceHeight = Math.max(1, overflowSurface.implicitHeight);
        const screenWidth = root.screen ? (root.screen.width || 0) : 0;
        const screenHeight = root.screen ? (root.screen.height || 0) : 0;
        const availableWidth = Math.max(surfaceWidth + root.overflowEdgeMargin * 2, overflowPopup.width, screenWidth);
        const availableHeight = Math.max(surfaceHeight + root.overflowEdgeMargin * 2, overflowPopup.height, screenHeight);
        const anchorX = root.overflowAnchorReady ? root.overflowAnchorX : root.overflowEdgeMargin;
        const anchorY = root.overflowAnchorReady ? root.overflowAnchorY : root.overflowEdgeMargin;
        const anchorWidth = root.overflowAnchorReady ? root.overflowAnchorWidth : 0;
        const anchorHeight = root.overflowAnchorReady ? root.overflowAnchorHeight : 0;

        root.overflowX = root.clamp(
            anchorX + anchorWidth / 2 - surfaceWidth / 2,
            root.overflowEdgeMargin,
            availableWidth - surfaceWidth - root.overflowEdgeMargin
        );

        const belowY = anchorY + anchorHeight + root.overflowAnchorGap;
        const aboveY = anchorY - surfaceHeight - root.overflowAnchorGap;
        const maxY = availableHeight - surfaceHeight - root.overflowEdgeMargin;
        root.overflowY = belowY <= maxY || aboveY < root.overflowEdgeMargin
            ? root.clamp(belowY, root.overflowEdgeMargin, maxY)
            : root.clamp(aboveY, root.overflowEdgeMargin, maxY);
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

    Rectangle {
        id: bgRect

        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: height / 2
        visible: false
    }

    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Appearance.applyAlpha(Appearance.colors.colShadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: 15

        MaterialRippleButton {
            id: trayOverflowButton

            visible: root.unpinnedItems.length > 0
            toggled: root.trayOverflowOpen
            implicitWidth: 24
            implicitHeight: 24
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.transparentize(Appearance.colors.colLayer0, 1)
            colBackgroundHover: Appearance.colors.colSecondaryContainer
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive
            colRippleToggled: Appearance.colors.colSecondaryContainerActive
            rippleEnabled: false
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
                iconSize: 19
                color: root.trayOverflowOpen || trayOverflowButton.pointerHovered
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnLayer0
                rotation: root.trayOverflowOpen ? 180 : 0

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

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "clavis-tray-overflow"
        WlrLayershell.keyboardFocus: overflowPopup.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        mask: Region { item: overflowInputRegion }

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
                const outsideMenu = event.x < overflowSurface.x
                    || event.x > overflowSurface.x + overflowSurface.width
                    || event.y < overflowSurface.y
                    || event.y > overflowSurface.y + overflowSurface.height;
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
                implicitWidth: popupBackground.implicitWidth + 20
                implicitHeight: popupBackground.implicitHeight + 20
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

                    x: 10
                    y: 10
                    implicitWidth: overflowLayout.implicitWidth + popupPadding * 2
                    implicitHeight: overflowLayout.implicitHeight + popupPadding * 2
                    color: Appearance.colors.colLayer0
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
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                onMenuOpened: window => root.setActiveMenu(window)
                                onMenuClosed: root.releaseActiveMenu(null)
                            }
                        }
                    }
                }
            }
        }
    }
}
