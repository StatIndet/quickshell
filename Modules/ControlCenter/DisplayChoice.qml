import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

ColumnLayout {
    id: root
    property string title: ""
    property alias options: choice.options
    property alias value: choice.value
    property alias placeholder: choice.placeholder
    signal selected(string value)
    spacing: Metrics.spacingXS
    Text {
        Layout.fillWidth: true
        text: root.title
        wrapMode: Text.Wrap
        font.family: Fonts.ui
        font.pixelSize: Typography.bodyMedium.pixelSize
        color: Appearance.colors.colOnSurface
    }
    SearchSelectMenuField {
        id: choice
        Layout.fillWidth: true
        closeOnAccept: true
        Accessible.name: root.title
        onAccepted: value => root.selected(value)
    }
}
