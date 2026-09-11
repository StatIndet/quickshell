import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common
import "../../Common/functions/DisplayConfiguration.js" as Config

StyledFlickable {
    id: root
    readonly property var selected: DisplayConfigService.selected
    readonly property var settings: selected ? selected.settings : ({})
    property bool advanced: false
    property string presetName: ""
    clip: true
    contentWidth: width
    contentHeight: content.implicitHeight + Metrics.pageMargin * 2
    Component.onCompleted: DisplayConfigService.refresh()
    function edit(key, value) {
        if (selected)
            DisplayConfigService.edit(selected.key, key, value);
    }
    ColumnLayout {
        id: content
        width: Math.min(760, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL
        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Display configuration")
            description: qsTr("Create or connect the Clavis output configuration.")
            integrationState: NiriConfigService.state("outputs")
            busy: NiriConfigService.busy && NiriConfigService.activeFeature === "outputs"
            blocked: NiriConfigService.busy || DisplayConfigService.busy
            error: NiriConfigService.error
            onSetupRequested: NiriConfigService.setup("outputs")
        }
        InlineStatusBanner {
            Layout.fillWidth: true
            visible: DisplayConfigService.error !== ""
            tone: "error"
            message: DisplayConfigService.error
        }
        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Layout")
            iconName: "monitor"
            DisplayLayoutCanvas {
                Layout.fillWidth: true
            }
            InlineStatusBanner {
                Layout.fillWidth: true
                visible: DisplayConfigService.validation !== ""
                message: DisplayConfigService.validation
            }
            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacingS
                ActionButton {
                    text: qsTr("Identify displays")
                    onClicked: DisplayConfigService.identifyDisplays()
                }
                ActionButton {
                    text: qsTr("Reload")
                    enabled: !DisplayConfigService.busy
                    onClicked: DisplayConfigService.reload()
                }
                ActionButton {
                    text: qsTr("Apply")
                    filled: true
                    enabled: DisplayConfigService.dirty && !DisplayConfigService.busy &&
                             !DisplayConfigService.validation && NiriConfigService.ready("outputs")
                    onClicked: DisplayConfigService.apply()
                    InlineBusyIndicator {
                        anchors.left: parent.right
                        anchors.leftMargin: Metrics.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        busy: DisplayConfigService.busy
                    }
                }
            }
        }
        DisplayChoice {
            Layout.fillWidth: true
            title: qsTr("Display")
            value: DisplayConfigService.selection
            options: DisplayConfigService.draft.filter(r => !r.deleted).map(r => ({
                value: r.key,
                label: r.connected ? r.label : qsTr("%1 (disconnected)").arg(r.label)
            }))
            onSelected: value => DisplayConfigService.selection = value
        }
        InlineStatusBanner {
            Layout.fillWidth: true
            visible: root.selected && !root.selected.editable
            message: qsTr("This output is read-only. Resolve conflicting or unsupported settings in %1.").arg(
                         root.selected ? root.selected.source : "")
        }
        SettingsSection {
            Layout.fillWidth: true
            visible: root.selected !== null
            enabled: root.selected && root.selected.editable && !DisplayConfigService.busy
            title: qsTr("Output settings")
            iconName: "tune"
            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Enabled")
                trailing: StyledSwitch {
                    checked: root.settings.enabled !== false
                    enabled: !root.selected || !root.selected.connected || !checked
                             || DisplayConfigService.draft.filter(r => r.connected && r.settings.enabled
                                                                       !== false).length > 1
                    Accessible.name: qsTr("Enabled")
                    onToggled: root.edit("enabled", checked)
                }
            }
            DisplayChoice {
                Layout.fillWidth: true
                visible: root.selected && root.selected.connected
                title: qsTr("Resolution and refresh rate")
                value: root.settings.mode || ""
                placeholder: root.settings.mode || ""
                options: root.selected && root.selected.live ? root.selected.live.modes.map(m => ({
                    value: Config.modeString(m),
                    label: qsTr("%1 × %2 · %3 Hz").arg(m.width).arg(m.height).arg((m.refreshMilliHz / 1000).toFixed(
                                                                                      3))
                })) : []
                onSelected: value => root.edit("mode", value)
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width > 440 ? 2 : 1
                DisplayChoice {
                    Layout.fillWidth: true
                    title: qsTr("Scale")
                    options: [1, 1.25, 1.5, 1.75, 2, 2.5, 3].map(v => ({
                        value: String(v),
                        label: Math.round(v * 100) + "%"
                    })).concat([
                    {
                        value: "custom",
                        label: qsTr("Custom")
                    }
                    ])
                    value: [1, 1.25, 1.5, 1.75, 2, 2.5, 3].indexOf(root.settings.scale) >= 0 ? String(
                                                                                                   root.settings.scale) :
                                                                                               "custom"
                    onSelected: value => {
                        if (value !== "custom")
                            root.edit("scale", Number(value));
                    }
                }
                OutlinedTextField {
                    Layout.fillWidth: true
                    labelText: qsTr("Custom scale")
                    text: String(root.settings.scale || 1)
                    validator: DoubleValidator {
                        bottom: 0.1
                        top: 10
                        locale: "C"
                    }
                    onEditingFinished: root.edit("scale", Number(text))
                }
                Repeater {
                    model: [
                        {
                            key: "x",
                            label: qsTr("Logical X")
                        },
                        {
                            key: "y",
                            label: qsTr("Logical Y")
                        }
                    ]
                    OutlinedTextField {
                        required property var modelData
                        Layout.fillWidth: true
                        labelText: modelData.label
                        text: String(root.settings.position ? root.settings.position[modelData.key] : 0)
                        validator: IntValidator {}
                        onEditingFinished: root.edit("position", Object.assign({}, root.settings.position, {
                                                                                   [modelData.key]: Number(
                                                                                                        text)
                                                                               }))
                    }
                }
            }
            DisplayChoice {
                Layout.fillWidth: true
                title: qsTr("Rotation and reflection")
                options: [
                    {
                        value: "normal",
                        label: qsTr("Normal")
                    },
                    {
                        value: "90",
                        label: "90°"
                    },
                    {
                        value: "180",
                        label: "180°"
                    },
                    {
                        value: "270",
                        label: "270°"
                    },
                    {
                        value: "flipped",
                        label: qsTr("Flipped")
                    },
                    {
                        value: "flipped-90",
                        label: qsTr("Flipped · 90°")
                    },
                    {
                        value: "flipped-180",
                        label: qsTr("Flipped · 180°")
                    },
                    {
                        value: "flipped-270",
                        label: qsTr("Flipped · 270°")
                    }
                ]
                value: root.settings.transform || "normal"
                onSelected: value => root.edit("transform", value)
            }
            DisplayChoice {
                Layout.fillWidth: true
                title: qsTr("Variable refresh rate")
                enabled: root.selected && (!root.selected.connected || root.selected.live.vrrSupported)
                options: [
                    {
                        value: "off",
                        label: qsTr("Off")
                    },
                    {
                        value: "on",
                        label: qsTr("On")
                    },
                    {
                        value: "on-demand",
                        label: qsTr("On-Demand")
                    }
                ]
                value: root.settings.vrr || "off"
                onSelected: value => root.edit("vrr", value)
            }
            SettingsRow {
                Layout.fillWidth: true
                visible: root.selected && root.selected.connected
                title: qsTr("VRR capability and activity")
                supportingText: !root.selected || !root.selected.live ? "" : !root.selected.live.vrrSupported
                                                                        ? qsTr("Not supported") :
                                                                          root.selected.live.vrrEnabled ? qsTr(
                                                                                                              "Supported · Currently active") :
                                                                                                          qsTr("Supported · Currently inactive")
            }
            ActionButton {
                text: root.advanced ? qsTr("Hide advanced settings") : qsTr("Advanced settings")
                onClicked: root.advanced = !root.advanced
            }
            DisplayAdvancedSettings {
                Layout.fillWidth: true
                visible: root.advanced
                row: root.selected
            }
            ActionButton {
                visible: root.selected && !root.selected.connected
                text: qsTr("Delete saved display")
                onClicked: DisplayConfigService.forget(root.selected.key)
            }
        }
        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Presets")
            iconName: "save"
            DisplayChoice {
                Layout.fillWidth: true
                title: qsTr("Saved preset")
                value: DisplayConfigService.selectedPreset
                options: DisplayConfigService.presets.map(p => ({
                    value: p.id,
                    label: p.name
                }))
                onSelected: value => DisplayConfigService.loadPreset(value, false)
            }
            OutlinedTextField {
                Layout.fillWidth: true
                labelText: qsTr("Preset name")
                text: root.presetName
                onTextChanged: root.presetName = text
            }
            Flow {
                Layout.fillWidth: true
                spacing: Metrics.spacingS
                enabled: !DisplayConfigService.busy
                ActionButton {
                    text: qsTr("Save preset")
                    enabled: root.presetName.trim() !== ""
                    onClicked: DisplayConfigService.savePreset(root.presetName)
                }
                ActionButton {
                    text: qsTr("Rename")
                    enabled: DisplayConfigService.selectedPreset !== "" && root.presetName.trim() !== ""
                    onClicked: DisplayConfigService.renamePreset(DisplayConfigService.selectedPreset,
                                                                 root.presetName)
                }
                ActionButton {
                    text: qsTr("Delete")
                    enabled: DisplayConfigService.selectedPreset !== ""
                    onClicked: DisplayConfigService.deletePreset(DisplayConfigService.selectedPreset)
                }
            }
            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Match presets when displays change")
                trailing: StyledSwitch {
                    checked: DisplayConfigService.autoMatch
                    Accessible.name: qsTr("Match presets when displays change")
                    onToggled: DisplayConfigService.setAutoMatch(checked)
                }
            }
        }
    }
}
