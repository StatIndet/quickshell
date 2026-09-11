import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

ColumnLayout {
    id: root
    property var row: null
    readonly property var settings: row ? row.settings : ({})
    spacing: Metrics.spacingM
    function edit(key, value) {
        if (row)
            DisplayConfigService.edit(row.key, key, value);
    }
    SettingsRow {
        Layout.fillWidth: true
        title: qsTr("Focus at Startup")
        trailing: StyledSwitch {
            checked: root.settings.focusAtStartup === true
            Accessible.name: qsTr("Focus at Startup")
            onToggled: root.edit("focusAtStartup", checked ? true : null)
        }
    }
    DisplayChoice {
        Layout.fillWidth: true
        title: qsTr("Hot corners")
        options: [
            {
                value: "inherit",
                label: qsTr("Inherit")
            },
            {
                value: "off",
                label: qsTr("Off")
            },
            {
                value: "custom",
                label: qsTr("Select corners")
            }
        ]
        value: !root.settings.hotCorners ? "inherit" : root.settings.hotCorners.indexOf("off") >= 0 ? "off" :
                                                                                                      "custom"

        onSelected: value => root.edit("hotCorners", value === "inherit" ? null : value === "off" ? ["off"] :
                                                                                                    ["top-left"])

    }
    GridLayout {
        Layout.fillWidth: true
        columns: width > 420 ? 2 : 1
        visible: root.settings.hotCorners && root.settings.hotCorners.indexOf("off") < 0
        Repeater {
            model: [
                {
                    key: "top-left",
                    label: qsTr("Top left")
                },
                {
                    key: "top-right",
                    label: qsTr("Top right")
                },
                {
                    key: "bottom-left",
                    label: qsTr("Bottom left")
                },
                {
                    key: "bottom-right",
                    label: qsTr("Bottom right")
                }
            ]
            SettingsRow {
                required property var modelData
                Layout.fillWidth: true
                title: modelData.label
                trailing: StyledSwitch {
                    checked: root.settings.hotCorners ? root.settings.hotCorners.indexOf(modelData.key) >= 0 :
                                                        false
                    Accessible.name: modelData.label
                    onToggled: {
                        const corners = root.settings.hotCorners || [];
                        const next = checked ? corners.concat([modelData.key]) : corners.filter(c => c
                                                                                                     !== modelData.key);
                        root.edit("hotCorners", next.length ? next : ["off"]);
                    }
                }
            }
        }
    }
    OutlinedTextField {
        Layout.fillWidth: true
        labelText: qsTr("Window gaps")
        placeholderText: qsTr("Inherit")
        text: root.settings.gaps === undefined ? "" : String(root.settings.gaps)
        validator: DoubleValidator {
            bottom: 0
            top: 65535
            locale: "C"
        }
        onEditingFinished: root.edit("gaps", text.trim() === "" ? null : Number(text))
    }
    DisplayChoice {
        Layout.fillWidth: true
        title: qsTr("Always center single column")
        options: [
            {
                value: "inherit",
                label: qsTr("Inherit")
            },
            {
                value: "on",
                label: qsTr("On")
            },
            {
                value: "off",
                label: qsTr("Off")
            }
        ]
        value: root.settings["always-center-single-column"] === undefined ? "inherit" :
                                                                            root.settings["always-center-single-column"]
                                                                            ? "on" : "off"
        onSelected: value => root.edit("always-center-single-column", value === "inherit" ? null : value
                                                                                            === "on")

    }
    DisplayColumnWidths {
        Layout.fillWidth: true
        title: qsTr("Default column width")
        single: true
        widths: root.settings["default-column-width"] || []
        onEdited: widths => root.edit("default-column-width", widths.length ? widths : null)
    }
    DisplayColumnWidths {
        Layout.fillWidth: true
        title: qsTr("Preset column widths")
        widths: root.settings["preset-column-widths"] || []
        onEdited: widths => root.edit("preset-column-widths", widths.length ? widths : null)
    }
}
