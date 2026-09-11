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
    property bool customScale: false
    readonly property string selectedKey: selected ? selected.key : ""
    onSelectedKeyChanged: customScale = selected !== null && [1, 1.25, 1.5, 1.75, 2, 2.5, 3].indexOf(
                              settings.scale) < 0
    Component.onCompleted: DisplayConfigService.refresh()
    function edit(key, value) {
        if (selected)
            DisplayConfigService.edit(selected.key, key, value);
    }
    clip: true
    interactive: !layoutCanvas.dragging
    contentWidth: width
    contentHeight: content.implicitHeight + Metrics.pageMargin * 2
    ColumnLayout {
        id: content
        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL
        NiriSetupPrompt {
            Layout.fillWidth: true
            title: qsTr("Display configuration")
            description: ""
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
            flat: true
            DisplayLayoutCanvas {
                id: layoutCanvas
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
                    iconName: "id_card"
                    onClicked: DisplayConfigService.identifyDisplays()
                }
                IconButton {
                    iconName: "refresh"
                    accessibleName: qsTr("Reload")
                    enabled: !DisplayConfigService.busy
                    onClicked: {
                        DisplayConfigService.reload();
                        DisplayConfigService.refresh();
                    }
                }
            }
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
            flat: true
            title: qsTr("Output settings")
            iconName: "tune"
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

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXS
                enabled: root.selected && root.selected.editable && !DisplayConfigService.busy
                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Enabled")
                    iconName: "monitor"
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
                        label: qsTr("%1 × %2 · %3 Hz").arg(m.width).arg(m.height).arg((m.refreshMilliHz
                                                                                       / 1000).toFixed(3))
                    })) : []
                    onSelected: value => root.edit("mode", value)
                }
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
                    value: !root.customScale && [1, 1.25, 1.5, 1.75, 2, 2.5, 3].indexOf(root.settings.scale)
                    >= 0 ? String(root.settings.scale) : "custom"
                    onSelected: value => {
                        root.customScale = value === "custom";
                        if (value !== "custom")
                            root.edit("scale", Number(value));
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: width > 440 ? 2 : 1
                    OutlinedTextField {
                        Layout.fillWidth: true
                        visible: root.customScale
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
                            onEditingFinished: root.edit("position", Object.assign({}, root.settings.position,
                                                                                   {
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
                    title: !root.selected || !root.selected.live ? "" : !root.selected.live.vrrSupported
                                                                   ? qsTr("VRR unavailable") :
                                                                     root.selected.live.vrrEnabled ? qsTr(
                                                                                                         "VRR active") :
                                                                                                     qsTr("VRR inactive")
                }
                SettingsActionRow {
                    Layout.fillWidth: true
                    text: qsTr("Advanced settings")
                    iconName: "tune"
                    trailingIconName: root.advanced ? "expand_less" : "expand_more"
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
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingS
            Item {
                Layout.fillWidth: true
            }
            ActionButton {
                text: qsTr("Discard")
                enabled: DisplayConfigService.dirty && !DisplayConfigService.busy
                onClicked: DisplayConfigService.reload()
            }
            ActionButton {
                text: qsTr("Apply")
                filled: true
                Layout.rightMargin: Metrics.spacingL
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
}
