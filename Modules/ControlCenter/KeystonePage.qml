import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Components
import qs.Modules.FilePicker
import qs.Widgets.common

Item {
    id: root

    property var parentModal: null
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
        title: qsTr("横向时钟样式")
        backAccessibleName: qsTr("返回钥石设置")
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
                title: qsTr("钥石样式")
                iconName: "toggle_off"

                SearchSelectSettingRow {
                    title: qsTr("样式")
                    options: PersonalizationConfig.keystoneStyles
                    value: PersonalizationConfig.keystoneStyle
                    placeholder: qsTr("选择钥石样式")
                    onAccepted: (value) => {
                        return PersonalizationConfig.setKeystoneStyle(value);
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("屏幕边缘")

                    trailing: EdgePositionSelector {
                        position: PersonalizationConfig.keystonePosition
                        onPositionSelected: (position) => {
                            return PersonalizationConfig.setKeystonePosition(position);
                        }
                    }

                }

            }

            KeystoneSection {
                title: qsTr("钥匙孔")
                iconName: "view_carousel"

                SortableMultiSelectField {
                    id: keyholeCardsField

                    Layout.fillWidth: true
                    Layout.leftMargin: Metrics.spacingS
                    Layout.rightMargin: Metrics.spacingS
                    values: PersonalizationConfig.keystoneKeyholeCards
                    options: PersonalizationConfig.keystoneKeyholeCardOptions
                    zone: "keyhole"
                    dragCoordinator: keyholeDragCoordinator
                    onToggled: (cardId) => {
                        return PersonalizationConfig.toggleKeystoneKeyholeCard(cardId);
                    }
                    onRemoved: (cardId) => {
                        return PersonalizationConfig.removeKeystoneKeyholeCard(cardId);
                    }
                }

            }

            KeystoneSection {
                title: qsTr("横向时钟")
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
                    title: qsTr("隐藏日期")

                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.keystoneHideDate
                        Accessible.name: qsTr("隐藏日期")
                        onToggled: PersonalizationConfig.setKeystoneHideDate(checked)
                    }

                }

                SettingsActionRow {
                    Layout.fillWidth: true
                    iconName: "tune"
                    text: qsTr("横向时钟样式")
                    description: qsTr("字体、数字位置和颜色")
                    trailingIconName: "chevron_right"
                    onClicked: root.openSection("horizontal-clock")
                }

            }

            KeystoneSection {
                title: qsTr("录制")
                iconName: "video_camera_front"

                RecordingDirectoryField {
                    settingTitle: qsTr("视频录制")
                    settingKey: "recordingVideoDirectory"
                    value: UiPreferences.recordingVideoDirectory
                }

                RecordingDirectoryField {
                    settingTitle: qsTr("GIF 录制")
                    settingKey: "recordingGifDirectory"
                    value: UiPreferences.recordingGifDirectory
                }

                RecordingDirectoryField {
                    settingTitle: qsTr("麦克风录音")
                    settingKey: "recordingMicrophoneDirectory"
                    value: UiPreferences.recordingMicrophoneDirectory
                }

                RecordingDirectoryField {
                    settingTitle: qsTr("系统音频录音")
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

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: subpageHeader.bottom
        anchors.bottom: parent.bottom
        visible: root.currentSection !== "overview"
        source: root.currentSection === "horizontal-clock" ? Qt.resolvedUrl("HorizontalClockPage.qml") : ""
    }

    BarLayoutDragCoordinator {
        id: keyholeDragCoordinator

        anchors.fill: parent
        z: 1000
        fields: [keyholeCardsField]
        onDropped: (cardId, targetZone, targetIndex) => {
            if (targetZone === "keyhole")
                PersonalizationConfig.moveKeystoneKeyholeCard(cardId, targetIndex);

        }
    }

    FilePickerWindow {
        id: directoryPicker

        parentModal: root.parentModal
        requiresParentWindow: true
        selectionMode: FilePickerWindow.Folders
        allowCurrentFolderSelection: true
        dialogTitle: qsTr("保存位置")
        description: root.editingDirectoryField ? root.editingDirectoryField.settingTitle : ""
        nameFilters: []
        windowIconName: "folder_open"
        emptyStateText: qsTr("当前文件夹为空")
        selectionPrompt: qsTr("选择文件夹")
        acceptLabel: qsTr("选择")
        formatSummary: qsTr("可选择当前文件夹或选中的子文件夹")
        onAccepted: function(path, isDirectory) {
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
            labelText: qsTr("保存位置")
            text: directorySetting.value
            trailingContentWidth: Metrics.touchTarget
            onAccepted: root.saveDirectory(directorySetting.settingKey, text, directoryField)
            onEditingFinished: root.saveDirectory(directorySetting.settingKey, text, directoryField)

            trailingContent: Component {
                IconButton {
                    anchors.centerIn: parent
                    iconName: "folder_open"
                    accessibleName: qsTr("选择文件夹")
                    tooltipText: qsTr("选择文件夹")
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
                value: selectRow.value
                placeholder: selectRow.placeholder
                textRole: "label"
                valueRole: "value"
                onAccepted: (value) => {
                    return selectRow.accepted(value);
                }
            }

        }

    }

}
