import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import "../../Common/NiriActionNames.js" as ActionNames
import Clavis.Keyboard
import qs.Services
import qs.Widgets.common

ListView {
    id: root
    property var parentModal: null
    property bool presentationActive: false
    property var groups: []
    property var draft: null
    property string draftGroup: ""
    property string draftRevision: ""
    property var patch: ({})
    property var unset: []
    property bool advanced: false
    property bool recording: false
    property bool inlineRecording: false
    property bool editorOpen: false
    property string query: ""
    property string category: "all"
    clip: true
    contentWidth: width
    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds
    spacing: Metrics.spacingM
    topMargin: Metrics.pageMargin
    bottomMargin: Metrics.pageMargin
    ScrollBar.vertical: StyledScrollBar {}
    property var visibleGroups: []
    model: visibleGroups
    keyNavigationEnabled: false
    onGroupsChanged: updateVisibleGroups()
    onQueryChanged: updateVisibleGroups()
    onCategoryChanged: updateVisibleGroups()
    onDraftGroupChanged: updateVisibleGroups()

    function updateVisibleGroups() {
        const filtered = groups.filter(group => draftGroup === group.id || (matchesCategory(group) && (query
                                                                                                       === "" || (
                                                                                                           group.name
                                                                                                           + " " + group.expression).toLowerCase(
                                                                                                           ).indexOf(
                                                                                                           query) >= 0)));
        // Selecting another chip must not reset the list and destroy its open editor.
        if (JSON.stringify(visibleGroups) !== JSON.stringify(filtered))
            visibleGroups = filtered;
        // ListView retains the current delegate even when it scrolls out of view.
        currentIndex = visibleGroups.findIndex(group => group.id === draftGroup);
    }

    component ShortcutChip: RippleButton {
        id: shortcutChip
        property bool recordingStyle: false
        property bool removable: false
        property bool removalEnabled: true
        property string removalLabel: qsTr("Delete")
        signal removeRequested
        implicitWidth: label.implicitWidth + leftPadding + rightPadding
        implicitHeight: Metrics.controlHeightS
        height: Metrics.controlHeightS
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        topPadding: 0
        bottomPadding: 0
        leftPadding: Metrics.spacingM
        rightPadding: removable ? removeButton.width + Metrics.spacingXS * 2 : Metrics.spacingM
        buttonRadius: Appearance.rounding.small
        buttonRadiusPressed: buttonRadius
        containerColor: recordingStyle ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
        stateLayerColor: recordingStyle ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
        rippleColor: stateLayerColor
        stateLayerOpacity: Appearance.interaction.hoverStateLayerOpacity
        focusStateLayerOpacity: Appearance.interaction.focusStateLayerOpacity
        pressedStateLayerOpacity: Appearance.interaction.pressedStateLayerOpacity
        IconButton {
            id: removeButton
            z: 2
            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacingXS
            anchors.verticalCenter: parent.verticalCenter
            controlSize: Metrics.controlHeightS - Metrics.spacingXS * 2
            iconSize: Metrics.iconS
            iconName: "close"
            iconColor: shortcutChip.stateLayerColor
            visible: shortcutChip.removable
            enabled: shortcutChip.removalEnabled
            accessibleName: shortcutChip.removalLabel
            showTooltip: false
            onClicked: shortcutChip.removeRequested()
        }
        contentItem: Text {
            id: label
            text: shortcutChip.text
            textFormat: Text.PlainText
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            color: shortcutChip.stateLayerColor
            font.family: Typography.labelMedium.family
            font.pixelSize: Typography.labelMedium.pixelSize
        }
    }

    function matchesCategory(group) {
        const assigned = group.chips.some(chip => !chip.draft);
        switch (category) {
        case "assigned":
            return assigned;
        case "managed":
            return group.chips.some(chip => chip.managed && !chip.draft);
        case "unassigned":
            return !assigned;
        default:
            return true;
        }
    }

    function rebuild() {
        if (draft)
            return;
        const result = [];
        const byAction = {};
        NiriConfigService.actionCatalog.forEach(entry => {
            const identity = entry.expression + ";";
            const group = {
                id: entry.id,
                identity: identity,
                name: ActionNames.translated(entry.name),
                expression: entry.expression,
                supported: entry.supported,
                error: entry.error || "",
                parameters: entry.parameters,
                builtin: true,
                chips: []
            };
            result.push(group);
            byAction[identity] = group;
        });
        NiriConfigService.bindings.forEach(binding => {
            let group = byAction[binding.group];
            if (!group) {
                group = {
                    id: binding.group,
                    identity: binding.group,
                    name: binding.action,
                    expression: binding.action,
                    supported: true,
                    builtin: false,
                    chips: []
                };
                byAction[binding.group] = group;
                result.push(group);
            }
            group.chips.push(binding);
        });
        result.forEach(group => {
            const titled = group.chips.find(chip => typeof chip.props["hotkey-overlay-title"] === "string"
                                                    && chip.props["hotkey-overlay-title"] !== "");
            if (titled)
                group.name = titled.props["hotkey-overlay-title"];
        });
        // Status notifications can carry an unchanged snapshot. Keep the delegates in that case.
        if (JSON.stringify(groups) !== JSON.stringify(result))
            groups = result;
    }

    function edit(group, binding, expand = true) {
        if (editorOpen && draftGroup === group.id && draft && binding && draft.id === binding.id) {
            cancel();
            return;
        }
        cleanup.stop();
        recording = false;
        inlineRecording = false;
        editorOpen = expand;
        draftGroup = group.id;
        draftRevision = NiriConfigService.revision;
        patch = {};
        unset = [];
        advanced = false;
        draft = binding && !binding.draft ? Object.assign({}, binding) : {
                                                key: "",
                                                action: group.expression,
                                                props: {},
                                                parameters: group.parameters || false,
                                                managed: true,
                                                editable: true
                                            };
    }

    function addShortcut(group) {
        edit(group, null, false);
        inlineRecording = true;
        root.forceActiveFocus();
        recording = true;
    }

    function stopRecording() {
        recording = false;
        if (inlineRecording)
            cancel();
    }

    function addAction() {
        clearDraft();
        const group = {
            id: "draft",
            name: qsTr("New action"),
            expression: "",
            supported: true,
            builtin: false,
            chips: [
                {
                    key: qsTr("Not configured"),
                    draft: true,
                    effective: false,
                    managed: false
                }
            ]
        };
        groups = [group].concat(groups);
        edit(group, null);
    }

    function cancel() {
        recording = false;
        inlineRecording = false;
        editorOpen = false;
        cleanup.restart();
    }

    function clearDraft() {
        cleanup.stop();
        recording = false;
        inlineRecording = false;
        editorOpen = false;
        draft = null;
        draftGroup = "";
        rebuild();
    }

    Timer {
        id: cleanup
        interval: Appearance.animation.expressiveDefaultSpatial.duration
        onTriggered: root.clearDraft()
    }

    ShortcutRecorder {
        target: root
        enabled: root.inlineRecording && root.recording && inhibitor.active
        keymap: NiriConfigService.snapshot.keymap || ({})
        onCaptured: key => {
            root.recording = false;
            root.draft = Object.assign({}, root.draft, {
                                           key: key
                                       });
            if (root.draft.parameters || !root.draft.action) {
                root.inlineRecording = false;
                root.editorOpen = true;
            } else {
                NiriConfigService.save({
                                           operation: "save",
                                           id: "",
                                           revision: root.draftRevision,
                                           key: key,
                                           action: root.draft.action,
                                           patch: {},
                                           unset: []
                                       });
            }
        }
        onCancelled: root.stopRecording()
        onFailed: reason => {
            root.recording = false;
            root.inlineRecording = false;
            root.editorOpen = true;
            NiriConfigService.error = reason;
        }
    }
    onActiveFocusChanged: if (!activeFocus && inlineRecording && recording)
                              stopRecording()

    function change(name, value) {
        patch = Object.assign({}, patch, {
                                  [name]: value
                              });
        unset = unset.filter(option => option !== name);
    }

    function option(name, fallback) {
        if (unset.indexOf(name) >= 0)
            return fallback;
        if (patch[name] !== undefined)
            return patch[name];
        return draft && draft.props[name] !== undefined ? draft.props[name] : fallback;
    }

    function bindingWarning(binding) {
        if (binding.collision)
            return qsTr("Conflicting key spelling; check the active binding");
        if (binding.invalid)
            return qsTr("Configuration validation failed");
        if (binding.overridden)
            return qsTr("Overridden by later configuration");
        if (!binding.editable)
            return qsTr("This binding is read-only");
        return "";
    }

    function closeChildWindows() {
        cancel();
    }
    onPresentationActiveChanged: if (!presentationActive)
                                     cancel()
    // The shared service loads once and watches the configuration files thereafter.
    Component.onCompleted: rebuild()
    Component.onDestruction: recording = false

    Connections {
        target: NiriConfigService
        function onSnapshotChanged() {
            root.rebuild();
        }
        function onActionCatalogChanged() {
            root.rebuild();
        }
        function onSaved() {
            if (root.draft && NiriConfigService.activeFeature === "binds")
                root.cancel();
        }
    }

    ShortcutInhibitor {
        id: inhibitor
        window: root.parentModal
        enabled: root.recording && root.presentationActive
        onCancelled: root.stopRecording()
        onActiveChanged: if (!active && root.recording)
                             root.stopRecording()
    }

    header: ColumnLayout {
        id: column
        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        spacing: Metrics.spacingM

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Keyboard shortcuts")
            description: qsTr(
                             "Create or connect the shortcuts file. Your existing bindings stay in their original files.")
            integrationState: NiriConfigService.state("binds")
            busy: NiriConfigService.busy && NiriConfigService.activeFeature === "binds"
            blocked: NiriConfigService.busy
            error: NiriConfigService.error
            onSetupRequested: NiriConfigService.setup("binds")
        }
        InlineStatusBanner {
            Layout.fillWidth: true
            visible: NiriConfigService.ready("binds") && NiriConfigService.error !== ""
            tone: "error"
            message: NiriConfigService.error
        }
        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.inlineRecording && root.recording && !inhibitor.active
            message: qsTr(
                         "Shortcut inhibition is not active. Use manual key input if recording is unavailable.")
        }
        RowLayout {
            Layout.fillWidth: true
            MaterialFilledTextField {
                Layout.fillWidth: true
                labelText: qsTr("Search actions")
                onTextChanged: root.query = text.toLowerCase()
            }
            ActionButton {
                text: qsTr("Add action")
                iconName: "add"
                enabled: NiriConfigService.ready("binds") && !NiriConfigService.busy
                onClicked: root.addAction()
            }
        }

        StyledButtonGroup {
            Layout.fillWidth: true
            currentValue: root.category
            enabled: !NiriConfigService.busy
            model: [
                {
                    value: "all",
                    label: qsTr("All")
                },
                {
                    value: "assigned",
                    label: qsTr("Assigned")
                },
                {
                    value: "managed",
                    label: qsTr("Assigned by me")
                },
                {
                    value: "unassigned",
                    label: qsTr("Unassigned")
                }
            ]
            onValueSelected: value => {
                if (root.category === value)
                    return;
                root.clearDraft();
                root.category = value;
            }
        }
    }

    delegate: Item {
        id: rowContainer
        required property var modelData
        width: root.width
        implicitHeight: row.implicitHeight

        // ListView positions the delegate. Center the content inside it instead.
        ColumnLayout {
            id: row
            readonly property var modelData: rowContainer.modelData
            width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Metrics.spacingS

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingM

                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: row.width * 0.38
                    Layout.minimumWidth: 0
                    text: row.modelData.name
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Appearance.colors.colOnLayer0
                    font.family: Typography.bodyMedium.family
                    font.pixelSize: Typography.bodyMedium.pixelSize
                }
                Flow {
                    id: chips
                    Layout.fillWidth: true
                    Layout.preferredWidth: row.width * 0.62
                    Layout.minimumWidth: 0
                    spacing: Metrics.spacingXS
                    layoutDirection: Qt.RightToLeft

                    ShortcutChip {
                        visible: root.inlineRecording && root.draftGroup === row.modelData.id
                        text: root.recording ? qsTr("Press shortcut…") : (root.draft ? root.draft.key : "")

                        recordingStyle: true
                        focusPolicy: Qt.TabFocus
                        width: Math.min(implicitWidth, chips.width)
                        enabled: !NiriConfigService.busy
                        onClicked: {
                            cleanup.stop();
                            root.recording = false;
                            root.inlineRecording = false;
                            root.editorOpen = true;
                        }
                    }
                    Repeater {
                        // Keep the stable binding order when right-aligning the chips.
                        model: (root.category === "managed" ? row.modelData.chips.filter(binding
                                                                                         => binding.managed) :
                                                              row.modelData.chips).slice().reverse()
                        delegate: ShortcutChip {
                            required property var modelData
                            text: modelData.key
                            removable: !!modelData.id && modelData.managed
                            removalEnabled: NiriConfigService.ready("binds") && (!root.draft
                                                                                 || root.draftRevision
                                                                                 === NiriConfigService.revision)
                            removalLabel: modelData.override ? qsTr("Remove override") : qsTr("Delete")
                            onRemoveRequested: {
                                root.recording = false;
                                NiriConfigService.save({
                                                           operation: "delete",
                                                           id: modelData.id,
                                                           revision: root.draft ? root.draftRevision :
                                                                                  NiriConfigService.revision
                                                       });
                            }
                            width: Math.min(implicitWidth, chips.width)
                            enabled: !NiriConfigService.busy
                            opacity: modelData.effective ? 1 : 0.55
                            onClicked: root.edit(row.modelData, modelData)
                        }
                    }
                    Text {
                        visible: row.modelData.chips.length === 0 && !(root.inlineRecording && root.draftGroup
                                                                       === row.modelData.id)
                        width: Math.min(implicitWidth, chips.width)
                        text: row.modelData.supported ? qsTr("Not configured") : qsTr(
                                                            "Unavailable in this niri version")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Typography.bodyMedium.pixelSize
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignRight
                        height: Math.max(implicitHeight, Metrics.controlHeightS)
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                IconButton {
                    iconName: "delete"
                    iconColor: Appearance.colors.colError
                    controlSize: Metrics.controlHeightS
                    iconSize: Metrics.iconS
                    visible: !row.modelData.builtin && row.modelData.chips.some(chip => chip.managed)
                    enabled: !root.draft && NiriConfigService.ready("binds") && !NiriConfigService.busy
                    accessibleName: qsTr("Delete action")
                    onClicked: NiriConfigService.save({
                                                          operation: "delete-group",
                                                          group: row.modelData.identity,
                                                          revision: NiriConfigService.revision
                                                      })
                }
                IconButton {
                    iconName: "add_circle"
                    controlSize: Metrics.controlHeightS
                    iconSize: Metrics.iconS
                    enabled: row.modelData.supported && NiriConfigService.ready("binds") &&
                             !NiriConfigService.busy
                    accessibleName: qsTr("Add shortcut")
                    onClicked: root.addShortcut(row.modelData)
                }
            }
            Item {
                id: editorHost
                readonly property bool expanded: root.editorOpen && root.draftGroup === row.modelData.id
                Layout.fillWidth: true
                Layout.preferredHeight: expanded ? editorLoader.implicitHeight : 0
                clip: true
                enabled: expanded
                opacity: expanded ? 1 : 0
                Behavior on Layout.preferredHeight {
                    ElementMoveAnimation {}
                }
                Behavior on opacity {
                    ElementMoveAnimation {}
                }
                Loader {
                    id: editorLoader
                    width: parent.width
                    active: editorHost.expanded || editorHost.height > 0
                    property var bindingDraft: ({
                                                    props: {}
                                                })
                    Component.onCompleted: {
                        if (root.draftGroup === row.modelData.id && root.draft)
                            bindingDraft = root.draft;
                    }
                    Connections {
                        target: root
                        function onDraftChanged() {
                            if (root.draftGroup === row.modelData.id && root.draft)
                                editorLoader.bindingDraft = root.draft;
                        }
                    }
                    sourceComponent: editor
                }
            }
        }
    }

    Component {
        id: editor
        ColumnLayout {
            id: editorContent
            readonly property var bindingDraft: parent.bindingDraft
            spacing: Metrics.spacingS
            enabled: !NiriConfigService.busy
            InlineStatusBanner {
                Layout.fillWidth: true
                message: root.bindingWarning(editorContent.bindingDraft)
                visible: !!editorContent.bindingDraft.id && message !== ""
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: root.draftRevision !== NiriConfigService.revision
                message: qsTr(
                             "Configuration changed. Cancel and reload before saving; your draft has been kept.")
            }
            RowLayout {
                Layout.fillWidth: true
                MaterialFilledTextField {
                    id: keyField
                    Layout.fillWidth: true
                    labelText: qsTr("Key")
                    text: editorContent.bindingDraft.key
                    readOnly: !editorContent.bindingDraft.managed || root.recording
                    onActiveFocusChanged: if (!activeFocus)
                                              root.recording = false
                }
                ShortcutRecorder {
                    target: keyField
                    enabled: root.recording && !root.inlineRecording && inhibitor.active
                    keymap: NiriConfigService.snapshot.keymap || ({})
                    onCaptured: key => {
                        keyField.text = key;
                        root.recording = false;
                    }
                    onCancelled: root.recording = false
                    onFailed: reason => {
                        root.recording = false;
                        NiriConfigService.error = reason;
                    }
                }
                ActionButton {
                    text: root.recording ? qsTr("Cancel recording") : qsTr("Record key")
                    enabled: editorContent.bindingDraft.managed
                    onClicked: {
                        if (root.recording)
                            root.recording = false;
                        else {
                            keyField.forceActiveFocus();
                            root.recording = true;
                        }
                    }
                }
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: root.recording && !inhibitor.active
                message: qsTr(
                             "Shortcut inhibition is not active. Use manual key input if recording is unavailable.")
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: editorContent.bindingDraft.parameters === true
                message: qsTr("Fill in the action parameters before saving")
            }
            MaterialFilledTextField {
                id: actionField
                Layout.fillWidth: true
                labelText: qsTr("Action expression")
                text: editorContent.bindingDraft.action
            }
            MaterialFilledTextField {
                Layout.fillWidth: true
                labelText: qsTr("Title")
                text: typeof editorContent.bindingDraft.props["hotkey-overlay-title"] === "string"
                ? editorContent.bindingDraft.props["hotkey-overlay-title"] : ""
                onTextEdited: root.change("hotkey-overlay-title", text)
            }
            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("Advanced options")
                trailingIconName: root.advanced ? "expand_less" : "expand_more"
                onClicked: root.advanced = !root.advanced
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.advanced ? advancedContent.implicitHeight : 0
                clip: true
                enabled: root.advanced
                opacity: root.advanced ? 1 : 0
                Behavior on Layout.preferredHeight {
                    ElementMoveAnimation {}
                }
                Behavior on opacity {
                    ElementMoveAnimation {}
                }
                ColumnLayout {
                    id: advancedContent
                    width: parent.width
                    SettingsRow {
                        Layout.fillWidth: true
                        title: qsTr("Repeat while held")
                        trailing: StyledSwitch {
                            checked: root.option("repeat", true)
                            onToggled: root.change("repeat", checked)
                        }
                    }
                    SettingsRow {
                        Layout.fillWidth: true
                        title: qsTr("Allow while locked")
                        supportingText: qsTr("Only available for spawn and spawn-sh")
                        trailing: StyledSwitch {
                            enabled: /^\s*(spawn|spawn-sh)\s/.test(actionField.text)
                            checked: root.option("allow-when-locked", false)
                            onToggled: root.change("allow-when-locked", checked)
                        }
                    }
                    ActionButton {
                        visible: root.option("allow-when-locked", undefined) !== undefined
                        text: qsTr("Remove lock option")
                        onClicked: root.unset = root.unset.concat(["allow-when-locked"])
                    }
                    MaterialFilledTextField {
                        Layout.fillWidth: true
                        labelText: qsTr("Minimum interval (ms)")
                        text: String(root.option("cooldown-ms", 0))
                        validator: IntValidator {
                            bottom: 0
                            top: 2147483647
                        }
                        onTextEdited: if (acceptableInput)
                                          root.change("cooldown-ms", Number(text))
                    }
                    SettingsRow {
                        Layout.fillWidth: true
                        title: qsTr("Keep working when apps inhibit shortcuts")
                        trailing: StyledSwitch {
                            checked: !root.option("allow-inhibiting", true)
                            onToggled: root.change("allow-inhibiting", !checked)
                        }
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacingS
                ActionButton {
                    text: qsTr("Save")
                    filled: true
                    enabled: NiriConfigService.ready("binds") && editorContent.bindingDraft.editable
                             && root.draftRevision === NiriConfigService.revision && keyField.text !== ""
                             && actionField.text !== "" && (!editorContent.bindingDraft.parameters
                                                            || actionField.text
                                                            !== editorContent.bindingDraft.action)
                    onClicked: {
                        root.recording = false;
                        NiriConfigService.save({
                                                   operation: "save",
                                                   id: editorContent.bindingDraft.id || "",
                                                   revision: root.draftRevision,
                                                   key: keyField.text,
                                                   action: actionField.text,
                                                   patch: root.patch,
                                                   unset: root.unset
                                               });
                    }
                }
                ActionButton {
                    text: editorContent.bindingDraft.override ? qsTr("Remove override") : qsTr("Delete")
                    visible: !!editorContent.bindingDraft.id && editorContent.bindingDraft.managed
                    enabled: root.draftRevision === NiriConfigService.revision
                    onClicked: NiriConfigService.save({
                                                          operation: "delete",
                                                          id: editorContent.bindingDraft.id,
                                                          revision: root.draftRevision
                                                      })
                }
                ActionButton {
                    text: qsTr("Cancel")
                    onClicked: root.cancel()
                }
            }
        }
    }
}
