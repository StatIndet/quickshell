import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

    readonly property real pageContentWidth: 600

    component Section: ColumnLayout {
        id: section

        property string title: ""
        property string iconName: "settings"
        default property alias content: body.data

        Layout.fillWidth: true
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                text: section.iconName
                iconSize: 26
                fill: 1
                color: Appearance.colors.colOnSecondaryContainer
            }

            Text {
                Layout.fillWidth: true
                text: section.title
                color: Appearance.colors.colOnSecondaryContainer
                font.family: Sizes.fontFamily
                font.pixelSize: 18
                font.weight: Font.Medium
            }
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: 10
        }
    }

    component ToggleSettingRow: Item {
        id: toggleRow

        property string title: ""
        property string description: ""
        property bool checked: false

        signal toggled(bool checked)

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(58, toggleLabelColumn.implicitHeight + 16)

        RowLayout {
            anchors.fill: parent
            spacing: 16

            Column {
                id: toggleLabelColumn

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    width: parent.width
                    text: toggleRow.title
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: toggleRow.description
                    color: Appearance.colors.colSubtext
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }
            }

            StyledSwitch {
                Layout.alignment: Qt.AlignVCenter
                checked: toggleRow.checked
                onToggled: toggleRow.toggled(checked)
            }
        }
    }

    component SliderSettingRow: ColumnLayout {
        id: sliderRow

        property string title: ""
        property string description: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property real stepSize: 1
        property string suffix: ""

        signal moved(real value)

        Layout.fillWidth: true
        spacing: 6

        function formatValue(displayValue) {
            return Math.round(displayValue).toString() + (suffix !== "" ? " " + suffix : "");
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: sliderRow.title
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Item {
                id: valueEditor

                Layout.preferredWidth: 108
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter

                property bool editing: false
                property bool invalid: false
                property string draft: ""

                function startEdit() {
                    draft = Math.round(sliderRow.value).toString();
                    invalid = false;
                    editing = true;
                }

                function applyEdit() {
                    if (!editing)
                        return;

                    const cleanDraft = draft.trim();
                    const value = Number(cleanDraft);
                    if (cleanDraft === "" || !isFinite(value)) {
                        invalid = true;
                        return;
                    }

                    const nextValue = Math.max(sliderRow.from, Math.min(sliderRow.to, Math.round(value)));
                    invalid = false;
                    editing = false;
                    sliderRow.moved(nextValue);
                }

                function cancelEdit() {
                    invalid = false;
                    editing = false;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.full
                    color: valueEditor.editing
                           ? Appearance.colors.colSecondaryContainer
                           : valueMouse.pressed
                             ? Appearance.colors.colSecondaryContainerActive
                             : valueMouse.containsMouse
                               ? Appearance.colors.colSecondaryContainerHover
                               : Appearance.colors.colSecondaryContainer
                    border.width: 0

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                Text {
                    id: valueLabel

                    anchors.centerIn: parent
                    width: parent.width - 16
                    visible: !valueEditor.editing
                    text: sliderRow.formatValue(sliderRow.value)
                    color: Appearance.colors.colOnSecondaryContainer
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: valueInput

                    anchors.fill: parent
                    visible: valueEditor.editing
                    text: valueEditor.draft
                    color: Appearance.colors.colOnSecondaryContainer
                    selectedTextColor: Appearance.colors.colOnPrimary
                    selectionColor: Appearance.colors.colPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    selectByMouse: true
                    validator: IntValidator {
                        bottom: Math.ceil(sliderRow.from)
                        top: Math.floor(sliderRow.to)
                    }
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    padding: 0
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    Material.accent: Appearance.colors.colPrimary
                    background: Item {}
                    onTextChanged: {
                        if (valueEditor.editing) {
                            valueEditor.draft = text;
                            valueEditor.invalid = false;
                        }
                    }
                    onVisibleChanged: {
                        if (visible) {
                            Qt.callLater(() => {
                                valueInput.forceActiveFocus();
                                valueInput.selectAll();
                            });
                        }
                    }
                    onEditingFinished: valueEditor.applyEdit()
                    Keys.onReturnPressed: valueEditor.applyEdit()
                    Keys.onEnterPressed: valueEditor.applyEdit()
                    Keys.onEscapePressed: event => {
                        valueEditor.cancelEdit();
                        event.accepted = true;
                    }
                }

                MouseArea {
                    id: valueMouse

                    anchors.fill: parent
                    enabled: !valueEditor.editing
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: valueEditor.startEdit()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: sliderRow.description
            color: Appearance.colors.colSubtext
            font.family: Sizes.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        MaterialAccessibleSlider {
            id: settingSlider

            Layout.fillWidth: true
            Layout.preferredHeight: 72
            from: sliderRow.from
            to: sliderRow.to
            stepSize: sliderRow.stepSize
            value: sliderRow.value
            accessibleName: sliderRow.title
            valueFormatter: sliderValue => Math.round(sliderValue).toString()
            onMoved: sliderRow.moved(Math.round(settingSlider.value))
        }
    }

    ColumnLayout {
        id: contentColumn

        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: 30

        Section {
            title: "提示音"
            iconName: "notification_sound"

            ToggleSettingRow {
                title: "番茄钟"
                description: "专注与休息阶段切换时播放系统提示音"
                checked: PersonalizationConfig.pomodoroSoundEnabled
                onToggled: checked => PersonalizationConfig.setPomodoroSoundEnabled(checked)
            }
        }

        Section {
            title: "滚动交互"
            iconName: "swipe"

            ToggleSettingRow {
                title: "平滑滚轮"
                description: "列表与滚动容器使用统一的滚轮插值"
                checked: PersonalizationConfig.scrollSmoothEnabled
                onToggled: checked => PersonalizationConfig.setScrollSmoothEnabled(checked)
            }

            SliderSettingRow {
                title: "鼠标滚轮速度"
                description: "适用于滚轮步进输入"
                from: 10
                to: 240
                stepSize: 5
                value: PersonalizationConfig.scrollMouseFactor
                onMoved: value => PersonalizationConfig.setScrollMouseFactor(Math.round(value))
            }

            SliderSettingRow {
                title: "触摸板滚动速度"
                description: "适用于连续小幅滚动输入"
                from: 10
                to: 300
                stepSize: 5
                value: PersonalizationConfig.scrollTouchpadFactor
                onMoved: value => PersonalizationConfig.setScrollTouchpadFactor(Math.round(value))
            }

            SliderSettingRow {
                title: "滚轮识别阈值"
                description: "angleDelta 大于该值时按鼠标滚轮处理"
                from: 60
                to: 240
                stepSize: 10
                value: PersonalizationConfig.scrollMouseDeltaThreshold
                onMoved: value => PersonalizationConfig.setScrollMouseDeltaThreshold(Math.round(value))
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }
}
