import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Rectangle {
    id: root

    required property string serviceName
    required property string iconName
    required property string fieldLabel
    required property string placeholderText
    required property string invalidKeyText
    property string clearDescription: ""
    property bool configured: false
    property bool credentialsReady: false
    property bool busy: false
    property bool checking: false
    property bool statusError: false
    property var storeAction: null
    property var clearAction: null
    property bool revealApiKey: false
    property string feedbackText: ""
    property bool feedbackError: false

    function showResult(result, fallbackMessage) {
        const success = result && result.ok;
        root.feedbackError = !success;
        root.feedbackText = result && result.message ? result.message : success ? "" : fallbackMessage;
    }

    function applyApiKey() {
        const value = apiKeyField.text.trim();
        if (value.length < 16) {
            root.feedbackError = true;
            root.feedbackText = root.invalidKeyText;
            apiKeyField.forceActiveFocus();
            return;
        }
        if (root.storeAction)
            root.showResult(root.storeAction(value), qsTr("Could not save the API key"));
    }

    function clearApiKey() {
        if (root.clearAction)
            root.showResult(root.clearAction(), qsTr("Could not clear the API key"));
    }

    function completeOperation(success, message) {
        root.feedbackError = !success;
        root.feedbackText = message;
        if (success) {
            apiKeyField.clear();
            root.revealApiKey = false;
        }
    }

    implicitHeight: serviceContent.implicitHeight + Metrics.spacingL * 2
    radius: Appearance.rounding.large
    color: Appearance.colors.colSurfaceContainer

    ColumnLayout {
        id: serviceContent

        anchors.fill: parent
        anchors.margins: Metrics.spacingL
        spacing: Metrics.spacingM

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingM

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: 22
                    fill: 1
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.serviceName
                color: Appearance.colors.colOnSurface
                font.family: Typography.titleMedium.family
                font.pixelSize: Typography.titleMedium.pixelSize
                font.weight: Typography.titleMedium.weight
                textFormat: Text.PlainText
            }

            Rectangle {
                implicitWidth: statusContent.implicitWidth + Metrics.spacingL * 2
                implicitHeight: 34
                radius: Appearance.rounding.full
                color: root.statusError ? Appearance.colors.colErrorContainer : root.configured
                                          ? Appearance.colors.colSecondaryContainer :
                                            Appearance.colors.colSurfaceContainerHighest

                RowLayout {
                    id: statusContent

                    anchors.centerIn: parent
                    spacing: Metrics.spacingXS

                    MaterialSymbol {
                        text: root.checking || root.busy ? "sync" : root.statusError ? "error" : root.configured
                                                                                       ? "key" : "key_off"
                        iconSize: 17
                        fill: root.configured ? 1 : 0
                        color: root.statusError ? Appearance.colors.colOnErrorContainer : root.configured
                                                  ? Appearance.colors.colOnSecondaryContainer :
                                                    Appearance.colors.colOnSurfaceVariant
                    }

                    Text {
                        text: root.checking ? qsTr("Checking") : root.busy ? qsTr("Processing") : root.statusError
                                                                             ? qsTr("Could not read key") :
                                                                               root.configured ? qsTr(
                                                                                                     "Key saved") :
                                                                                                 qsTr("No key saved")
                        color: root.statusError ? Appearance.colors.colOnErrorContainer : root.configured
                                                  ? Appearance.colors.colOnSecondaryContainer :
                                                    Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.labelMedium.family
                        font.pixelSize: Typography.labelMedium.pixelSize
                        font.weight: Font.DemiBold
                        textFormat: Text.PlainText
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.dividerWidth
            color: Appearance.colors.colOutlineVariant
        }

        Text {
            Layout.fillWidth: true
            text: root.fieldLabel
            color: Appearance.colors.colOnSurface
            font.family: Typography.labelLarge.family
            font.pixelSize: Typography.labelLarge.pixelSize
            font.weight: Typography.labelLarge.weight
            textFormat: Text.PlainText
        }

        MaterialTextField {
            id: apiKeyField

            Layout.fillWidth: true
            Layout.preferredHeight: 56
            placeholderText: root.placeholderText
            echoMode: root.revealApiKey ? TextInput.Normal : TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            maximumLength: 128
            enabled: root.credentialsReady && !root.busy
            Accessible.name: root.fieldLabel
            Accessible.description: qsTr("Save securely in the system keyring")
            onTextChanged: {
                if (root.feedbackError) {
                    root.feedbackError = false;
                    root.feedbackText = "";
                }
            }
            onAccepted: root.applyApiKey()

            trailingContent: Component {
                IconButton {
                    anchors.fill: parent
                    iconName: root.revealApiKey ? "visibility_off" : "visibility"
                    iconSize: Metrics.iconM
                    iconColor: Appearance.colors.colOnSurfaceVariant
                    accessibleName: root.revealApiKey ? qsTr("Hide API key") : qsTr("Show API key")
                    hoverStateLayerColor: Appearance.colors.colLayer3Hover
                    pressedStateLayerColor: Appearance.colors.colLayer3Active
                    onClicked: root.revealApiKey = !root.revealApiKey
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("The key is stored in the system keyring and takes effect immediately after saving.")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Typography.bodySmall.family
            font.pixelSize: Typography.bodySmall.pixelSize
            font.weight: Typography.bodySmall.weight
            lineHeight: 1.35
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: feedbackRow.implicitHeight + Metrics.spacingM * 2
            radius: Appearance.rounding.small
            visible: root.feedbackText !== ""
            color: root.feedbackError ? Appearance.colors.colErrorContainer :
                                        Appearance.colors.colSecondaryContainer

            RowLayout {
                id: feedbackRow

                anchors.fill: parent
                anchors.margins: Metrics.spacingM
                spacing: Metrics.spacingS

                MaterialSymbol {
                    text: root.busy ? "sync" : root.feedbackError ? "error" : "check_circle"
                    iconSize: Metrics.iconS
                    fill: root.busy ? 0 : 1
                    color: root.feedbackError ? Appearance.colors.colOnErrorContainer :
                                                Appearance.colors.colOnSecondaryContainer
                }

                Text {
                    Layout.fillWidth: true
                    text: root.feedbackText
                    color: root.feedbackError ? Appearance.colors.colOnErrorContainer :
                                                Appearance.colors.colOnSecondaryContainer
                    font.family: Typography.bodySmall.family
                    font.pixelSize: Typography.bodySmall.pixelSize
                    font.weight: Typography.bodySmall.weight
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingS

            Item {
                Layout.fillWidth: true
            }

            ActionButton {
                text: qsTr("Clear key")
                iconName: "delete"
                enabled: root.configured && !root.busy
                contentColor: Appearance.colors.colPrimary
                Accessible.description: root.clearDescription
                onClicked: root.clearApiKey()
            }

            ActionButton {
                text: qsTr("Save key")
                iconName: "save"
                enabled: root.credentialsReady && !root.busy && apiKeyField.text.trim().length >= 16
                contentColor: Appearance.colors.colPrimary
                Accessible.description: qsTr("Save securely and apply immediately without restarting")
                onClicked: root.applyApiKey()
            }
        }
    }
}
