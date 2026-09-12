import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: panelRoot

    title: qsTr("Idle management")
    icon: "schedule"
    showBackButton: true
    backAction: () => WidgetState.quickSettingsView = "settings"

    property bool foreground: false
    property bool isActive: foreground && WidgetState.quickSettingsView === "idle"
    property string expandedStage: ""
    property real pendingDimFraction: IdleService.dimFraction
    readonly property var timeoutPresetSeconds: [60, 120, 300, 600, 900, 1800, 3600, 7200]

    function formatTimeout(seconds) {
        const value = Math.max(0, Number(seconds || 0));
        if (value < 60)
            return Math.round(value) + qsTr(" seconds");
        const minutes = value / 60;
        return (Math.abs(minutes - Math.round(minutes)) < 0.001 ? Math.round(minutes) : minutes.toFixed(1)) + qsTr(
                    " minutes");
    }

    function timeoutOptions(currentSeconds) {
        const values = timeoutPresetSeconds.slice();
        const current = Math.max(0, Number(currentSeconds || 0));
        if (current > 0 && values.indexOf(current) === -1)
            values.push(current);
        values.sort((a, b) => a - b);
        return values.map(value => ({
            "seconds": value,
            "label": panelRoot.formatTimeout(value)
        }));
    }

        function stageActive(name) {
        const stage = IdleService.stages.find(candidate => candidate.name === name);
        return stage ? !!stage.active : false;
    }

        function policySummary() {
        if (!IdleService.policyEnabled)
        return qsTr("Paused");
        const enabledCount = IdleService.stages.filter(stage => stage.enabled).length;
        return enabledCount + qsTr(" enabled");
    }

        onIsActiveChanged: {
        if (!isActive)
        expandedStage = "";
    }

        Timer {
        id: dimFractionCommitTimer
        interval: 250
        repeat: false
        onTriggered: IdleService.setDimFraction(panelRoot.pendingDimFraction)
    }

        ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        ProgressBar {
        Layout.fillWidth: true
        Layout.preferredHeight: (!IdleService.policyReady || IdleService.busy) ? 4 : 0
        opacity: (!IdleService.policyReady || IdleService.busy) ? 1 : 0
        indeterminate: true
        Material.accent: Appearance.colors.colPrimary

        Behavior on Layout.preferredHeight {
        ElementMoveAnimation {}
    }
        Behavior on opacity {
        ElementMoveAnimation {}
    }
    }

        InlineStatusBanner {
        Layout.fillWidth: true
        visible: IdleService.lastError.length > 0
        tone: "error"
        message: IdleService.lastError
    }

        StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: idleContent.implicitHeight

        ColumnLayout {
        id: idleContent

        width: parent.width - Appearance.spacing.small
        spacing: Appearance.spacing.small

        SettingsSection {
        Layout.fillWidth: true

        SettingsRow {
        Layout.fillWidth: true
        iconName: "coffee"
        title: qsTr("Keep awake")
        highlighted: IdleService.inhibited

        trailing: StyledSwitch {
        scale: 0.78
        checked: IdleService.inhibited
        enabled: !IdleService.busy
        Accessible.name: qsTr("Keep awake")
        onToggled: IdleService.setInhibited(checked)
    }
    }

        SettingsRow {
        Layout.fillWidth: true
        iconName: "schedule"
        title: qsTr("Automatic idle")
        supportingText: panelRoot.policySummary()
        highlighted: IdleService.policyEnabled

        trailing: StyledSwitch {
        scale: 0.78
        checked: IdleService.policyEnabled
        enabled: IdleService.policyReady
        Accessible.name: qsTr("Automatic idle")
        onToggled: IdleService.setPolicyEnabled(checked)
    }
    }
    }

        SettingsSection {
        Layout.fillWidth: true
        title: qsTr("Idle actions")

        StageEditor {
        Layout.fillWidth: true
        stageName: "dim"
        stageTitle: qsTr("Dim screen")
        stageIcon: "brightness_4"
        showDimFraction: true
    }

        StageEditor {
        Layout.fillWidth: true
        stageName: "lock"
        stageTitle: qsTr("Lock session")
        stageIcon: "lock"
    }

        StageEditor {
        Layout.fillWidth: true
        stageName: "displayOff"
        stageTitle: qsTr("Turn off displays")
        stageIcon: "display_settings"
    }

        StageEditor {
        Layout.fillWidth: true
        stageName: "suspend"
        stageTitle: qsTr("Suspend system")
        stageIcon: "mode_standby"
    }
    }

        Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Appearance.spacing.small
    }
    }
    }
    }

        component StageEditor: Item {
        id: stageEditor

        required property string stageName
        required property string stageTitle
        required property string stageIcon
        property bool showDimFraction: false
        readonly property bool expanded: panelRoot.expandedStage === stageName
        readonly property bool stageEnabled: !!IdleService[stageName + "Enabled"]
        readonly property real stageTimeout: Number(IdleService[stageName + "Timeout"] || 0)
        readonly property bool respectInhibitors: !!IdleService[stageName + "RespectInhibitors"]

        implicitHeight: stageLayout.implicitHeight

        ColumnLayout {
        id: stageLayout

        width: parent.width
        spacing: Appearance.spacing.xSmall

        SettingsRow {
        Layout.fillWidth: true
        iconName: stageEditor.stageIcon
        title: stageEditor.stageTitle
        supportingText: (stageEditor.stageEnabled ? panelRoot.formatTimeout(stageEditor.stageTimeout) : qsTr(
        "Off")) + (panelRoot.stageActive(stageEditor.stageName) ? qsTr(" · Triggered") : "")
        interactive: true
        highlighted: stageEditor.stageEnabled && IdleService.policyEnabled
        onClicked: panelRoot.expandedStage = stageEditor.expanded ? "" : stageEditor.stageName

        trailing: RowLayout {
        spacing: Appearance.spacing.xSmall

        MaterialSymbol {
        text: "expand_more"
        iconSize: 20
        color: Appearance.colors.colOnLayer1
        rotation: stageEditor.expanded ? 180 : 0

        Behavior on rotation {
        ElementMoveAnimation {}
    }
    }

        StyledSwitch {
        scale: 0.72
        checked: stageEditor.stageEnabled
        enabled: IdleService.policyReady
        Accessible.name: stageEditor.stageTitle
        onToggled: IdleService.configureStage(stageEditor.stageName, checked, stageEditor.stageTimeout,
        stageEditor.respectInhibitors)
    }
    }
    }

        Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: stageEditor.expanded ? stageDetails.implicitHeight
        + Appearance.spacing.medium * 2 : 0
        opacity: stageEditor.expanded ? 1 : 0
        enabled: stageEditor.expanded
        clip: true
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer2

        Behavior on Layout.preferredHeight {
        ElementMoveAnimation {}
    }
        Behavior on opacity {
        ElementMoveAnimation {}
    }

        ColumnLayout {
        id: stageDetails

        anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        margins: Appearance.spacing.medium
    }
        spacing: Appearance.spacing.small

        RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        Text {
        Layout.fillWidth: true
        text: qsTr("Wait time")
        color: Appearance.colors.colOnLayer2
        font.family: Fonts.ui
        font.pixelSize: 13
    }

        SearchSelectMenuField {
        Layout.preferredWidth: 144
        Layout.preferredHeight: 40
        options: panelRoot.timeoutOptions(stageEditor.stageTimeout)
        value: String(stageEditor.stageTimeout)
        textRole: "label"
        valueRole: "seconds"
        maxVisibleItems: 5
        popupBoundsItem: panelRoot
        closeOnAccept: true
        Accessible.name: qsTr("%1 wait time").arg(stageEditor.stageTitle)
        onAccepted: value => IdleService.configureStage(stageEditor.stageName, stageEditor.stageEnabled,
        Number(value), stageEditor.respectInhibitors)
    }
    }

        RowLayout {
        Layout.fillWidth: true
        visible: stageEditor.showDimFraction
        spacing: Appearance.spacing.small

        Text {
        text: qsTr("Dim percentage")
        color: Appearance.colors.colOnLayer2
        font.family: Fonts.ui
        font.pixelSize: 13
    }

        Loader {
        id: dimFractionSliderLoader

        Layout.fillWidth: true
        Layout.minimumWidth: 148
        active: stageEditor.showDimFraction
        sourceComponent: dimFractionSliderComponent
    }
    }

        SettingsRow {
        Layout.fillWidth: true
        iconName: "coffee"
        title: qsTr("Skip while keeping awake")

        trailing: StyledSwitch {
        scale: 0.68
        checked: stageEditor.respectInhibitors
        enabled: IdleService.policyReady
        Accessible.name: qsTr("%1: respect keep-awake").arg(stageEditor.stageTitle)
        onToggled: IdleService.configureStage(stageEditor.stageName, stageEditor.stageEnabled,
        stageEditor.stageTimeout, checked)
    }
    }
    }
    }
    }

        Component {
        id: dimFractionSliderComponent

        MaterialSplitSlider {
        id: dimFractionSlider

        width: parent ? parent.width : implicitWidth
        configuration: MaterialSplitSlider.Configuration.XS
        from: 0.1
        to: 0.8
        stepSize: 0.05
        stopIndicatorValues: []
        showTooltipOnHover: true
        usePercentTooltip: false
        tooltipContent: Math.round(value * 100) + "%"
        Accessible.name: qsTr("Screen dim percentage")

        Binding {
        target: dimFractionSlider
        property: "value"
        value: IdleService.dimFraction
        when: !dimFractionSlider.pressed
    }

        onMoved: {
        panelRoot.pendingDimFraction = value;
        dimFractionCommitTimer.restart();
    }
    }
    }
    }
    }
