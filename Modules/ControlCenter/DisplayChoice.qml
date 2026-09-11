import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

SettingsRow {
    id: root
    property alias options: choice.options
    property alias value: choice.value
    property alias placeholder: choice.placeholder
    signal selected(string value)

    trailing: SearchSelectMenuField {
        id: choice
        Layout.preferredWidth: Math.min(280, Math.max(120, root.width * 0.5))
        closeOnAccept: true
        Accessible.name: root.title
        onAccepted: value => root.selected(value)
    }
}
