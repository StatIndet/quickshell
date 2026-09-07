import QtQuick
import QtQuick.Layouts
import qs.Common

ColumnLayout {
    id: root
    required property string title
    required property string description
    required property string integrationState
    property bool busy: false
    property bool blocked: false
    property string error: ""
    signal setupRequested
    visible: integrationState !== "ready"
    spacing: Metrics.spacingS

    SettingsRow {
        Layout.fillWidth: true
        title: root.title
        supportingText: root.integrationState === "unsupported" ? qsTr("Available in a niri session") :
                                                                  root.description
        trailing: ActionButton {
            text: qsTr("Set up")
            enabled: !root.busy && !root.blocked && root.integrationState !== "unsupported"
                     && root.integrationState !== "loading"

            onClicked: root.setupRequested()
            InlineBusyIndicator {
                anchors.centerIn: parent
                busy: root.busy
            }
        }
    }
    InlineStatusBanner {
        Layout.fillWidth: true
        visible: root.error !== ""
        tone: "error"
        message: root.error
    }
}
