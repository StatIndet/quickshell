import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
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
        property string iconName: "palette"
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

    component PreviewSegmentGroup: Item {
        id: previewGroup

        property bool selected: false
        property bool darkPreview: false
        property color normalFill: darkPreview ? "#5f5961" : "#e1dee2"
        property color selectedFill: Appearance.colors.colPrimary
        property color checkColor: Appearance.colors.colOnPrimary

        implicitWidth: 260
        implicitHeight: 34

        readonly property real gap: 3
        readonly property real segmentHeight: height
        readonly property real firstWidth: Math.round(width * 0.315)
        readonly property real middleWidth: Math.round(width * 0.34)
        readonly property real lastWidth: width - firstWidth - middleWidth - gap * 2

        Rectangle {
            x: 0
            y: 0
            width: previewGroup.firstWidth
            height: previewGroup.segmentHeight
            radius: height / 2
            color: previewGroup.selected ? previewGroup.selectedFill : previewGroup.normalFill
            opacity: previewGroup.selected ? 1 : 0.82
            antialiasing: true

            MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                iconSize: 16
                fill: 1
                color: previewGroup.checkColor
                visible: previewGroup.selected
            }
        }

        Rectangle {
            x: previewGroup.firstWidth + previewGroup.gap
            y: 0
            width: previewGroup.middleWidth
            height: previewGroup.segmentHeight
            radius: 5
            color: previewGroup.normalFill
            opacity: 0.82
            antialiasing: true
        }

        Rectangle {
            x: previewGroup.firstWidth + previewGroup.middleWidth + previewGroup.gap * 2
            y: 0
            width: previewGroup.lastWidth
            height: previewGroup.segmentHeight
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: height / 2
            bottomRightRadius: height / 2
            color: previewGroup.normalFill
            opacity: 0.82
            antialiasing: true
        }
    }

    component ThemePreviewCard: Item {
        id: themeCard

        required property string mode
        required property string title
        property bool darkPreview: false
        readonly property bool active: PersonalizationConfig.themeMode === mode
        readonly property color selectedAccent: Appearance.colors.colPrimary
        readonly property color selectedOnAccent: Appearance.colors.colOnPrimary
        readonly property color outerFill: active ? selectedAccent : Appearance.colors.colLayer1
        readonly property color previewSurface: darkPreview ? "#302d32" : "#fbf7f8"
        readonly property color avatarFill: darkPreview ? "#8a838c" : "#dedde1"
        readonly property color placeholderFill: darkPreview ? "#948b92" : "#dedbdf"
        readonly property color placeholderAltFill: darkPreview ? "#776f75" : "#d3d0d5"
        readonly property color waveFill: active ? selectedAccent : (darkPreview ? "#8a858e" : "#ccc8cd")
        readonly property color trackFill: darkPreview ? "#6d6870" : "#d7d3d8"
        readonly property color labelText: active ? selectedOnAccent : Appearance.colors.colOnLayer1

        signal clicked

        Layout.preferredWidth: 288
        Layout.preferredHeight: 180
        scale: cardMouse.pressed ? 0.985 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutSine
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: themeCard.outerFill
            border.width: 0
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 33
            bottomLeftRadius: 13
            bottomRightRadius: 13
            color: "transparent"

            Text {
                anchors.centerIn: parent
                text: themeCard.title
                color: themeCard.labelText
                font.family: Sizes.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }

        Rectangle {
            id: previewPane

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.topMargin: 10
            anchors.bottomMargin: 37
            radius: 8
            color: themeCard.previewSurface
            border.width: 0

            Rectangle {
                x: 15
                y: 12
                width: 46
                height: 46
                radius: width / 2
                color: themeCard.avatarFill
                opacity: themeCard.darkPreview ? 0.9 : 0.92
            }

            Column {
                x: 72
                y: 16
                spacing: 8

                Rectangle {
                    width: Math.min(154, previewPane.width - 92)
                    height: 18
                    radius: 5
                    color: themeCard.placeholderFill
                    opacity: themeCard.darkPreview ? 0.85 : 1
                }

                Rectangle {
                    width: Math.min(124, previewPane.width - 118)
                    height: 16
                    radius: 5
                    color: themeCard.placeholderAltFill
                    opacity: themeCard.darkPreview ? 0.95 : 1
                }
            }

            MiniMaterialWaveLine {
                x: 18
                y: 66
                width: previewPane.width - 36
                height: 18
                waveColor: themeCard.waveFill
                trackColor: themeCard.trackFill
                trackOpacity: themeCard.darkPreview ? 0.42 : 0.54
                wavePortion: 0.72
                phaseDuration: 1600
                flowing: themeCard.active
                endDotColor: themeCard.waveFill
            }

            PreviewSegmentGroup {
                x: 13
                y: previewPane.height - height - 8
                width: previewPane.width - 26
                height: 33
                selected: themeCard.active
                darkPreview: themeCard.darkPreview
                selectedFill: themeCard.selectedAccent
                checkColor: themeCard.selectedOnAccent
            }
        }

        MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: themeCard.clicked()
        }
    }

    component SearchSelectSettingRow: Item {
        id: selectRow

        property string title: ""
        property string description: ""
        property var options: []
        property string value: ""
        property string placeholder: ""
        property string textRole: "label"
        property string valueRole: "value"
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
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: selectRow.description
                    color: Appearance.colors.colSubtext
                    font.family: Sizes.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }
            }

            SearchSelectMenuField {
                Layout.preferredWidth: selectRow.fieldWidth
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                options: selectRow.options
                value: selectRow.value
                placeholder: selectRow.placeholder
                textRole: selectRow.textRole
                valueRole: selectRow.valueRole
                maxVisibleItems: 6
                noResultText: "无匹配结果"
                onAccepted: value => selectRow.accepted(value)
            }
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ThemePreviewCard {
                title: "浅色"
                mode: "light"
                darkPreview: false
                onClicked: ThemeService.setThemeMode("light")
            }

            ThemePreviewCard {
                title: "深色"
                mode: "dark"
                darkPreview: true
                onClicked: ThemeService.setThemeMode("dark")
            }
        }

        Section {
            title: "matugen配色方案"
            iconName: "colors"

            ColumnLayout {
                Layout.alignment: Qt.AlignLeft
                spacing: 4

                SegmentedButtonGroup {
                    Layout.alignment: Qt.AlignLeft
                    model: PersonalizationConfig.matugenSchemes.slice(0, 5)
                    currentValue: PersonalizationConfig.matugenScheme
                    horizontalPadding: 24
                    onValueSelected: value => ThemeService.setMatugenScheme(value)
                }

                SegmentedButtonGroup {
                    Layout.alignment: Qt.AlignLeft
                    model: PersonalizationConfig.matugenSchemes.slice(5, 9)
                    currentValue: PersonalizationConfig.matugenScheme
                    horizontalPadding: 24
                    onValueSelected: value => ThemeService.setMatugenScheme(value)
                }
            }
        }

        Section {
            title: "光标主题"
            iconName: "mouse"

            CursorThemeSelect {
                cursorThemes: ThemeService.availableCursorThemes
                currentCursorTheme: PersonalizationConfig.cursorTheme
                onAccepted: value => ThemeService.setCursorTheme(value)
            }

            SliderSettingRow {
                title: "光标尺寸"
                description: "鼠标指针像素尺寸"
                from: 12
                to: 128
                stepSize: 1
                suffix: "像素"
                value: PersonalizationConfig.cursorSize
                onMoved: value => ThemeService.setCursorSize(Math.round(value))
            }

            ToggleSettingRow {
                title: "打字时隐藏"
                description: "按下键盘按键时隐藏光标"
                checked: PersonalizationConfig.cursorHideWhenTyping
                onToggled: checked => ThemeService.setCursorHideWhenTyping(checked)
            }

            SliderSettingRow {
                title: "自动超时隐藏"
                description: "闲置后隐藏光标，0 表示停用"
                from: 0
                to: 5000
                stepSize: 100
                suffix: "毫秒"
                value: PersonalizationConfig.cursorHideAfterInactiveMs
                onMoved: value => ThemeService.setCursorHideAfterInactiveMs(Math.round(value))
            }
        }

        Section {
            title: "图标主题"
            iconName: "interests"

            SearchSelectSettingRow {
                title: "图标主题"
                description: "桌面壳层与系统应用图标"
                options: ThemeService.availableIconThemes
                value: PersonalizationConfig.iconTheme
                placeholder: "选择图标主题"
                onAccepted: value => ThemeService.setIconTheme(value)
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
