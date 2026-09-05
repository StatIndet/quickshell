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
    property int maxVisibleItems: 10
    property string textRole: "label"
    property string valueRole: "value"
    property string enabledRole: "enabled"
    property string tooltipRole: "tooltip"
    property bool closeOnAccept: false
    property bool showCheckmark: true
    property bool showActiveIndicator: true
    property Component leadingDelegate
    property real leadingWidth: Metrics.iconM
    property real fieldHeight: 40
    property real itemHeight: 40
    property Item popupBoundsItem: null

    property int highlightedIndex: -1
    readonly property string visualSelectedValue: hasPendingAccepted ? pendingAcceptedValue : value
    readonly property string currentText: labelFor(visualSelectedValue)
    readonly property string displayText: currentText !== "" ? currentText : placeholder
    readonly property bool showingPlaceholder: currentText === "" && placeholder !== ""
    readonly property color menuSurfaceColor: Appearance.m3colors.m3surfaceContainerHigh
    readonly property color menuHoverColor: Appearance.m3colors.m3surfaceContainerHighest
    readonly property real menuGap: 6
    readonly property real menuPadding: 6
    readonly property real listTargetHeight: Math.min(
        Math.max(1, maxVisibleItems) * itemHeight,
        Math.max(itemHeight, options.length * itemHeight)
    )
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

    function optionEnabled(option) {
        if (!hasRole(option, enabledRole))
            return true;
        return option[enabledRole] !== false;
    }

    function optionTooltip(option) {
        return roleText(option, tooltipRole);
    }

    function labelFor(currentValue) {
        for (let i = 0; i < options.length; i += 1) {
            if (optionValue(options[i]) === currentValue)
                return optionText(options[i]);
        }
        return currentValue;
    }

    function optionForValue(currentValue) {
        for (let i = 0; i < options.length; i += 1) {
            if (optionValue(options[i]) === currentValue)
                return options[i];
        }
        return null;
    }

    function selectedIndexInOptions() {
        for (let i = 0; i < options.length; i += 1) {
            if (optionValue(options[i]) === visualSelectedValue)
                return i;
        }
        return options.length > 0 ? 0 : -1;
    }

    function ensureHighlightedVisible() {
        if (highlightedIndex < 0 || highlightedIndex >= options.length)
            return;
        menuList.positionViewAtIndex(highlightedIndex, ListView.Contain);
    }

    function updatePopupGeometry() {
        if (!popupParentItem)
            return false;

        const boundsItem = popupBoundsItem || popupParentItem;
        const boundsOrigin = boundsItem.mapToItem(popupParentItem, 0, 0);
        const edgeMargin = 12;
        const boundsLeft = boundsOrigin.x + edgeMargin;
        const boundsTop = boundsOrigin.y + edgeMargin;
        const boundsRight = boundsOrigin.x + boundsItem.width - edgeMargin;
        const boundsBottom = boundsOrigin.y + boundsItem.height - edgeMargin;
        const availableWidth = Math.max(0, boundsRight - boundsLeft);
        const availableHeight = Math.max(0, boundsBottom - boundsTop);
        if (availableWidth <= 0 || availableHeight <= menuPadding * 2)
            return false;

        const naturalHeight = menuPadding * 2 + listTargetHeight;
        optionsPopup.width = Math.min(width, availableWidth);
        optionsPopup.height = Math.min(naturalHeight, availableHeight);
        optionsPopup.effectiveListHeight = Math.max(
            0, optionsPopup.height - menuPadding * 2);

        const belowOrigin = fieldFrame.mapToItem(popupParentItem, 0, height + menuGap);
        const aboveOrigin = fieldFrame.mapToItem(popupParentItem, 0, -optionsPopup.height - menuGap);
        const maxX = boundsRight - optionsPopup.width;
        optionsPopup.x = Math.max(boundsLeft, Math.min(belowOrigin.x, maxX));

        if (belowOrigin.y + optionsPopup.height <= boundsBottom)
            optionsPopup.y = belowOrigin.y;
        else if (aboveOrigin.y >= boundsTop)
            optionsPopup.y = aboveOrigin.y;
        else
            optionsPopup.y = Math.max(boundsTop, Math.min(belowOrigin.y, boundsBottom - optionsPopup.height));
        return true;
    }

    function openMenu() {
        if (expanded)
            return;

        hasPendingAccepted = false;
        highlightedIndex = selectedIndexInOptions();
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
        if (options.length === 0) {
            highlightedIndex = -1;
            return;
        }

        let nextIndex = highlightedIndex < 0
            ? (delta >= 0 ? 0 : options.length - 1)
            : (highlightedIndex + delta + options.length) % options.length;

        for (let attempts = 0; attempts < options.length;
                attempts += 1) {
            if (optionEnabled(options[nextIndex])) {
                highlightedIndex = nextIndex;
                ensureHighlightedVisible();
                return;
            }
            nextIndex = (nextIndex + (delta >= 0 ? 1 : -1)
                + options.length) % options.length;
        }

        highlightedIndex = -1;
    }

    function moveHighlightToBoundary(first) {
        if (options.length === 0) {
            highlightedIndex = -1;
            return;
        }

        let nextIndex = first ? 0 : options.length - 1;
        for (let attempts = 0; attempts < options.length;
                attempts += 1) {
            if (optionEnabled(options[nextIndex])) {
                highlightedIndex = nextIndex;
                ensureHighlightedVisible();
                return;
            }
            nextIndex = (nextIndex + (first ? 1 : -1) + options.length)
                % options.length;
        }
        highlightedIndex = -1;
    }

    function handleMenuKey(event) {
        if (!root.expanded)
            return false;

        if (event.key === Qt.Key_Escape) {
            root.closeMenu();
        } else if (event.key === Qt.Key_Down) {
            root.moveHighlight(1);
        } else if (event.key === Qt.Key_Up) {
            root.moveHighlight(-1);
        } else if (event.key === Qt.Key_Home) {
            root.moveHighlightToBoundary(true);
        } else if (event.key === Qt.Key_End) {
            root.moveHighlightToBoundary(false);
        } else if (event.key === Qt.Key_Return
                   || event.key === Qt.Key_Enter
                   || event.key === Qt.Key_Space) {
            root.acceptHighlighted();
        } else {
            return false;
        }

        event.accepted = true;
        return true;
    }

    function acceptHighlighted() {
        if (highlightedIndex < 0 || highlightedIndex >= options.length)
            return;
        acceptOption(options[highlightedIndex]);
    }

    function acceptOption(option) {
        if (!optionEnabled(option))
            return;
        const acceptedValue = optionValue(option);
        hasPendingAccepted = true;
        pendingAcceptedValue = acceptedValue;
        highlightedIndex = selectedIndexInOptions();
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
                ensureHighlightedVisible();
            });
        } else {
            closeDelay.stop();
            hasPendingAccepted = false;
            if (optionsPopup.visible)
                optionsPopup.close();
            root.forceActiveFocus();
        }
    }

    onOptionsChanged: {
        if (!expanded)
            return;
        highlightedIndex = selectedIndexInOptions();
        updatePopupGeometry();
        ensureHighlightedVisible();
    }

    Keys.onPressed: event => {
        if (root.expanded) {
            root.handleMenuKey(event);
        } else if (event.key === Qt.Key_Return
                   || event.key === Qt.Key_Enter
                   || event.key === Qt.Key_Space
                   || event.key === Qt.Key_Down) {
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

            anchors.left: currentLeadingLoader.active
                ? currentLeadingLoader.right : parent.left
            anchors.right: arrowIcon.left
            anchors.leftMargin: currentLeadingLoader.active ? 10 : 14
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: true
            text: root.displayText
            color: root.showingPlaceholder ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2
            font.family: Fonts.ui
            font.pixelSize: 14
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Loader {
            id: currentLeadingLoader

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: active ? root.leadingWidth : 0
            height: active ? root.leadingWidth : 0
            active: root.leadingDelegate !== null
                && root.optionForValue(root.visualSelectedValue) !== null
            sourceComponent: root.leadingDelegate
            onLoaded: {
                if (item && "optionData" in item)
                    item.optionData = root.optionForValue(
                        root.visualSelectedValue);
            }
        }

        Connections {
            target: root

            function onVisualSelectedValueChanged() {
                if (currentLeadingLoader.item
                        && "optionData" in currentLeadingLoader.item) {
                    currentLeadingLoader.item.optionData
                        = root.optionForValue(root.visualSelectedValue);
                }
            }
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
        property real effectiveListHeight: root.listTargetHeight

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
        onOpened: Qt.callLater(() => {
            root.updatePopupGeometry();
            popupContent.forceActiveFocus();
        })
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
                duration: Appearance.animation.standardDecel.duration
                easing.type: Appearance.animation.standardDecel.type
                easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
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
                duration: Appearance.animation.standardDecel.duration
                easing.type: Appearance.animation.standardDecel.type
                easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
            }
        }

        background: Item {
        }

        contentItem: FocusScope {
            id: popupContent

            focus: optionsPopup.visible
            implicitWidth: optionsPopup.width
            implicitHeight: optionsPopup.height

            Keys.onPressed: event => {
                root.handleMenuKey(event);
            }

            Item {
                id: maskedSurface

                width: parent.width
                height: root.menuPadding * 2
                    + optionsPopup.effectiveListHeight
                        * optionsPopup.revealProgress
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
                    height: optionsPopup.effectiveListHeight * optionsPopup.revealProgress
                    clip: true

                    StyledListView {
                        id: menuList

                        width: parent.width
                        height: optionsPopup.effectiveListHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.options
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
                            readonly property bool itemEnabled: root.optionEnabled(modelData)
                            readonly property bool selected: itemValue === root.visualSelectedValue
                            readonly property bool highlighted: index === root.highlightedIndex
                            readonly property string tooltipText: root.optionTooltip(modelData)

                            width: ListView.view.width
                            height: root.itemHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: optionItem.selected && optionItem.itemEnabled
                                       ? Appearance.colors.colPrimaryContainer
                                       : optionItem.highlighted
                                         ? root.menuHoverColor
                                         : root.menuSurfaceColor
                                opacity: optionItem.itemEnabled ? 1 : 0.5

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
                                    scale: optionItem.selected && optionItem.itemEnabled
                                        && root.showCheckmark ? 1 : 0
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
                                        opacity: optionItem.selected
                                            && optionItem.itemEnabled ? 1 : 0
                                        scale: optionItem.selected
                                            && optionItem.itemEnabled ? 1 : 0.6

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

                                Loader {
                                    id: optionLeadingLoader

                                    x: optionItem.selected && root.showCheckmark ? 30 : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: active ? root.leadingWidth : 0
                                    height: active ? root.leadingWidth : 0
                                    active: root.leadingDelegate !== null
                                    sourceComponent: root.leadingDelegate
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Appearance.animation.expressiveFastSpatial.duration
                                            easing.type: Appearance.animation.expressiveFastSpatial.type
                                            easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                                        }
                                    }
                                    onLoaded: {
                                        if (item && "optionData" in item)
                                            item.optionData = optionItem.modelData;
                                    }
                                }

                                Text {
                                    x: (optionItem.selected && root.showCheckmark ? 32 : 0)
                                        + (optionLeadingLoader.active
                                            ? root.leadingWidth + 10 : 0)
                                    width: parent.width - x
                                    height: parent.height
                                    text: optionItem.itemText
                                    color: optionItem.selected
                                        && optionItem.itemEnabled
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnLayer3
                                    font.family: Fonts.ui
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
                                enabled: optionItem.itemEnabled
                                cursorShape: enabled
                                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: root.highlightedIndex = optionItem.index
                                onClicked: root.acceptOption(optionItem.modelData)
                            }

                            HoverHandler {
                                id: optionHover
                                enabled: optionItem.tooltipText !== ""
                            }

                            StyledToolTip {
                                extraVisibleCondition: optionHover.hovered
                                    && optionItem.tooltipText !== ""
                                text: optionItem.tooltipText
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
                        visible: root.options.length === 0
                        text: qsTr("暂无可用选项")
                        color: Appearance.colors.colSubtext
                        font.family: Fonts.ui
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
