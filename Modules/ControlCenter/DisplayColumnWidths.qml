import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

ColumnLayout {
    id: root
    property string title: ""
    property var widths: []
    property bool single: false
    signal edited(var widths)
    spacing: Metrics.spacingS
    Text {
        Layout.fillWidth: true
        text: root.title
        font.family: Fonts.ui
        color: Appearance.colors.colOnSurface
        wrapMode: Text.Wrap
    }
    Repeater {
        model: root.widths
        delegate: GridLayout {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            columns: width > 420 ? 3 : 1
            SearchSelectMenuField {
                Layout.fillWidth: true
                options: [
                    {
                        value: "proportion",
                        label: qsTr("Proportion")
                    },
                    {
                        value: "fixed",
                        label: qsTr("Pixels")
                    }
                ]
                value: modelData.kind
                closeOnAccept: true
                Accessible.name: root.title
                onAccepted: value => {
                    const next = root.widths.slice();
                    next[index] = {
                        kind: value,
                        value: value === "fixed" ? 800 : 0.5
                    };
                    root.edited(next);
                }
            }
            OutlinedTextField {
                Layout.fillWidth: true
                labelText: modelData.kind === "fixed" ? qsTr("Pixels") : qsTr("Proportion (1 = full width)")
                text: String(modelData.value)
                validator: DoubleValidator {
                    bottom: modelData.kind === "fixed" ? 1 : 0.01
                    top: modelData.kind === "fixed" ? 65535 : 100
                    locale: "C"
                    decimals: modelData.kind === "fixed" ? 0 : 12
                }
                onEditingFinished: {
                    const next = root.widths.slice();
                    next[index] = {
                        kind: modelData.kind,
                        value: Number(text)
                    };
                    root.edited(next);
                }
            }
            IconButton {
                iconName: "delete"
                accessibleName: qsTr("Remove column width")
                onClicked: root.edited(root.widths.filter((_, i) => i !== index))
            }
        }
    }
    ActionButton {
        Layout.alignment: Qt.AlignRight
        visible: !root.single || root.widths.length === 0
        text: root.single ? qsTr("Set custom width") : qsTr("Add column width")
        onClicked: root.edited(root.widths.concat([
                                                      {
                                                          kind: "proportion",
                                                          value: 0.5
                                                      }
                                                  ]))
    }
}
