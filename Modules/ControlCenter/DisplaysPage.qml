import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Widgets.common

ColumnLayout {
    id: root
    property string section: "configuration"
    property bool presentationActive: false
    onSectionChanged: DisplayConfigService.clearCompletionNotice()
    onPresentationActiveChanged: {
        if (!presentationActive)
            DisplayConfigService.clearCompletionNotice();
    }
    onVisibleChanged: {
        if (!visible)
            DisplayConfigService.clearCompletionNotice();
    }
    Component.onDestruction: DisplayConfigService.clearCompletionNotice()
    spacing: 0
    StyledButtonGroup {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Metrics.pageMargin
        currentValue: root.section
        model: [
            {
                value: "configuration",
                label: qsTr("Display configuration")
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
