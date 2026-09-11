import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Widgets.common

ColumnLayout {
    id: root
    property string section: "configuration"
    property bool presentationActive: false
    property var parentModal: null
    function closeChildWindows() {
        if (pageLoader.item && typeof pageLoader.item.closeChildWindows === "function")
            pageLoader.item.closeChildWindows();
    }
    onSectionChanged: {
        closeChildWindows();
        DisplayConfigService.clearCompletionNotice();
    }
    onPresentationActiveChanged: {
        if (!presentationActive) {
            closeChildWindows();
            DisplayConfigService.clearCompletionNotice();
        }
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
        id: pageLoader
        onLoaded: {
            if (item && "parentModal" in item)
                item.parentModal = Qt.binding(() => root.parentModal);
        }
        Layout.fillWidth: true
        Layout.fillHeight: true
        source: root.section === "configuration" ? "DisplayConfigurationPage.qml" : "GammaControlPage.qml"
    }
}
