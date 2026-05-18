import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components

FocusScope {
    id: root

    property var options: []
    property string value: ""
    property string placeholder: ""
    property bool expanded: false
    property int maxVisibleItems: 6
    property string noResultText: "无匹配结果"
    property string textRole: "label"
    property string valueRole: "value"
    property bool closeOnAccept: false
    property bool showCheckmark: true
    property bool showActiveIndicator: true
    property real fieldHeight: 40
    property real itemHeight: 40

    property int highlightedIndex: -1
    readonly property var filteredOptions: options
    readonly property string visualSelectedValue: hasPendingAccepted ? pendingAcceptedValue : value
    readonly property string currentText: labelFor(visualSelectedValue)
    readonly property string displayText: currentText !== "" ? currentText : placeholder
    readonly property bool showingPlaceholder: currentText === "" && placeholder !== ""
    readonly property color menuSurfaceColor: Appearance.m3colors.m3surfaceContainerHigh
    readonly property color menuHoverColor: Appearance.m3colors.m3surfaceContainerHighest
    readonly property real menuGap: 6
    readonly property real menuPadding: 6
    readonly property real listTargetHeight: Math.min(Math.max(1, maxVisibleItems) * itemHeight, Math.max(itemHeight, filteredOptions.length * itemHeight))
    readonly property Item popupParentItem: root.Window.window ? root.Window.window.contentItem : null

    property bool hasPendingAccepted: false
    property string pendingAcceptedValue: ""

    signal accepted(string value)

    implicitWidth: 240
    implicitHeight: fieldHeight
    activeFocusOnTab: true

    function isObject(option) {
        return option !== null && typeof option === "object";
    }

    function hasRole(option, role) {
        return isObject(option) && role !== "" && option[role] !== undefined && option[role] !== null;
    }

    function roleText(option, role) {
        if (!hasRole(option, role))
            return "";
        return String(option[role]);
    }

    function optionText(option) {
        if (isObject(option)) {
            const explicitText = roleText(option, textRole);
            if (explicitText !== "")
                return explicitText;
            const label = roleText(option, "label");
            if (label !== "")
                return label;
            const optionValue = roleText(option, valueRole);
            if (optionValue !== "")
                return optionValue;
        }
        return option === undefined || option === null ? "" : String(option);
    }

    function optionValue(option) {
        if (isObject(option)) {
            if (hasRole(option, valueRole))
                return String(option[valueRole]);
            return optionText(option);
        }
        return option === undefined || option === null ? "" : String(option);
    }

    function labelFor(currentValue) {
        for (let i = 0; i < options.length; i += 1) {
            if (optionValue(options[i]) === currentValue)
                return optionText(options[i]);
        }
        return currentValue;
    }

    function selectedIndexInFiltered() {
        for (let i = 0; i < filteredOptions.length; i += 1) {
            if (optionValue(filteredOptions[i]) === visualSelectedValue)
                return i;
        }
        return filteredOptions.length > 0 ? 0 : -1;
    }

    function updatePopupGeometry() {
        if (!popupParentItem)
            return false;

        const origin = fieldFrame.mapToItem(popupParentItem, 0, height + menuGap);
        optionsPopup.width = Math.min(width, popupParentItem.width - 24);
        optionsPopup.height = menuPadding * 2 + listTargetHeight;
        optionsPopup.x = Math.max(12, Math.min(origin.x, popupParentItem.width - optionsPopup.width - 12));
        optionsPopup.y = Math.max(12, Math.min(origin.y, popupParentItem.height - optionsPopup.height - 12));
        return true;
    }

    function openMenu() {
        if (expanded)
            return;

        hasPendingAccepted = false;
        highlightedIndex = selectedIndexInFiltered();
        if (updatePopupGeometry())
            expanded = true;
    }

    function closeMenu() {
        expanded = false;
    }

    function toggleMenu() {
        if (expanded)
            closeMenu();
        else
            openMenu();
    }

    function moveHighlight(delta) {
        if (filteredOptions.length === 0) {
            highlightedIndex = -1;
            return;
        }

        const nextIndex = highlightedIndex < 0 ? 0 : (highlightedIndex + delta + filteredOptions.length) % filteredOptions.length;
        highlightedIndex = nextIndex;
        menuList.positionViewAtIndex(highlightedIndex, ListView.Contain);
    }

    function acceptHighlighted() {
        if (highlightedIndex < 0 || highlightedIndex >= filteredOptions.length)
            return;
        acceptOption(filteredOptions[highlightedIndex]);
    }

    function acceptOption(option) {
        const acceptedValue = optionValue(option);
        hasPendingAccepted = true;
        pendingAcceptedValue = acceptedValue;
        highlightedIndex = selectedIndexInFiltered();
        accepted(acceptedValue);
        if (closeOnAccept)
            closeDelay.restart();
    }

    onExpandedChanged: {
        if (expanded) {
            updatePopupGeometry();
            optionsPopup.open();
            Qt.callLater(() => {
                updatePopupGeometry();
                root.forceActiveFocus();
            });
        } else {
            closeDelay.stop();
            hasPendingAccepted = false;
            if (optionsPopup.visible)
                optionsPopup.close();
            root.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.expanded) {
            root.closeMenu();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) && !root.expanded) {
            root.openMenu();
            event.accepted = true;
        }
    }

    Rectangle {
        id: fieldFrame

        anchors.fill: parent
        radius: 0
        color: root.expanded
               ? Appearance.colors.colLayer2Active
               : fieldMouse.pressed
                 ? Appearance.colors.colLayer2Active
                 : fieldMouse.containsMouse
                   ? Appearance.colors.colLayer2Hover
                   : Appearance.colors.colLayer2
        clip: true

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }

        Text {
            id: displayLabel

            anchors.left: parent.left
            anchors.right: arrowIcon.left
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: true
            text: root.displayText
            color: root.showingPlaceholder ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2
            font.family: Sizes.fontFamily
            font.pixelSize: 14
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        MaterialSymbol {
            id: arrowIcon

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "expand_more"
            iconSize: 20
            color: Appearance.colors.colOnLayer2
            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastSpatial.duration
                    easing.type: Appearance.animation.expressiveFastSpatial.type
                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: !root.showActiveIndicator ? 0 : root.expanded ? 2 : 1
            color: root.expanded ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
            visible: root.showActiveIndicator

            Behavior on height {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }
            }
        }

        MouseArea {
            id: fieldMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.forceActiveFocus();
                root.toggleMenu();
            }
        }
    }

    Timer {
        id: closeDelay

        interval: 150
        onTriggered: root.closeMenu()
    }

    Popup {
        id: optionsPopup

        property real revealProgress: 0

        parent: root.popupParentItem
        padding: 0
        modal: true
        dim: false
        focus: true
        clip: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAboutToShow: {
            revealProgress = 0;
            root.updatePopupGeometry();
            Qt.callLater(() => revealProgress = 1);
        }
        onOpened: Qt.callLater(root.updatePopupGeometry)
        onAboutToHide: revealProgress = 0
        onClosed: {
            if (root.expanded)
                root.expanded = false;
            root.hasPendingAccepted = false;
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.animation.standardDecel.duration
                easing.type: Appearance.animation.standardDecel.type
                easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
            }
            NumberAnimation {
                property: "y"
                from: optionsPopup.y - 4
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
            NumberAnimation {
                property: "y"
                to: optionsPopup.y - 4
                duration: Appearance.animation.expressiveFastEffects.duration
                easing.type: Appearance.animation.expressiveFastEffects.type
                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
            }
        }

        Behavior on revealProgress {
            NumberAnimation {
                duration: Appearance.animation.expressiveFastSpatial.duration
                easing.type: Appearance.animation.expressiveFastSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
            }
        }

        background: Item {
        }

        contentItem: Item {
            implicitWidth: optionsPopup.width
            implicitHeight: optionsPopup.height

            Item {
                id: maskedSurface

                width: parent.width
                height: root.menuPadding * 2 + root.listTargetHeight * optionsPopup.revealProgress
                visible: height > 0
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: maskedSurface.width
                        height: maskedSurface.height
                        radius: Appearance.rounding.normal
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: root.menuSurfaceColor
                }

                Item {
                    id: revealClip

                    x: root.menuPadding
                    y: root.menuPadding
                    width: parent.width - root.menuPadding * 2
                    height: root.listTargetHeight * optionsPopup.revealProgress
                    clip: true

                    StyledListView {
                        id: menuList

                        width: parent.width
                        height: root.listTargetHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.filteredOptions
                        interactive: contentHeight > height
                        currentIndex: root.highlightedIndex
                        animateAppearance: false
                        animateMovement: false

                        delegate: Item {
                            id: optionItem

                            required property var modelData
                            required property int index

                            readonly property string itemText: root.optionText(modelData)
                            readonly property string itemValue: root.optionValue(modelData)
                            readonly property bool selected: itemValue === root.visualSelectedValue
                            readonly property bool highlighted: index === root.highlightedIndex

                            width: ListView.view.width
                            height: root.itemHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: optionItem.selected
                                       ? Appearance.colors.colPrimaryContainer
                                       : optionItem.highlighted
                                         ? root.menuHoverColor
                                         : root.menuSurfaceColor

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.animation.expressiveFastEffects.duration
                                        easing.type: Appearance.animation.expressiveFastEffects.type
                                        easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                                    }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12 + Appearance.scrollBar.width + Appearance.scrollBar.margin

                                Item {
                                    id: checkSlot

                                    width: 22
                                    height: parent.height
                                    scale: optionItem.selected && root.showCheckmark ? 1 : 0
                                    transformOrigin: Item.Left

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Appearance.animation.clickBounce.duration
                                            easing.type: Appearance.animation.clickBounce.type
                                            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
                                        }
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: 19
                                        fill: 1
                                        color: Appearance.colors.colOnPrimaryContainer
                                        visible: root.showCheckmark
                                        opacity: optionItem.selected ? 1 : 0
                                        scale: optionItem.selected ? 1 : 0.6

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Appearance.animation.expressiveFastEffects.duration
                                                easing.type: Appearance.animation.expressiveFastEffects.type
                                                easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                                            }
                                        }

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Appearance.animation.clickBounce.duration
                                                easing.type: Appearance.animation.clickBounce.type
                                                easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
                                            }
                                        }
                                    }
                                }

                                Text {
                                    x: optionItem.selected && root.showCheckmark ? 32 : 0
                                    width: parent.width - x
                                    height: parent.height
                                    text: optionItem.itemText
                                    color: optionItem.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: 14
                                    font.weight: optionItem.selected ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Appearance.animation.expressiveFastSpatial.duration
                                            easing.type: Appearance.animation.expressiveFastSpatial.type
                                            easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                                        }
                                    }

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Appearance.animation.expressiveFastEffects.duration
                                            easing.type: Appearance.animation.expressiveFastEffects.type
                                            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.highlightedIndex = optionItem.index
                                onClicked: root.acceptOption(optionItem.modelData)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        height: root.itemHeight
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        visible: root.filteredOptions.length === 0
                        text: root.noResultText
                        color: Appearance.colors.colSubtext
                        font.family: Sizes.fontFamily
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                    }
                }
            }

        }
    }
}
