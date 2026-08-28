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
                font.family: Fonts.ui
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
                font.family: Fonts.ui
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
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: toggleRow.description
                    color: Appearance.colors.colSubtext
                    font.family: Fonts.ui
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
                font.family: Fonts.ui
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: sliderRow.formatValue(sliderRow.value)
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.numeric
                font.pixelSize: Typography.bodyMedium.pixelSize
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            Layout.fillWidth: true
            text: sliderRow.description
            color: Appearance.colors.colSubtext
            font.family: Fonts.ui
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        MaterialSlider {
            id: settingSlider

            Layout.fillWidth: true
            Layout.preferredHeight: 72
            from: sliderRow.from
            to: sliderRow.to
            stepSize: sliderRow.stepSize
            value: sliderRow.value
            accessibleName: sliderRow.title
            valueFormatter: sliderValue => Math.round(sliderValue).toString()
                + sliderRow.suffix
            onMoved: value => sliderRow.moved(Math.round(value))
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
                title: qsTr("浅色")
                mode: "light"
                darkPreview: false
                onClicked: ThemeService.setThemeMode("light")
            }

            ThemePreviewCard {
                title: qsTr("深色")
                mode: "dark"
                darkPreview: true
                onClicked: ThemeService.setThemeMode("dark")
            }
        }

        Section {
            title: qsTr("matugen配色方案")
            iconName: "colors"

            ColumnLayout {
                Layout.alignment: Qt.AlignLeft
                spacing: 4

                StyledButtonGroup {
                    Layout.alignment: Qt.AlignLeft
                    model: PersonalizationConfig.matugenSchemes.slice(0, 5)
                    currentValue: PersonalizationConfig.matugenScheme
                    horizontalPadding: 24
                    onValueSelected: value => ThemeService.setMatugenScheme(value)
                }

                StyledButtonGroup {
                    Layout.alignment: Qt.AlignLeft
                    model: PersonalizationConfig.matugenSchemes.slice(5, 9)
                    currentValue: PersonalizationConfig.matugenScheme
                    horizontalPadding: 24
                    onValueSelected: value => ThemeService.setMatugenScheme(value)
                }
            }
        }

        Section {
            title: qsTr("光标主题")
            iconName: "mouse"

            CursorThemeSelect {
                cursorThemes: ThemeService.availableCursorThemes
                currentCursorTheme: PersonalizationConfig.cursorTheme
                onAccepted: value => ThemeService.setCursorTheme(value)
            }

            InlineStatusBanner {
                Layout.fillWidth: true
                visible: ThemeService.cursorLastError !== ""
                tone: "error"
                message: ThemeService.cursorLastError
            }

            SliderSettingRow {
                title: qsTr("光标尺寸")
                from: 12
                to: 128
                stepSize: 1
                suffix: qsTr("像素")
                value: PersonalizationConfig.cursorSize
                onMoved: value => ThemeService.setCursorSize(Math.round(value))
            }

            ToggleSettingRow {
                title: qsTr("打字时隐藏")
                checked: PersonalizationConfig.cursorHideWhenTyping
                onToggled: checked => ThemeService.setCursorHideWhenTyping(checked)
            }

            SliderSettingRow {
                title: qsTr("自动超时隐藏")
                description: qsTr("闲置后隐藏光标，0 表示停用")
                from: 0
                to: 5000
                stepSize: 100
                suffix: qsTr("毫秒")
                value: PersonalizationConfig.cursorHideAfterInactiveMs
                onMoved: value => ThemeService.setCursorHideAfterInactiveMs(Math.round(value))
            }
        }

        Section {
            title: qsTr("图标主题")
            iconName: "interests"

            SearchSelectSettingRow {
                title: qsTr("图标主题")
                options: ThemeService.availableIconThemes
                value: PersonalizationConfig.iconTheme
                placeholder: qsTr("选择图标主题")
                onAccepted: value => ThemeService.setIconTheme(value)
            }
        }

        Section {
            title: qsTr("字体")
            iconName: "text_format"

            SearchSelectSettingRow {
                title: qsTr("界面字体")
                description: qsTr("普通标题、正文和控件")
                options: FontService.fontOptions
                value: PersonalizationConfig.uiFontFamily
                placeholder: qsTr("选择界面字体")
                fieldWidth: 280
                onAccepted: value =>
                    PersonalizationConfig.setFontFamily("ui", value)
            }

            SearchSelectSettingRow {
                title: qsTr("等宽字体")
                description: qsTr("命令、路径和技术信息")
                options: FontService.fontOptions
                value: PersonalizationConfig.monoFontFamily
                placeholder: qsTr("选择等宽字体")
                fieldWidth: 280
                onAccepted: value =>
                    PersonalizationConfig.setFontFamily("mono", value)
            }

            SearchSelectSettingRow {
                title: qsTr("数字字体")
                description: qsTr("时间、百分比和系统数值")
                options: FontService.fontOptions
                value: PersonalizationConfig.numericFontFamily
                placeholder: qsTr("选择数字字体")
                fieldWidth: 280
                onAccepted: value =>
                    PersonalizationConfig.setFontFamily("numeric", value)
            }

            SearchSelectSettingRow {
                title: qsTr("表现性字体")
                description: qsTr("天气等强调型视觉组件")
                options: FontService.fontOptions
                value: PersonalizationConfig.expressiveFontFamily
                placeholder: qsTr("选择表现性字体")
                fieldWidth: 280
                onAccepted: value =>
                    PersonalizationConfig.setFontFamily("expressive", value)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight

                ActionButton {
                    text: qsTr("恢复默认字体")
                    onClicked: PersonalizationConfig.resetFontFamilies()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }
}
