import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import "../../Common/NiriActionNames.js" as ActionNames
import Clavis.Keyboard
import qs.Services
import qs.Widgets.common

StyledFlickable {
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
    property string query: ""
    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight + Metrics.pageMargin * 2

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
        groups = result;
    }

    function edit(group, binding) {
        recording = false;
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

    function addAction() {
        cancel();
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
        draft = null;
        draftGroup = "";
        rebuild();
    }

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

    function sourceText(chip) {
        const label = chip.collision ? qsTr("Conflicting key spelling; check the active binding") :
                                       chip.invalid ? qsTr("Configuration validation failed") :
                                                      chip.overridden ? qsTr(
                                                                            "Overridden by later configuration") :
                                                                        chip.override ? qsTr(
                                                                                            "Overrides user configuration") :
                                                                                        chip.managed ? qsTr(
                                                                                                           "Clavis managed") :
                                                                                                       qsTr("From user configuration");
        return label + (chip.editable ? "" : "\n" + qsTr("This binding is read-only")) + "\n" + chip.source;
    }

    function closeChildWindows() {
        cancel();
    }
    onPresentationActiveChanged: if (!presentationActive)
                                     recording = false
    Component.onCompleted: {
        rebuild();
        NiriConfigService.refresh();
    }
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
        onCancelled: root.recording = false
        onActiveChanged: if (!active && root.recording)
                             root.recording = false
    }

    ColumnLayout {
        id: column
        width: Math.max(0, root.width - Metrics.pageMargin * 2)
        x: Metrics.pageMargin
        y: Metrics.pageMargin
        spacing: Metrics.spacingM

        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Keyboard shortcuts")
            description: qsTr(
                             "Create or connect the Clavis shortcuts file. Your existing bindings stay in their original files.")
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

        Repeater {
            model: root.groups
            delegate: ColumnLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                visible: root.draftGroup === modelData.id || root.query === "" || (modelData.name + " "
                                                                                   + modelData.expression).toLowerCase(
                             ).indexOf(root.query) >= 0
                spacing: Metrics.spacingS

                Text {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Appearance.colors.colOnLayer0
                    font.family: Typography.bodyMedium.family
                    font.pixelSize: Typography.bodyMedium.pixelSize
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXS
                    Repeater {
                        model: row.modelData.chips
                        delegate: ActionButton {
                            required property var modelData
                            text: modelData.key
                            filled: modelData.effective
                            opacity: modelData.effective ? 1 : 0.55
                            onClicked: root.edit(row.modelData, modelData)
                            StyledToolTip {
                                text: parent.modelData.draft ? qsTr("Not configured") : root.sourceText(
                                                                   parent.modelData)
                            }
                        }
                    }
                    Text {
                        visible: row.modelData.chips.length === 0
                        text: row.modelData.supported ? qsTr("Not configured") : qsTr(
                                                            "Unavailable in this niri version")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Typography.bodyMedium.pixelSize
                        height: Metrics.controlHeightM
                        verticalAlignment: Text.AlignVCenter
                    }
                    ActionButton {
                        text: "+"
                        enabled: row.modelData.supported && NiriConfigService.ready("binds") &&
                                 !NiriConfigService.busy
                        Accessible.name: qsTr("Add shortcut")
                        onClicked: root.edit(row.modelData, null)
                    }
                }
                ActionButton {
                    visible: !row.modelData.builtin && row.modelData.chips.some(chip => chip.managed)
                    enabled: !root.draft && NiriConfigService.ready("binds") && !NiriConfigService.busy
                    text: qsTr("Delete action")
                    onClicked: NiriConfigService.save({
                                                          operation: "delete-group",
                                                          group: row.modelData.identity,
                                                          revision: NiriConfigService.revision
                                                      })
                    StyledToolTip {
                        text: qsTr("Only Clavis bindings are deleted; user configuration is kept")
                    }
                }
                Loader {
                    Layout.fillWidth: true
                    active: root.draft !== null && root.draftGroup === row.modelData.id
                    sourceComponent: editor
                }
            }
        }
    }

    Component {
        id: editor
        ColumnLayout {
            spacing: Metrics.spacingS
            enabled: !NiriConfigService.busy
            Text {
                Layout.fillWidth: true
                visible: !!root.draft.id
                text: root.draft.id ? root.sourceText(root.draft) : ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Appearance.colors.colSubtext
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
                    text: root.draft.key
                    readOnly: !root.draft.managed || root.recording
                    onActiveFocusChanged: if (!activeFocus)
                                              root.recording = false
                }
                ShortcutRecorder {
                    target: keyField
                    enabled: root.recording && inhibitor.active
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
                    enabled: root.draft.managed
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
                visible: root.draft.parameters === true
                message: qsTr("Fill in the action parameters before saving")
            }
            MaterialFilledTextField {
                id: actionField
                Layout.fillWidth: true
                labelText: qsTr("Action expression")
                text: root.draft.action
            }
            MaterialFilledTextField {
                Layout.fillWidth: true
                labelText: qsTr("Title")
                text: typeof root.draft.props["hotkey-overlay-title"] === "string"
                ? root.draft.props["hotkey-overlay-title"] : ""
                onTextEdited: root.change("hotkey-overlay-title", text)
            }
            SettingsActionRow {
                Layout.fillWidth: true
                text: qsTr("Advanced options")
                trailingIconName: root.advanced ? "expand_less" : "expand_more"
                onClicked: root.advanced = !root.advanced
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.advanced
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
            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacingS
                ActionButton {
                    text: qsTr("Save")
                    filled: true
                    enabled: NiriConfigService.ready("binds") && root.draft.editable && root.draftRevision
                             === NiriConfigService.revision && keyField.text !== "" && actionField.text
                             !== "" && (!root.draft.parameters || actionField.text !== root.draft.action)
                    onClicked: {
                        root.recording = false;
                        NiriConfigService.save({
                                                   operation: "save",
                                                   id: root.draft.id || "",
                                                   revision: root.draftRevision,
                                                   key: keyField.text,
                                                   action: actionField.text,
                                                   patch: root.patch,
                                                   unset: root.unset
                                               });
                    }
                }
                ActionButton {
                    text: root.draft.override ? qsTr("Remove override") : qsTr("Delete")
                    visible: !!root.draft.id && root.draft.managed
                    enabled: root.draftRevision === NiriConfigService.revision
                    onClicked: NiriConfigService.save({
                                                          operation: "delete",
                                                          id: root.draft.id,
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
