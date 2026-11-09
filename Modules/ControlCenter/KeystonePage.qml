import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Components
import qs.Modules.FilePicker
import qs.Widgets.common

Item {
    id: root

    property int searchRequestSerial: -1
    readonly property var searchLeaf: currentSection === "overview" ? overviewFlickable : pageLoader.item ? (
                                                                                                                pageLoader.item.searchLeaf
                                                                                                                || pageLoader.item) :
                                                                                                            root
    function openSearchPath(path, serial) {
        const section = path.length ? path[0] : "overview";
        if (searchRequestSerial !== serial) {
            searchRequestSerial = serial;
            root.currentSection = section;
        }
        if (root.currentSection !== section)
            return "cancelled";
        if (section === "overview")
            return "ready";
        if (!(pageLoader.status === Loader.Ready) || !pageLoader.item)
            return "loading";
        return typeof pageLoader.item.openSearchPath === "function" ? pageLoader.item.openSearchPath(
                                                                          path.slice(1), serial) : "ready";
    }

    property var parentModal: null
    onCurrentSectionChanged: {
        if (ControlCenterService.searchTarget && !ControlCenterService.applyingSearch && searchRequestSerial
                === ControlCenterService.searchSerial)
            ControlCenterService.cancelSearch();
        ControlCenterService.retrySearch();
    }
    property string currentSection: "overview"
    property string editingDirectoryKey: ""
    property var editingDirectoryField: null

    function directoryValue(key) {
        return String(UiPreferences[key] || "");
    }

    function saveDirectory(key, value, field) {
        UiPreferences.setRecordingDirectory(key, value);
        if (field)
            field.text = root.directoryValue(key);
    }

    function openDirectoryPicker(key, field) {
        root.saveDirectory(key, field.text, field);
        root.editingDirectoryKey = key;
        root.editingDirectoryField = field;
        directoryPicker.openAt(root.directoryValue(key));
    }

    function openSection(section) {
        root.currentSection = String(section || "overview");
    }

    function showOverview() {
        root.currentSection = "overview";
    }

    function closeChildWindows() {
        root.showOverview();
        directoryPicker.dismiss();
    }

    GeneralSubpageHeader {
        id: subpageHeader

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.currentSection !== "overview"
        title: SpotlightCatalog.title("keystone." + root.currentSection)
        backAccessibleName: qsTr("Back to Keystone settings")
        z: 2
        onBackRequested: root.showOverview()
    }

    StyledFlickable {
        id: overviewFlickable

        anchors.fill: parent
        visible: root.currentSection === "overview"
        contentWidth: width
        contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

        ColumnLayout {
            id: contentColumn

            width: Math.min(600, Math.max(1, overviewFlickable.width - 48))
            x: Math.max(24, (overviewFlickable.width - width) / 2)
            y: 28
            spacing: 30

            KeystoneSection {
                id: searchSection0
                title: searchAnchor0.title
                SettingsSearchAnchor {
                    id: searchAnchor0
                    target: searchSection0
                    declaration:
                        '{"id":"keystone.section.keystone-style","route":"keystone","title":"Keystone style","context":"KeystonePage","icon":"toggle_off","aliases":[]}'
                }
                iconName: "toggle_off"

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Show Keystone")
                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneEnabled
                        Accessible.name: qsTr("Show Keystone")
                        onToggled: PersonalizationConfig.setValue("keystoneEnabled", checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Floating")
                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneOverlay
                        Accessible.name: qsTr("Floating")
                        onToggled: PersonalizationConfig.setValue("keystoneOverlay", checked)
                    }
                }

                SearchSelectSettingRow {
                    title: qsTr("Style")
                    options: PersonalizationConfig.keystoneStyles
                    value: PersonalizationConfig.keystoneStyle
                    placeholder: qsTr("Choose Keystone style")
                    onAccepted: value => {
                        return PersonalizationConfig.setKeystoneStyle(value);
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Full display")
                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneFullDisplay
                        Accessible.name: qsTr("Full display")
                        onToggled: PersonalizationConfig.setValue("keystoneFullDisplay", checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Screen edge")

                    trailing: EdgePositionSelector {
                        position: PersonalizationConfig.keystonePosition
                        onPositionSelected: position => {
                            return PersonalizationConfig.setKeystonePosition(position);
                        }
                    }
                }
            }

            KeystoneSection {
                id: dimensionsSection
                Layout.fillWidth: true
                title: dimensionsSearchAnchor.title
                iconName: "space_bar"
                SettingsSearchAnchor {
                    id: dimensionsSearchAnchor
                    target: dimensionsSection
                    declaration:
                        '{"id":"keystone.section.size-spacing","route":"keystone","title":"Size and spacing","context":"KeystonePage","icon":"space_bar","aliases":[]}'
                }

                GeneralSliderSetting {
                    title: qsTr("Edge spacing")
                    value: PersonalizationConfig.keystoneStyle === "pill"
                           ? PersonalizationConfig.keystoneEdgeSpacing : 0
                    from: PersonalizationConfig.keystoneDimensionLimits.edgeSpacing[1]
                    to: PersonalizationConfig.keystoneDimensionLimits.edgeSpacing[2]
                    suffix: qsTr(" px")
                    enabled: PersonalizationConfig.keystoneStyle === "pill"
                    onMoved: value => PersonalizationConfig.setPanelDimension("keystone", "edgeSpacing",
                                                                              value)
                }

                GeneralSliderSetting {
                    title: qsTr("Exclusive zone offset")
                    value: PersonalizationConfig.keystoneExclusiveZoneOffset
                    from: PersonalizationConfig.keystoneDimensionLimits.exclusiveZoneOffset[1]
                    to: PersonalizationConfig.keystoneDimensionLimits.exclusiveZoneOffset[2]
                    suffix: qsTr(" px")
                    enabled: !PersonalizationConfig.keystoneOverlay
                    onMoved: value => PersonalizationConfig.setPanelDimension("keystone",
                                                                              "exclusiveZoneOffset", value)
                }

                GeneralSliderSetting {
                    title: qsTr("Size")
                    value: PersonalizationConfig.keystoneThickness
                    from: PersonalizationConfig.keystoneDimensionLimits.thickness[1]
                    to: PersonalizationConfig.keystoneDimensionLimits.thickness[2]
                    suffix: qsTr(" px")
                    onMoved: value => PersonalizationConfig.setPanelDimension("keystone", "thickness", value)
                }

                GeneralSliderSetting {
                    title: qsTr("Clock padding")
                    value: PersonalizationConfig.keystoneClockPadding
                    from: PersonalizationConfig.keystoneDimensionLimits.clockPadding[1]
                    to: PersonalizationConfig.keystoneDimensionLimits.clockPadding[2]
                    suffix: qsTr(" px")
                    onMoved: value => PersonalizationConfig.setPanelDimension("keystone", "clockPadding",
                                                                              value)
                }

                GeneralSliderSetting {
                    title: qsTr("Inset padding")
                    value: PersonalizationConfig.keystoneInsetPadding
                    from: PersonalizationConfig.keystoneDimensionLimits.insetPadding[1]
                    to: PersonalizationConfig.keystoneDimensionLimits.insetPadding[2]
                    suffix: qsTr(" px")
                    enabled: PersonalizationConfig.keystoneFullDisplay
                    onMoved: value => PersonalizationConfig.setPanelDimension("keystone", "insetPadding",
                                                                              value)
                }

                GeneralSliderSetting {
                    title: qsTr("Item spacing")
                    value: PersonalizationConfig.keystoneItemSpacing
                    from: PersonalizationConfig.keystoneDimensionLimits.itemSpacing[1]
                    to: PersonalizationConfig.keystoneDimensionLimits.itemSpacing[2]
                    suffix: qsTr(" px")
                    enabled: PersonalizationConfig.keystoneFullDisplay
                    onMoved: value => PersonalizationConfig.setPanelDimension("keystone", "itemSpacing",
                                                                              value)
                }

                GeneralSliderSetting {
                    title: qsTr("Popup gap")
                    value: PersonalizationConfig.keystonePopupGap
                    from: PersonalizationConfig.keystoneDimensionLimits.popupGap[1]
                    to: PersonalizationConfig.keystoneDimensionLimits.popupGap[2]
                    suffix: qsTr(" px")
                    enabled: PersonalizationConfig.keystoneFullDisplay
                    onMoved: value => PersonalizationConfig.setPanelDimension("keystone", "popupGap", value)
                }
            }

            KeystoneSection {
                id: searchSection1
                title: searchAnchor1.title
                SettingsSearchAnchor {
                    id: searchAnchor1
                    target: searchSection1
                    declaration:
                        '{"id":"keystone.section.mouse-actions","route":"keystone","title":"Mouse actions","context":"KeystonePage","icon":"toggle_off","aliases":[]}'
                }
                iconName: "mouse"

                SearchSelectSettingRow {
                    title: qsTr("Hover")
                    options: PersonalizationConfig.availableKeystoneHoverActionOptions
                    value: PersonalizationConfig.effectiveKeystoneHoverAction
                    onAccepted: value => PersonalizationConfig.setKeystoneAction("hover", value)
                }

                GeneralSliderSetting {
                    title: qsTr("Hover open delay")
                    value: PersonalizationConfig.keystoneHoverOpenDelay
                    from: 0
                    to: 500
                    stepSize: 25
                    suffix: qsTr(" ms")
                    enabled: PersonalizationConfig.effectiveKeystoneHoverAction !== "none"
                    onMoved: value => PersonalizationConfig.setKeystoneHoverOpenDelay(value)
                }

                GeneralSliderSetting {
                    title: qsTr("Hover close delay")
                    value: PersonalizationConfig.keystoneHoverCloseDelay
                    from: 0
                    to: 600
                    stepSize: 25
                    suffix: qsTr(" ms")
                    enabled: PersonalizationConfig.effectiveKeystoneHoverAction !== "none"
                    onMoved: value => PersonalizationConfig.setKeystoneHoverCloseDelay(value)
                }

                SearchSelectSettingRow {
                    title: qsTr("Left click")
                    options: PersonalizationConfig.keystoneActionOptions
                    value: PersonalizationConfig.keystoneLeftClickAction
                    onAccepted: value => PersonalizationConfig.setKeystoneAction("left", value)
                }

                SearchSelectSettingRow {
                    title: qsTr("Middle click")
                    options: PersonalizationConfig.keystoneActionOptions
                    value: PersonalizationConfig.keystoneMiddleClickAction
                    onAccepted: value => PersonalizationConfig.setKeystoneAction("middle", value)
                }
            }

            KeystoneSection {
                id: mediaSection
                title: mediaSearchAnchor.title
                iconName: "music_note"

                SettingsSearchAnchor {
                    id: mediaSearchAnchor
                    target: mediaSection
                    declaration:
                        '{"id":"keystone.section.media-controls","route":"keystone","title":"Media controls","context":"KeystonePage","icon":"music_note","aliases":[]}'
                }

                SearchSelectSettingRow {
                    title: qsTr("Progress bar")
                    options: PersonalizationConfig.keystoneMediaProgressOptions
                    value: PersonalizationConfig.keystoneMediaProgressStyle
                    onAccepted: value => PersonalizationConfig.setKeystoneMediaProgressStyle(value)
                }

                SearchSelectSettingRow {
                    title: qsTr("Cover style")
                    options: PersonalizationConfig.keystoneMediaCoverOptions
                    value: PersonalizationConfig.keystoneMediaCoverStyle
                    onAccepted: value => PersonalizationConfig.setKeystoneMediaCoverStyle(value)
                }

                SearchSelectSettingRow {
                    title: qsTr("Colors")
                    options: PersonalizationConfig.keystoneMediaColorOptions
                    value: PersonalizationConfig.keystoneMediaColorStyle
                    onAccepted: value => PersonalizationConfig.setKeystoneMediaColorStyle(value)
                }
            }

            KeystoneSection {
                visible: PersonalizationConfig.keystoneFullDisplay
                title: qsTr("Status items")
                iconName: "view_week"

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Show device names")
                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneFullShowNames
                        Accessible.name: qsTr("Show device names")
                        onToggled: PersonalizationConfig.setKeystoneFullShowNames(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Show system monitor values")
                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneFullShowMonitorValues
                        Accessible.name: qsTr("Show system monitor values")
                        onToggled: PersonalizationConfig.setKeystoneFullShowMonitorValues(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Show numeric values")
                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneFullShowValues
                        Accessible.name: qsTr("Show numeric values")
                        onToggled: PersonalizationConfig.setKeystoneFullShowValues(checked)
                    }
                }

                SettingsRow {
                    id: fullLeadingFieldRow
                    Layout.fillWidth: true
                    title: PersonalizationConfig.keystonePosition === "top"
                           || PersonalizationConfig.keystonePosition === "bottom" ? qsTr("Left") : qsTr("Top")
                    trailing: SortableMultiSelectField {
                        id: fullLeadingField
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: Math.max(0, fullLeadingFieldRow.width - 96 - 3
                                                        * Metrics.spacingS)
                        values: PersonalizationConfig.keystoneFullLeading
                        options: PersonalizationConfig.keystoneFullItemOptions
                        zone: "leading"
                        dragCoordinator: fullDragCoordinator
                        onToggled: itemId => PersonalizationConfig.toggleKeystoneFullItem(itemId, zone)
                        onRemoved: itemId => PersonalizationConfig.removeKeystoneFullItem(itemId)
                    }
                }

                SettingsRow {
                    id: fullTrailingFieldRow
                    Layout.fillWidth: true
                    title: PersonalizationConfig.keystonePosition === "top"
                           || PersonalizationConfig.keystonePosition === "bottom" ? qsTr("Right") : qsTr(
                                                                                        "Bottom")
                    trailing: SortableMultiSelectField {
                        id: fullTrailingField
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: Math.max(0, fullTrailingFieldRow.width - 96 - 3
                                                        * Metrics.spacingS)
                        values: PersonalizationConfig.keystoneFullTrailing
                        options: PersonalizationConfig.keystoneFullItemOptions
                        zone: "trailing"
                        dragCoordinator: fullDragCoordinator
                        onToggled: itemId => PersonalizationConfig.toggleKeystoneFullItem(itemId, zone)
                        onRemoved: itemId => PersonalizationConfig.removeKeystoneFullItem(itemId)
                    }
                }
            }

            KeystoneSection {
                id: extraSearchSection0
                visible: KeyboardLockService.available
                title: extraSearchAnchor0.title
                SettingsSearchAnchor {
                    id: extraSearchAnchor0
                    target: extraSearchSection0
                    declaration:
                        '{"id":"keystone.section.keyboard-indicators","route":"keystone","title":"Keyboard indicators","context":"KeystonePage","icon":"settings","aliases":[],"availability":"keyboard-lock"}'
                }
                iconName: "keyboard"

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Caps Lock changes")
                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneCapsLockOsd
                        Accessible.name: qsTr("Caps Lock changes")
                        onToggled: PersonalizationConfig.setKeystoneCapsLockOsd(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Num Lock changes")
                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneNumLockOsd
                        Accessible.name: qsTr("Num Lock changes")
                        onToggled: PersonalizationConfig.setKeystoneNumLockOsd(checked)
                    }
                }
            }

            KeystoneSection {
                id: extraSearchSection1
                title: extraSearchAnchor1.title
                SettingsSearchAnchor {
                    id: extraSearchAnchor1
                    target: extraSearchSection1
                    declaration:
                        '{"id":"keystone.section.keyhole","route":"keystone","title":"Keyhole","context":"KeystonePage","icon":"settings","aliases":[]}'
                }
                iconName: "dashboard"

                SearchSelectSettingRow {
                    title: qsTr("Card")
                    closeOnAccept: true
                    options: PersonalizationConfig.keystoneKeyholeCardOptions
                    value: PersonalizationConfig.keystoneKeyholeCard
                    onAccepted: value => PersonalizationConfig.setKeystoneKeyholeCard(value)
                }
            }

            KeystoneSection {
                id: searchSection2
                title: searchAnchor2.title
                SettingsSearchAnchor {
                    id: searchAnchor2
                    target: searchSection2
                    declaration:
                        '{"id":"keystone.section.horizontal-clock","route":"keystone","title":"Horizontal clock","context":"KeystonePage","icon":"toggle_off","aliases":[]}'
                }
                iconName: "schedule"

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(66, (width - 8) * 42 / 220 + 12)

                    HorizontalClockPreview {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("Hide date")

                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneHideDate
                        Accessible.name: qsTr("Hide date")
                        onToggled: PersonalizationConfig.setKeystoneHideDate(checked)
                    }
                }

                SettingsActionRow {
                    Layout.fillWidth: true
                    iconName: "tune"
                    text: qsTr("Horizontal clock style")
                    description: qsTr("Font, digit positions, and colors")
                    trailingIconName: "chevron_right"
                    onClicked: root.openSection("horizontal-clock")
                }
            }

            KeystoneSection {
                id: searchSection3
                title: searchAnchor3.title
                SettingsSearchAnchor {
                    id: searchAnchor3
                    target: searchSection3
                    declaration:
                        '{"id":"keystone.section.recording","route":"keystone","title":"Recording","context":"KeystonePage","icon":"toggle_off","aliases":[]}'
                }
                iconName: "video_camera_front"

                RecordingDirectoryField {
                    settingTitle: qsTr("Video recording")
                    settingKey: "recordingVideoDirectory"
                    value: UiPreferences.recordingVideoDirectory
                }

                RecordingDirectoryField {
                    settingTitle: qsTr("GIF recording")
                    settingKey: "recordingGifDirectory"
                    value: UiPreferences.recordingGifDirectory
                }

                RecordingDirectoryField {
                    settingTitle: qsTr("Microphone recording")
                    settingKey: "recordingMicrophoneDirectory"
                    value: UiPreferences.recordingMicrophoneDirectory
                }

                RecordingDirectoryField {
                    settingTitle: qsTr("System audio recording")
                    settingKey: "recordingSystemAudioDirectory"
                    value: UiPreferences.recordingSystemAudioDirectory
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
            }
        }
    }

    Loader {
        id: pageLoader
        onLoaded: ControlCenterService.retrySearch()

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: subpageHeader.bottom
        anchors.bottom: parent.bottom
        visible: root.currentSection !== "overview"
        source: {
            const route = SpotlightCatalog.route("keystone." + root.currentSection);
            return route ? Qt.resolvedUrl(route.source) : "";
        }
    }

    BarLayoutDragCoordinator {
        id: fullDragCoordinator
        anchors.fill: parent
        z: 1001
        fields: [fullLeadingField, fullTrailingField]
        onDropped: (itemId, targetZone, targetIndex) => PersonalizationConfig.moveKeystoneFullItem(itemId,
                                                                                                   targetZone,
                                                                                                   targetIndex)
    }

    FilePickerWindow {
        id: directoryPicker

        parentModal: root.parentModal
        requiresParentWindow: true
        selectionMode: FilePickerWindow.Folders
        allowCurrentFolderSelection: true
        dialogTitle: qsTr("Save location")
        description: root.editingDirectoryField ? root.editingDirectoryField.settingTitle : ""
        nameFilters: []
        windowIconName: "folder_open"
        emptyStateText: qsTr("This folder is empty")
        selectionPrompt: qsTr("Choose folder")
        acceptLabel: qsTr("Choose")
        formatSummary: qsTr("Choose the current folder or a selected subfolder")
        onAccepted: function (path, isDirectory) {
            if (isDirectory && root.editingDirectoryKey !== "")
                root.saveDirectory(root.editingDirectoryKey, path, root.editingDirectoryField);

            root.editingDirectoryKey = "";
            root.editingDirectoryField = null;
        }
        onRejected: {
            root.editingDirectoryKey = "";
            root.editingDirectoryField = null;
        }
    }

    component RecordingDirectoryField: ColumnLayout {
        id: directorySetting

        property string settingTitle: ""
        property string settingKey: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.leftMargin: Metrics.spacingS
        Layout.rightMargin: Metrics.spacingS
        spacing: Metrics.spacingXS

        Text {
            Layout.fillWidth: true
            text: directorySetting.settingTitle
            color: Appearance.colors.colOnSurface
            font.family: Typography.titleSmall.family
            font.pixelSize: Typography.titleSmall.pixelSize
            font.weight: Typography.titleSmall.weight
            elide: Text.ElideRight
        }

        MaterialFilledTextField {
            id: directoryField

            Layout.fillWidth: true
            labelText: qsTr("Save location")
            text: directorySetting.value
            trailingContentWidth: Metrics.touchTarget
            onAccepted: root.saveDirectory(directorySetting.settingKey, text, directoryField)
            onEditingFinished: root.saveDirectory(directorySetting.settingKey, text, directoryField)

            trailingContent: Component {
                IconButton {
                    anchors.centerIn: parent
                    iconName: "folder_open"
                    accessibleName: qsTr("Choose folder")
                    tooltipText: qsTr("Choose folder")
                    controlSize: Metrics.touchTarget
                    onClicked: root.openDirectoryPicker(directorySetting.settingKey, directoryField)
                }
            }
        }
    }

    component SearchSelectSettingRow: Item {
        id: selectRow

        property string title: ""
        property string description: ""
        property var options: []
        property string value: ""
        property string placeholder: ""
        property int fieldWidth: 240
        property bool closeOnAccept: true

        signal accepted(string value)

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(58, selectLabelColumn.implicitHeight + 16)

        RowLayout {
            anchors.fill: parent
            spacing: 16

            Column {
                id: selectLabelColumn

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: selectRow.title
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: selectRow.description
                    color: Appearance.colors.colSubtext
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }

            SearchSelectMenuField {
                Layout.preferredWidth: selectRow.fieldWidth
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                options: selectRow.options
                closeOnAccept: selectRow.closeOnAccept
                value: selectRow.value
                placeholder: selectRow.placeholder
                textRole: "label"
                valueRole: "value"
                onAccepted: value => {
                    return selectRow.accepted(value);
                }
            }
        }
    }
}
