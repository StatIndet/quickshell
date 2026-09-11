import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

ColumnLayout {
    id: root

    property string title: ""
    property string description: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 1
    property string suffix: ""

    signal moved(real value)

    Layout.fillWidth: true
    spacing: Metrics.spacingXS
    opacity: enabled ? 1 : 0.45

    RowLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacingM

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXXS

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: Typography.bodyMedium.pixelSize
                font.weight: Font.Medium
            }

            Text {
                Layout.fillWidth: true
                visible: root.description !== ""
                text: root.description
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: Typography.bodySmall.pixelSize
                wrapMode: Text.Wrap
            }
        }

        Text {
            text: Math.round(root.value) + root.suffix
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Fonts.numeric
            font.pixelSize: Typography.bodyMedium.pixelSize
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    MaterialSlider {
        Layout.fillWidth: true
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        enabled: root.enabled
        accessibleName: root.title
        valueFormatter: sliderValue => {
            return Math.round(sliderValue).toString() + root.suffix;
        }
        onMoved: root.moved(Math.round(value))
    }
}
