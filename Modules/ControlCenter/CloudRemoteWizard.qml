pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

FloatingWindow {
    id: root

    property var parentModal: null
    property string wizardState: "providerSelection"
    property int currentPage: 0
    property var selectedProvider: null
    property string remoteName: ""
    property string searchText: ""
    property bool showAdvancedOptions: false
    property var currentOption: null
    property string currentStateToken: ""
    property string questionAnswer: ""
    property string questionError: ""
    property bool oauthLikely: false
    property bool autoSelectDefault: false
    property bool wizardCreatedRemote: false
    property var acceptedAnswers: ({})

    readonly property var filteredProviders: {
        const query = root.searchText.trim().toLowerCase();
        return RcloneService.providers.filter(provider => {
            if (!provider || provider.Hide === true)
                return false;
            if (query === "")
                return true;
            return String(provider.Name || "").toLowerCase().indexOf(query) >= 0 || String(
                        provider.Description || "").toLowerCase().indexOf(query) >= 0;
        });
    }
    readonly property bool processing: root.wizardState === "processing" || root.wizardState === "cancelling"

    function showWindow() {
        if (!root.parentModal || RcloneService.configBusy)
            return;
        root.resetWizard();
        root.visible = true;
        if (RcloneService.providers.length === 0)
            RcloneService.loadProviders();
        Qt.callLater(() => providerSearch.forceActiveFocus());
    }

    function resetWizard() {
        root.wizardState = RcloneService.providers.length > 0 ? "providerSelection" : "providersLoading";
        root.currentPage = 0;
        root.selectedProvider = null;
        root.remoteName = "";
        root.searchText = "";
        root.showAdvancedOptions = false;
        root.clearQuestion();
        root.oauthLikely = false;
        root.autoSelectDefault = RcloneService.writableRemotes().length === 0;
        root.wizardCreatedRemote = false;
        root.acceptedAnswers = {};
    }

    function clearQuestion() {
        root.currentOption = null;
        root.currentStateToken = "";
        root.questionAnswer = "";
        root.questionError = "";
    }

    function dismiss() {
        root.questionAnswer = "";
        root.acceptedAnswers = {};
        if (RcloneService.configBusy && (RcloneService.configState === "processing"
                                         || RcloneService.configState === "question")) {
            root.wizardState = "cancelling";
            RcloneService.cancelRemoteConfiguration();
            return;
        }
        root.visible = false;
        root.clearQuestion();
    }

    function chooseProvider(provider) {
        root.selectedProvider = provider;
        root.remoteName = "";
        root.wizardState = "remoteName";
        root.currentPage = 1;
        Qt.callLater(() => remoteNameField.fieldItem.forceActiveFocus());
    }

    function remoteNameError() {
        const value = RcloneService.normalizeRemoteName(root.remoteName).trim();
        if (value === "")
            return qsTr("Name cannot be empty");
        if (!RcloneService.validRemoteName(value))
            return qsTr("Names cannot contain a colon or path separator");
        if (RcloneService.remoteByName(value))
            return qsTr("Cloud storage with this name already exists");
        return "";
    }

    function beginConfiguration() {
        const error = root.remoteNameError();
        if (error !== "") {
            remoteNameField.errorText = error;
            return;
        }
        remoteNameField.errorText = "";
        root.remoteName = RcloneService.normalizeRemoteName(root.remoteName).trim();
        root.wizardState = "processing";
        root.currentPage = 2;
        root.wizardCreatedRemote = true;
        if (!RcloneService.startRemoteConfiguration(root.remoteName, String(root.selectedProvider.Name
                                                                            || ""))) {
            root.wizardState = "error";
            root.questionError = qsTr("Could not start cloud storage setup");
        }
    }

    function defaultAnswer(option) {
        if (!option)
            return "";
        if (option.DefaultStr !== undefined && option.DefaultStr !== null)
            return String(option.DefaultStr);
        if (option.Default === undefined || option.Default === null)
            return "";
        if (typeof option.Default === "boolean")
            return option.Default ? "true" : "false";
        return String(option.Default);
    }

    function receiveQuestion() {
        const question = RcloneService.configQuestion;
        if (!question || !question.option)
            return;
        const option = question.option;
        const defaultValue = root.defaultAnswer(option);
        if (String(option.Name || "") === "config_fs_advanced") {
            RcloneService.answerConfigQuestion(question.state, root.showAdvancedOptions ? "true" : "false");
            return;
        }
        if (option.Advanced === true && !root.showAdvancedOptions && (defaultValue !== "" || option.Required
                                                                      !== true)) {
            RcloneService.answerConfigQuestion(question.state, defaultValue);
            return;
        }
        root.currentOption = option;
        root.currentStateToken = String(question.state || "");
        root.questionAnswer = defaultValue;
        root.questionError = String(question.error || "");
        root.wizardState = "question";
        root.currentPage = 2;
        root.oauthLikely = false;
    }

    function isNumericType(type) {
        return ["int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16", "uint32", "uint64",
                "float", "float32", "float64"].indexOf(String(type || "").toLowerCase()) >= 0;
    }

    function answerError() {
        if (!root.currentOption)
            return qsTr("The configuration question is unavailable");
        const answer = String(root.questionAnswer || "");
        if (root.currentOption.Required === true && answer.trim() === "")
            return qsTr("This field is required");
        if (root.isNumericType(root.currentOption.Type) && answer.trim() !== "" && !isFinite(Number(answer)))
            return qsTr("Enter a valid number");
        return "";
    }

    function submitAnswer() {
        const error = root.answerError();
        if (error !== "") {
            root.questionError = error;
            return;
        }
        const optionName = String(root.currentOption.Name || "");
        const answer = String(root.questionAnswer || "");
        if (root.currentOption.IsPassword !== true && root.currentOption.Sensitive !== true) {
            const answers = Object.assign({}, root.acceptedAnswers);
            answers[optionName] = answer;
            root.acceptedAnswers = answers;
        }
        root.oauthLikely = optionName === "config_is_local" && answer === "true";
        root.questionAnswer = "";
        root.questionError = "";
        root.wizardState = "processing";
        RcloneService.answerConfigQuestion(root.currentStateToken, answer);
        root.currentStateToken = "";
        root.currentOption = null;
    }

    function finishWizard() {
        root.visible = false;
        root.clearQuestion();
        root.acceptedAnswers = {};
    }

    visible: false
    parentWindow: root.parentModal
    title: qsTr("Add cloud storage")
    implicitWidth: 720
    implicitHeight: 680
    minimumSize: Qt.size(560, 520)
    color: "transparent"
    onClosed: root.dismiss()

    Connections {
        target: RcloneService

        function onProvidersLoaded() {
            if (root.visible && root.currentPage === 0)
                root.wizardState = "providerSelection";
        }

        function onProvidersLoadFailed(message) {
            if (root.visible) {
                root.wizardState = "error";
                root.questionError = message;
            }
        }

        function onConfigQuestionReady() {
            if (root.visible)
                Qt.callLater(root.receiveQuestion);
        }

        function onConfigSucceeded(remoteName, remoteType) {
            if (!root.visible || remoteName !== root.remoteName)
                return;
            root.wizardState = "success";
            root.currentPage = 3;
            root.clearQuestion();
        }

        function onConfigFailed(message) {
            if (root.visible) {
                root.wizardState = "error";
                root.currentPage = 2;
                root.questionError = message;
                root.questionAnswer = "";
            }
        }

        function onConfigCancelled() {
            if (root.visible && root.wizardState === "cancelling")
                root.finishWizard();
        }

        function onRemotesRevisionChanged() {
            if (root.visible && root.wizardState === "success" && root.autoSelectDefault && RcloneService.remoteByName(
                        root.remoteName)) {
                RcloneService.setDefaultRemote(root.remoteName);
                root.autoSelectDefault = false;
            }
        }
    }

    Rectangle {
        id: windowBackground

        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: BlurService.backgroundColor(Appearance.m3colors.m3surfaceContainerHigh)
    }

    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: windowBackground
        radius: windowBackground.radius
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: event => {
            root.dismiss();
            event.accepted = true;
        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === 0
            hubPage: true
            transitionsEnabled: root.visible

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingXL
                spacing: Metrics.spacingM

                WizardHeader {
                    Layout.fillWidth: true
                    title: qsTr("Add cloud storage")
                    subtitle: qsTr("Choose a service")
                    closeEnabled: !root.processing
                    onCloseRequested: root.dismiss()
                }

                MaterialTextField {
                    id: providerSearch

                    Layout.fillWidth: true
                    labelText: qsTr("Search cloud storage services")
                    text: root.searchText
                    leadingContent: Component {
                        MaterialSymbol {
                            text: "search"
                            iconSize: Metrics.iconM
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                    onTextChanged: root.searchText = text
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible: root.wizardState === "error" || RcloneService.providersError !== ""
                    tone: "error"
                    message: root.questionError || RcloneService.providersError
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    MaterialLoadingIndicator {
                        anchors.centerIn: parent
                        visible: RcloneService.providersLoading
                        accessibleName: qsTr("Loading cloud storage services")
                    }

                    ListView {
                        anchors.fill: parent
                        visible: !RcloneService.providersLoading
                        clip: true
                        spacing: Metrics.spacingXS
                        model: root.filteredProviders

                        delegate: SettingsRow {
                            id: providerRow

                            required property var modelData

                            width: ListView.view.width
                            title: RcloneService.providerDisplayName(String(modelData.Name || ""))
                            interactive: true
                            onClicked: root.chooseProvider(modelData)
                            leading: Component {
                                CloudProviderIcon {
                                    remoteType: String(providerRow.modelData.Name || "")
                                    iconSize: Metrics.iconL
                                }
                            }
                            trailing: MaterialSymbol {
                                text: "chevron_right"
                                iconSize: Metrics.iconM
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === 1
            transitionsEnabled: root.visible

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingXL
                spacing: Metrics.spacingL

                WizardHeader {
                    Layout.fillWidth: true
                    title: qsTr("Add cloud storage")
                    subtitle: root.selectedProvider ? RcloneService.providerDisplayName(String(
                                                                                            root.selectedProvider.Name
                                                                                            || "")) : ""
                    showBack: true
                    onBackRequested: {
                        root.currentPage = 0;
                        root.wizardState = "providerSelection";
                    }
                    onCloseRequested: root.dismiss()
                }

                OutlinedTextField {
                    id: remoteNameField

                    Layout.fillWidth: true
                    labelText: qsTr("Name")
                    text: root.remoteName
                    supportingText: qsTr("Used to identify this cloud storage in Clavis and rclone.")
                    onTextChanged: {
                        root.remoteName = text;
                        errorText = "";
                    }
                    onAccepted: root.beginConfiguration()
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Show advanced options")
                    supportingText: qsTr("Enable only when custom backend settings are needed")
                    trailing: StyledSwitch {
                        checked: root.showAdvancedOptions
                        onToggled: root.showAdvancedOptions = checked
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingS
                    Item {
                        Layout.fillWidth: true
                    }
                    ActionButton {
                        text: qsTr("Cancel")
                        onClicked: root.dismiss()
                    }
                    ActionButton {
                        text: qsTr("Continue")
                        filled: true
                        onClicked: root.beginConfiguration()
                    }
                }
            }
        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === 2
            transitionsEnabled: root.visible

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingXL
                spacing: Metrics.spacingM

                WizardHeader {
                    Layout.fillWidth: true
                    title: root.wizardState === "error" ? qsTr("Setup failed") : qsTr("Setting up")
                    subtitle: root.remoteName
                    closeEnabled: root.wizardState !== "cancelling"
                    onCloseRequested: root.dismiss()
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible: root.questionError !== ""
                    tone: "error"
                    message: root.questionError
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.wizardState === "question"
                    spacing: Metrics.spacingM

                    Text {
                        Layout.fillWidth: true
                        text: root.currentOption ? String(root.currentOption.Name || "") : ""
                        color: Appearance.colors.colOnSurface
                        font.family: Typography.titleLarge.family
                        font.pixelSize: Typography.titleLarge.pixelSize
                        font.weight: Typography.titleLarge.weight
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentOption ? String(root.currentOption.Help || "") : ""
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.bodyMedium.family
                        font.pixelSize: Typography.bodyMedium.pixelSize
                        font.weight: Typography.bodyMedium.weight
                        wrapMode: Text.Wrap
                    }

                    SearchSelectMenuField {
                        Layout.fillWidth: true
                        visible: root.currentOption && Array.isArray(root.currentOption.Examples)
                                 && root.currentOption.Examples.length > 0 && root.currentOption.Exclusive
                                 === true
                        options: root.currentOption && Array.isArray(root.currentOption.Examples)
                                 ? root.currentOption.Examples.map(example => ({
                                     "label": String(example.Help || example.Value || ""),
                                     "value": String(example.Value || "")
                                 })) : []
                        value: root.questionAnswer
                        placeholder: qsTr("Choose an option")
                        closeOnAccept: true
                        onAccepted: value => root.questionAnswer = value
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        visible: root.currentOption && String(root.currentOption.Type || "").toLowerCase()
                                 === "bool" && !(Array.isArray(root.currentOption.Examples)
                                                 && root.currentOption.Examples.length > 0
                                                 && root.currentOption.Exclusive === true)
                        title: root.questionAnswer === "true" ? qsTr("Yes") : qsTr("No")
                        trailing: StyledSwitch {
                            checked: root.questionAnswer === "true"
                            onToggled: root.questionAnswer = checked ? "true" : "false"
                        }
                    }

                    OutlinedTextField {
                        id: answerField

                        Layout.fillWidth: true
                        visible: root.currentOption && !(Array.isArray(root.currentOption.Examples)
                                                         && root.currentOption.Examples.length > 0
                                                         && root.currentOption.Exclusive === true) && String(
                                     root.currentOption.Type || "").toLowerCase() !== "bool"
                        labelText: root.currentOption ? String(root.currentOption.Name || qsTr("Value")) : qsTr(
                                                            "Value")
                        text: root.questionAnswer
                        passwordToggle: root.currentOption ? root.currentOption.IsPassword === true
                                                             || root.currentOption.Sensitive === true : false
                        inputMethodHints: root.currentOption && root.isNumericType(root.currentOption.Type)
                                          ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
                        supportingText: root.currentOption && Array.isArray(root.currentOption.Examples)
                                        && root.currentOption.Examples.length > 0 ? qsTr(
                                                                                        "You can also enter a custom value") :
                                                                                    ""
                        errorText: root.questionError
                        onTextChanged: {
                            root.questionAnswer = text;
                            if (root.questionError !== String(RcloneService.configQuestion
                                                              && RcloneService.configQuestion.error || ""))
                                root.questionError = "";
                        }
                        onAccepted: root.submitAnswer()
                    }

                    SearchSelectMenuField {
                        Layout.fillWidth: true
                        visible: root.currentOption && Array.isArray(root.currentOption.Examples)
                                 && root.currentOption.Examples.length > 0 && root.currentOption.Exclusive
                                 !== true
                        options: root.currentOption && Array.isArray(root.currentOption.Examples)
                                 ? root.currentOption.Examples.map(example => ({
                                     "label": String(example.Help || example.Value || ""),
                                     "value": String(example.Value || "")
                                 })) : []
                        value: ""
                        placeholder: qsTr("Use a suggested value")
                        closeOnAccept: true
                        onAccepted: value => root.questionAnswer = value
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingS
                        Item {
                            Layout.fillWidth: true
                        }
                        ActionButton {
                            text: qsTr("Cancel")
                            onClicked: root.dismiss()
                        }
                        ActionButton {
                            text: qsTr("Continue")
                            filled: true
                            onClicked: root.submitAnswer()
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.wizardState === "processing" || root.wizardState === "cancelling"
                    spacing: Metrics.spacingM

                    Item {
                        Layout.fillHeight: true
                    }
                    MaterialLoadingIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        accessibleName: root.oauthLikely ? qsTr("Completing authorization") : qsTr(
                                                               "Setting up")
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.wizardState === "cancelling" ? qsTr("Cancelling setup…") :
                                                                  root.oauthLikely ? qsTr(
                                                                                         "Completing authorization") :
                                                                                     qsTr("Applying configuration…")
                        color: Appearance.colors.colOnSurface
                        font.family: Typography.titleMedium.family
                        font.pixelSize: Typography.titleMedium.pixelSize
                        font.weight: Typography.titleMedium.weight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: root.oauthLikely && root.wizardState !== "cancelling"
                        text: qsTr(
                                  "If a browser opened, complete sign-in and authorization there. Clavis will continue automatically afterward.")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Typography.bodyMedium.family
                        font.pixelSize: Typography.bodyMedium.pixelSize
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                    ActionButton {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.wizardState !== "cancelling"
                        text: qsTr("Cancel")
                        onClicked: root.dismiss()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.wizardState === "error"
                    spacing: Metrics.spacingM
                    Item {
                        Layout.fillHeight: true
                    }
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "cloud_off"
                        iconSize: Metrics.touchTarget
                        color: Appearance.colors.colError
                    }
                    ActionButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Done")
                        filled: true
                        onClicked: root.finishWizard()
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }

        PageTransitionLayer {
            anchors.fill: parent
            active: root.currentPage === 3
            transitionsEnabled: root.visible

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingXL
                spacing: Metrics.spacingM

                WizardHeader {
                    Layout.fillWidth: true
                    title: qsTr("Cloud storage connected")
                    onCloseRequested: root.finishWizard()
                }

                Item {
                    Layout.fillHeight: true
                }
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "cloud_done"
                    iconSize: Metrics.touchTarget
                    fill: 1
                    color: Appearance.colors.colPrimary
                }
                Text {
                    Layout.fillWidth: true
                    text: root.selectedProvider ? qsTr("%1 is connected").arg(
                                                      RcloneService.providerDisplayName(String(
                                                                                            root.selectedProvider.Name
                                                                                            || ""))) : qsTr(
                                                      "Cloud storage connected")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.headlineSmall.family
                    font.pixelSize: Typography.headlineSmall.pixelSize
                    font.weight: Typography.headlineSmall.weight
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: root.remoteName + "\n" + (root.selectedProvider ? String(root.selectedProvider.Name
                                                                                   || "") : "")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Typography.bodyLarge.family
                    font.pixelSize: Typography.bodyLarge.pixelSize
                    horizontalAlignment: Text.AlignHCenter
                }
                Item {
                    Layout.fillHeight: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingS
                    Item {
                        Layout.fillWidth: true
                    }
                    ActionButton {
                        visible: !root.autoSelectDefault && RcloneService.selectedRemoteName
                                 !== root.remoteName
                        enabled: RcloneService.remoteByName(root.remoteName) !== null
                        text: qsTr("Set as default cloud storage")
                        onClicked: {
                            RcloneService.setDefaultRemote(root.remoteName);
                            root.finishWizard();
                        }
                    }
                    ActionButton {
                        text: qsTr("Done")
                        filled: true
                        onClicked: root.finishWizard()
                    }
                }
            }
        }
    }
}
