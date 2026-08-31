import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string currentSection: "overview"

    function openSection(section) {
        root.currentSection = String(section || "overview");
    }

    function showOverview() {
        root.currentSection = "overview";
    }

    function closeChildWindows() {
        root.showOverview();
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

                SettingsRow {
                    Layout.fillWidth: true
                    title: qsTr("卡片")

                    trailing: SortableMultiSelectField {
                        id: keyholeCardsField

                        Layout.preferredWidth: 380
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
