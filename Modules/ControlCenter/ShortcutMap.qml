pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets.common
import "../../Common/NiriActionNames.js" as ActionNames

PanelWindow {
    id: root

    signal dismissed
    property var targetScreen: null
    screen: targetScreen
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    color: "transparent"
    WlrLayershell.namespace: "clavis-shell-shortcut-map"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var entries: {
        const names = {};
        NiriConfigService.actionCatalog.forEach(action => names[action.expression + ";"]
                                                          = ActionNames.translated(action.name));
        return NiriConfigService.bindings.map(binding => ({
            key: binding.key,
            name: binding.props["hotkey-overlay-title"] || names[binding.group] || root.actionName(
                binding.action),
            effective: binding.effective
        }));
    }

        function actionName(expression) {
        const command = expression.split(/\s/)[0];
        const entry = NiriConfigService.actionCatalog.find(action => action.category === "niri"
        && action.expression.split(/\s/)[0] === command);
        if (entry) {
        const argumentsText = expression.substring(command.length).replace(/;\s*$/, "").trim();
        return argumentsText ? qsTr("%1: %2").arg(ActionNames.translated(entry.name)).arg(argumentsText) :
        ActionNames.translated(entry.name);
    }
        const program = expression.match(/^spawn\s+"([^"]+)"/);
        return program ? qsTr("Run %1").arg(program[1].split("/").pop()) : expression;
    }

        function keys(value) {
        const aliases = {
        space: "Space",
        return: "Enter",
        escape: "Esc",
        left: "←",
        right: "→",
        up: "↑",
        down: "↓",
        comma: ",",
        period: ".",
        minus: "−",
        equal: "=",
        page_up: "PgUp",
        page_down: "PgDn"
    };
        return value.split("+").map(key => {
        if (key.toLowerCase() === "mod")
        return NiriConfigService.snapshot.modKey || "Super";
        return aliases[key.toLowerCase()] || key;
    });
    }

        MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

        Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(16, Math.min(root.width, root.height) * 0.045)
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainerLow
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        MouseArea {
        anchors.fill: parent
    }

        ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingL
        spacing: Metrics.spacingL
        Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        Text {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 96)
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("Shortcut map")
        color: Appearance.colors.colOnSurface
        font.family: Fonts.ui
        font.pixelSize: 28
        font.weight: Font.Bold
        elide: Text.ElideRight
    }
        IconButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconName: "close"
        accessibleName: qsTr("Close")
        onClicked: root.dismissed()
    }
    }
        InlineStatusBanner {
        Layout.fillWidth: true
        visible: NiriConfigService.error.length > 0
        message: NiriConfigService.error
        tone: "error"
    }
        Text {
        visible: root.entries.length === 0
        text: qsTr("No shortcuts assigned")
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Fonts.ui
    }
        ListView {
        id: pages
        Layout.fillWidth: true
        Layout.fillHeight: true
        orientation: ListView.Horizontal
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property int columnCount: Math.ceil(root.entries.length / rows)
        readonly property int rows: Math.max(1, Math.floor((height - 20) / 48))
        readonly property int columnWidth: 520
        model: columnCount
        spacing: 32
        ScrollBar.horizontal: ScrollBar {
        policy: ScrollBar.AsNeeded
    }
        focus: true
        Keys.onEscapePressed: root.dismissed()
        Keys.onRightPressed: contentX = Math.min(Math.max(0, contentWidth - width), contentX + width)
        Keys.onLeftPressed: contentX = Math.max(0, contentX - width)
        MouseArea {
        // Keep wheel interception on the viewport, outside the scrolling contentItem.
        parent: pages
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        onWheel: event => {
        const delta = event.pixelDelta.x || event.pixelDelta.y || event.angleDelta.x || event.angleDelta.y;
        pages.contentX = Math.max(0, Math.min(Math.max(0, pages.contentWidth - pages.width), pages.contentX
        - delta));
        event.accepted = true;
    }
    }
        delegate: Item {
        id: page
        required property int index
        width: pages.columnWidth
        height: pages.height
        Grid {
        columns: 1
        columnSpacing: 24
        rowSpacing: 8
        Repeater {
        model: Array.from({
        length: pages.rows
    }, (_, row) => root.entries[row * pages.columnCount + page.index]).filter(entry => entry !== undefined)
        delegate: RowLayout {
        id: entryCell
        required property var modelData
        width: pages.columnWidth
        height: 40
        spacing: 16
        Flickable {
        Layout.preferredWidth: entryCell.width * 0.48
        Layout.preferredHeight: 28
        contentWidth: keyRow.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Row {
        id: keyRow
        spacing: 4
        Repeater {
        model: root.keys(entryCell.modelData.key)
        delegate: Row {
        required property string modelData
        required property int index
        spacing: 4
        Text {
        visible: parent.index > 0
        text: "+"
        height: 26
        verticalAlignment: Text.AlignVCenter
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Fonts.mono
        font.pixelSize: 13
    }
        ShortcutKeycap {
        keyText: parent.modelData
    }
    }
    }
    }
    }
        Text {
        Layout.fillWidth: true
        text: entryCell.modelData.effective ? entryCell.modelData.name : qsTr("%1 (inactive)").arg(
        entryCell.modelData.name)
        color: entryCell.modelData.effective ? Appearance.colors.colOnSurface :
        Appearance.colors.colOnSurfaceVariant
        font.family: Fonts.ui
        font.pixelSize: Typography.bodyMedium.pixelSize
        maximumLineCount: 2
        wrapMode: Text.Wrap
        elide: Text.ElideRight
    }
    }
    }
    }
    }
    }
    }
    }
    }
