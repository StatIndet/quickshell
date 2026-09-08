import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

ColumnLayout {
    id: root

    property string title: ""
    property string axisTag: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 1
    property bool discrete: false
    property int valueDecimals: 0
    property string suffix: ""

    signal moved(real value)
    signal committed(real value)

    Layout.fillWidth: true
    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Appearance.colors.colOnSecondaryContainer
            font.family: Fonts.ui
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Text {
            text: root.axisTag + "  " + Number(root.value).toFixed(root.valueDecimals) + root.suffix
            color: Appearance.colors.colOnSecondaryContainer
            font.family: Fonts.numeric
            font.pixelSize: 12
        }
    }

    MaterialSlider {
        Layout.fillWidth: true
        from: root.from
        to: root.to
        stepSize: root.stepSize
        discrete: root.discrete
        value: root.value
        valueDecimals: root.valueDecimals
        valueSuffix: root.suffix
        onMoved: root.moved(value)
        onCommitted: root.committed(value)
    }
}
