import QtQuick
import qs.Common

// Always reserves its layout slot. Only the existing spinner changes visibility.
Item {
    id: root

    property bool busy: false
    property color spinnerColor: Appearance.colors.colPrimary

    implicitWidth: Metrics.iconM
    implicitHeight: Metrics.iconM
    Accessible.ignored: true

    BrailleSpinner {
        anchors.centerIn: parent
        visible: root.busy
        running: root.busy && root.visible
        dotColor: root.spinnerColor
    }

}
