import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

ColumnLayout {
    id: root
    property string section: "configuration"
    spacing: 0
    StyledButtonGroup {
        Layout.alignment: Qt.AlignLeft
        Layout.leftMargin: Math.max(Metrics.pageMargin, (root.width - 640) / 2)
        Layout.topMargin: Metrics.pageMargin
        currentValue: root.section
        horizontalPadding: Metrics.spacingM
        model: [
            {
                value: "configuration",
                label: qsTr("Configuration")
            },
            {
                value: "gamma",
                label: qsTr("Gamma Control")
            }
        ]
        onValueSelected: value => root.section = value
    }
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        source: root.section === "configuration" ? "DisplayConfigurationPage.qml" : "GammaControlPage.qml"
    }
}
