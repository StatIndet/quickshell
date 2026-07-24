import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property var model: []
    property string currentValue: ""
    property int buttonHeight: 36
    property int minimumWidth: 112
    property int maximumWidth: 172
    property int menuMinimumWidth: 190
    property int menuMaximumWidth: 260
    property string leadingIcon: ""
    readonly property int gap: 2
    readonly property int menuMargin: 12
    readonly property int menuPadding: 8
    readonly property int menuVerticalGap: 6
    readonly property int leadingLeftPadding: 10
    readonly property int leadingRightPadding: 8
    readonly property int trailingWidth: 34
    property color buttonColor: Appearance.colors.colPrimary
    property color buttonHoverColor: Appearance.colors.colPrimaryHover
    property color buttonPressedColor: Appearance.colors.colPrimaryActive
    property color buttonTextColor: Appearance.colors.colOnPrimary
    property color menuSurfaceColor:
        Appearance.m3colors.m3surfaceContainerHighest
    property real popupX: 0
    property real popupY: 0
    property real popupHeight: menuPreferredHeight
    readonly property Item popupParentItem: root.Window.window ? root.Window.window.contentItem : null

    signal valueSelected(string value)

    implicitWidth: Math.min(maximumWidth, Math.max(minimumWidth, labelMetrics.advanceWidth + leadingLeftPadding + leadingRightPadding + (leadingIcon !== "" ? 24 : 0) + gap + trailingWidth))
    implicitHeight: buttonHeight

    readonly property real menuPreferredWidth: Math.min(menuMaximumWidth, Math.max(menuMinimumWidth, menuLabelMetrics.advanceWidth + 64))
    readonly property real menuPreferredHeight: Math.max(menuPadding * 2, model.length * 48 + menuPadding * 2)

    function labelFor(value) {
        for (let i = 0; i < model.length; i += 1) {
            if (model[i].value === value)
                return model[i].label;
        }
        return value;
    }

    function longestLabel() {
        let longest = "";
        for (let i = 0; i < model.length; i += 1) {
            const label = model[i].label || model[i].value || "";
            if (String(label).length > longest.length)
                longest = String(label);
        }
        return longest;
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(value, maxValue));
    }

    function updatePopupGeometry() {
        const parentItem = root.popupParentItem;
        if (!parentItem || root.width <= 0 || root.height <= 0)
            return false;

        const origin = root.mapToItem(parentItem, root.width - root.menuPreferredWidth, 0);
        const minX = root.menuMargin;
        const maxX = Math.max(minX, parentItem.width - root.menuMargin - root.menuPreferredWidth);
        const below = root.mapToItem(parentItem, 0, root.height + root.menuVerticalGap).y;
        const minY = root.menuMargin;
        const availableBelow = parentItem.height - root.menuMargin - below;
        const nextHeight = Math.min(root.menuPreferredHeight, Math.max(96, availableBelow));
        const maxY = Math.max(minY, parentItem.height - root.menuMargin - nextHeight);

        root.popupX = root.clamp(origin.x, minX, maxX);
        root.popupY = root.clamp(below, minY, maxY);
        root.popupHeight = nextHeight;
        return true;
    }

    TextMetrics {
        id: labelMetrics

        font.family: Sizes.fontFamily
        font.pixelSize: 13
        font.weight: Font.Medium
        text: root.labelFor(root.currentValue)
    }

    TextMetrics {
        id: menuLabelMetrics

        font.family: Sizes.fontFamily
        font.pixelSize: 14
        font.weight: Font.Normal
        text: root.longestLabel()
    }

    function openMenu() {
        if (!optionsPopup.visible && root.updatePopupGeometry()) {
            optionsPopup.open();
            Qt.callLater(root.updatePopupGeometry);
        }
    }

    function toggleMenu() {
        if (optionsPopup.visible)
            optionsPopup.close();
        else
            root.openMenu();
    }

    onXChanged: if (optionsPopup.visible) root.updatePopupGeometry()
    onYChanged: if (optionsPopup.visible) root.updatePopupGeometry()
    onWidthChanged: if (optionsPopup.visible) root.updatePopupGeometry()
    onHeightChanged: if (optionsPopup.visible) root.updatePopupGeometry()

    Connections {
        target: root.Window.window

        function onWidthChanged() {
            if (optionsPopup.visible)
                root.updatePopupGeometry();
        }

        function onHeightChanged() {
            if (optionsPopup.visible)
                root.updatePopupGeometry();
        }

        function onVisibleChanged() {
            if (!root.Window.window.visible)
                optionsPopup.close();
            else if (optionsPopup.visible)
                root.updatePopupGeometry();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: root.gap

        Item {
            id: leadingButton

            Layout.fillWidth: true
            Layout.fillHeight: true

            property bool pressed: leadingMouse.pressed
            property bool hovered: leadingMouse.containsMouse
            property real innerRadius: (pressed || hovered || optionsPopup.visible) ? Appearance.rounding.small : Appearance.rounding.extraSmall
            property color fillColor: pressed ? root.buttonPressedColor : hovered ? root.buttonHoverColor : root.buttonColor

            Rectangle {
                anchors.fill: parent
                topLeftRadius: root.buttonHeight / 2
                bottomLeftRadius: root.buttonHeight / 2
                topRightRadius: leadingButton.innerRadius
                bottomRightRadius: leadingButton.innerRadius
                color: leadingButton.fillColor

                Behavior on topRightRadius {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                Behavior on bottomRightRadius {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
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

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.leadingLeftPadding
                anchors.rightMargin: root.leadingRightPadding
                spacing: 6

                MaterialSymbol {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    text: root.leadingIcon
                    iconSize: 18
                    fill: 1
                    color: root.buttonTextColor
                    visible: root.leadingIcon !== ""
                }

                Text {
                    Layout.fillWidth: true
                    text: root.labelFor(root.currentValue)
                    color: root.buttonTextColor
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MouseArea {
                id: leadingMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMenu()
            }
        }

        Item {
            id: trailingButton

            Layout.preferredWidth: root.trailingWidth
            Layout.fillHeight: true

            property bool pressed: trailingMouse.pressed
            property bool hovered: trailingMouse.containsMouse
            property real innerRadius: optionsPopup.visible ? (root.buttonHeight / 2) : (pressed || hovered ? Appearance.rounding.small : Appearance.rounding.extraSmall)
            property color fillColor: pressed ? root.buttonPressedColor : hovered ? root.buttonHoverColor : root.buttonColor

            Rectangle {
                anchors.fill: parent
                topLeftRadius: trailingButton.innerRadius
                bottomLeftRadius: trailingButton.innerRadius
                topRightRadius: root.buttonHeight / 2
                bottomRightRadius: root.buttonHeight / 2
                color: trailingButton.fillColor

                Behavior on topLeftRadius {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                Behavior on bottomLeftRadius {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
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

            MaterialSymbol {
                id: arrowIcon

                anchors.centerIn: parent
                text: "expand_more"
                iconSize: 20
                color: root.buttonTextColor
                rotation: optionsPopup.visible ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }
            }

            MouseArea {
                id: trailingMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleMenu()
            }
        }
    }

    Popup {
        id: optionsPopup

        parent: root.popupParentItem
        x: root.popupX
        y: root.popupY
        width: root.menuPreferredWidth
        height: root.popupHeight
        padding: root.menuPadding
        modal: true
        dim: false
        focus: true
        clip: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAboutToShow: root.updatePopupGeometry()
        onOpened: Qt.callLater(root.updatePopupGeometry)

        background: Rectangle {
            radius: Appearance.rounding.small
            color: root.menuSurfaceColor
            border.width: 1
            border.color: Appearance.m3colors.m3outlineVariant
        }

        contentItem: StyledListView {
            id: menuList

            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            model: root.model
            interactive: contentHeight > height
            animateAppearance: false
            animateMovement: false
            showVerticalScrollBar: root.menuPreferredHeight > optionsPopup.height

            delegate: Item {
                id: option

                required property var modelData

                property bool selected: root.currentValue === modelData.value
                property bool pressed: optionMouse.pressed
                property bool hovered: optionMouse.containsMouse
                property color itemColor: selected
                                          ? Appearance.m3colors.m3secondaryContainer
                                          : pressed
                                            ? Appearance.mix(root.menuSurfaceColor, Appearance.m3colors.m3onSurface, 0.82)
                                            : hovered
                                              ? Appearance.mix(root.menuSurfaceColor, Appearance.m3colors.m3onSurface, 0.92)
                                              : root.menuSurfaceColor

                width: ListView.view.width
                height: 48

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.extraSmall
                    color: option.itemColor

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        MaterialSymbol {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            text: option.selected ? "check" : ""
                            iconSize: 20
                            color: Appearance.m3colors.m3onSecondaryContainer
                        }

                        Text {
                            Layout.fillWidth: true
                            text: option.modelData.label
                            color: option.selected ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurface
                            font.family: Sizes.fontFamily
                            font.pixelSize: 14
                            font.weight: option.selected ? Font.Medium : Font.Normal
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueSelected(option.modelData.value);
                        optionsPopup.close();
                    }
                }
            }
        }
    }
}
