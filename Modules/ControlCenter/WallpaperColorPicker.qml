import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property string pickerTitle: "选择壁纸颜色"
    property color currentColor: Appearance.colors.colPrimary
    property real hue: 0
    property real saturation: 1
    property real value: 1
    property real alpha: 1
    property real gradientX: 1
    property real gradientY: 0
    property bool shouldBeVisible: false
    property string pickedColorOutput: ""

    readonly property real dialogWidth: Math.max(560, Math.min(680, modalWindow.width - 64))
    readonly property real dialogHeight: Math.min(720, Math.max(520, modalWindow.height - 64))
    readonly property var standardColors: ["#f44336", "#e91e63", "#9c27b0", "#673ab7", "#3f51b5", "#2196f3", "#03a9f4", "#00bcd4", "#009688", "#4caf50", "#8bc34a", "#cddc39", "#ffeb3b", "#ffc107", "#ff9800", "#ff5722", "#d32f2f", "#c2185b", "#7b1fa2", "#512da8", "#303f9f", "#1976d2", "#0288d1", "#0097a7", "#00796b", "#388e3c", "#689f38", "#afb42b", "#fbc02d", "#ffa000", "#f57c00", "#e64a19", "#c62828", "#ad1457", "#6a1b9a", "#4527a0", "#283593", "#1565c0", "#0277bd", "#00838f", "#00695c", "#2e7d32", "#558b2f", "#9e9d24", "#f9a825", "#ff8f00", "#ef6c00", "#d84315", "#ffffff", "#9e9e9e", "#212121"]

    signal colorSelected(string color)

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function normalizeHex(value) {
        const text = String(value || "").trim().toLowerCase();
        if (/^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(text))
            return text;
        if (/^([0-9a-f]{6}|[0-9a-f]{8})$/.test(text))
            return "#" + text;
        return "";
    }

    function showWithColor(colorValue) {
        const normalized = normalizeHex(colorValue);
        const next = normalized !== "" ? Qt.color(normalized) : Appearance.colors.colPrimary;
        root.currentColor = next;
        root.updateFromColor(next);
        root.open();
    }

    function open() {
        shouldBeVisible = true;
        Qt.callLater(() => modalContent.forceActiveFocus());
    }

    function close() {
        shouldBeVisible = false;
    }

    function updateFromColor(colorValue) {
        root.hue = Math.max(0, colorValue.hsvHue);
        root.saturation = root.clamp01(colorValue.hsvSaturation);
        root.value = root.clamp01(colorValue.hsvValue);
        root.alpha = root.clamp01(colorValue.a);
        root.gradientX = root.saturation;
        root.gradientY = 1 - root.value;
    }

    function updateColor() {
        root.currentColor = Qt.hsva(root.hue, root.saturation, root.value, root.alpha);
    }

    function updateColorFromGradient(x, y) {
        root.saturation = root.clamp01(x);
        root.value = root.clamp01(1 - y);
        root.updateColor();
    }

    function colorToHex(colorValue) {
        const a = Math.round(root.clamp01(colorValue.a) * 255).toString(16).padStart(2, "0");
        const r = Math.round(root.clamp01(colorValue.r) * 255).toString(16).padStart(2, "0");
        const g = Math.round(root.clamp01(colorValue.g) * 255).toString(16).padStart(2, "0");
        const b = Math.round(root.clamp01(colorValue.b) * 255).toString(16).padStart(2, "0");
        if (root.clamp01(colorValue.a) < 1)
            return "#" + a + r + g + b;
        return "#" + r + g + b;
    }

    function rgbString() {
        const r = Math.round(root.currentColor.r * 255);
        const g = Math.round(root.currentColor.g * 255);
        const b = Math.round(root.currentColor.b * 255);
        if (root.alpha < 1)
            return "rgba(" + r + ", " + g + ", " + b + ", " + root.alpha.toFixed(2) + ")";
        return "rgb(" + r + ", " + g + ", " + b + ")";
    }

    function hsvString() {
        const h = Math.round(root.hue * 360);
        const s = Math.round(root.saturation * 100);
        const v = Math.round(root.value * 100);
        if (root.alpha < 1)
            return h + "deg, " + s + "%, " + v + "%, " + Math.round(root.alpha * 100) + "%";
        return h + "deg, " + s + "%, " + v + "%";
    }

    function copyText(value) {
        Quickshell.execDetached(["wl-copy", String(value)]);
    }

    function applyPickedColor(colorText) {
        const normalized = normalizeHex(colorText);
        if (normalized === "")
            return false;

        root.currentColor = Qt.color(normalized);
        root.updateFromColor(root.currentColor);
        PersonalizationConfig.addRecentWallpaperColor(normalized);
        return true;
    }

    function pickColorFromScreen() {
        root.pickedColorOutput = "";
        root.close();
        pickColorProcess.running = false;
        pickColorProcess.running = true;
    }

    PanelWindow {
        id: modalWindow

        visible: root.shouldBeVisible
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clavis-wallpaper-color-picker"
        WlrLayershell.keyboardFocus: modalWindow.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => modalContent.forceActiveFocus());
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.shouldBeVisible
            onClicked: root.close()
        }

        FocusScope {
            id: modalContent

            anchors.centerIn: parent
            width: root.dialogWidth
            height: root.dialogHeight
            focus: root.shouldBeVisible

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainerLow
                border.width: 1
                border.color: Appearance.m3colors.m3outlineVariant
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                z: -1
                onPressed: mouse => mouse.accepted = true
                onClicked: mouse => mouse.accepted = true
            }

            Keys.onEscapePressed: event => {
                root.close();
                event.accepted = true;
            }

            StyledFlickable {
                anchors.fill: parent
                anchors.margins: 16
                contentWidth: width
                contentHeight: mainColumn.implicitHeight

                ColumnLayout {
                    id: mainColumn

                    width: parent.width
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.pickerTitle
                                color: Appearance.colors.colOnSurface
                                font.family: Sizes.fontFamily
                                font.pixelSize: 19
                                font.weight: Font.Medium
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "从调色板中选择颜色，或使用自定义滑块"
                                color: Appearance.colors.colSubtext
                                font.family: Sizes.fontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }

                        IconButton {
                            iconName: "colorize"
                            tooltipText: "屏幕取色"
                            onClicked: root.pickColorFromScreen()
                        }

                        IconButton {
                            iconName: "close"
                            tooltipText: "关闭"
                            onClicked: root.close()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            id: gradientPicker

                            Layout.fillWidth: true
                            Layout.preferredHeight: 280
                            radius: Appearance.rounding.normal
                            border.color: Appearance.colors.colOutline
                            border.width: 1
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.hsva(root.hue, 1, 1, 1)

                                Rectangle {
                                    anchors.fill: parent
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#ffffff" }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 1.0; color: "#000000" }
                                    }
                                }
                            }

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                border.color: "white"
                                border.width: 2
                                color: "transparent"
                                x: root.gradientX * parent.width - width / 2
                                y: root.gradientY * parent.height - height / 2

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 4
                                    height: parent.height - 4
                                    radius: width / 2
                                    border.color: "black"
                                    border.width: 1
                                    color: "transparent"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.CrossCursor
                                onPressed: mouse => {
                                    const x = root.clamp01(mouse.x / width);
                                    const y = root.clamp01(mouse.y / height);
                                    root.gradientX = x;
                                    root.gradientY = y;
                                    root.updateColorFromGradient(x, y);
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return;
                                    const x = root.clamp01(mouse.x / width);
                                    const y = root.clamp01(mouse.y / height);
                                    root.gradientX = x;
                                    root.gradientY = y;
                                    root.updateColorFromGradient(x, y);
                                }
                            }
                        }

                        Rectangle {
                            id: hueSlider

                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 280
                            radius: Appearance.rounding.normal
                            border.color: Appearance.colors.colOutline
                            border.width: 1

                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.00; color: "#ff0000" }
                                GradientStop { position: 0.17; color: "#ffff00" }
                                GradientStop { position: 0.33; color: "#00ff00" }
                                GradientStop { position: 0.50; color: "#00ffff" }
                                GradientStop { position: 0.67; color: "#0000ff" }
                                GradientStop { position: 0.83; color: "#ff00ff" }
                                GradientStop { position: 1.00; color: "#ff0000" }
                            }

                            Rectangle {
                                width: parent.width
                                height: 4
                                color: "white"
                                border.color: "black"
                                border.width: 1
                                y: root.hue * parent.height - height / 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.SizeVerCursor
                                onPressed: mouse => {
                                    root.hue = root.clamp01(mouse.y / height);
                                    root.updateColor();
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return;
                                    root.hue = root.clamp01(mouse.y / height);
                                    root.updateColor();
                                }
                            }
                        }
                    }

                    SectionLabel {
                        text: "Material Colors"
                    }

                    StyledGridView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 152
                        cellWidth: 38
                        cellHeight: 38
                        clip: true
                        interactive: false
                        animateAppearance: false
                        animateMovement: false
                        showVerticalScrollBar: false
                        smoothWheelEnabled: false
                        model: root.standardColors

                        delegate: Rectangle {
                            required property string modelData

                            width: 36
                            height: 36
                            radius: 4
                            color: modelData
                            border.color: Appearance.colors.colOutline
                            border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentColor = Qt.color(modelData);
                                    root.updateFromColor(root.currentColor);
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        ColumnLayout {
                            Layout.preferredWidth: 210
                            spacing: 8

                            SectionLabel {
                                text: "Recent Colors"
                            }

                            RowLayout {
                                spacing: 6

                                Repeater {
                                    model: 5

                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 4
                                        color: index < PersonalizationConfig.recentWallpaperColors.length ? PersonalizationConfig.recentWallpaperColors[index] : Appearance.colors.colLayer3
                                        opacity: index < PersonalizationConfig.recentWallpaperColors.length ? 1 : 0.35
                                        border.color: Appearance.colors.colOutline
                                        border.width: 1

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: index < PersonalizationConfig.recentWallpaperColors.length
                                            hoverEnabled: enabled
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                root.currentColor = Qt.color(PersonalizationConfig.recentWallpaperColors[index]);
                                                root.updateFromColor(root.currentColor);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            SectionLabel {
                                text: "Opacity"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 100
                                    value: Math.round(root.alpha * 100)
                                    Material.accent: Appearance.colors.colPrimary
                                    onMoved: {
                                        root.alpha = value / 100;
                                        root.updateColor();
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 44
                                    text: Math.round(root.alpha * 100) + "%"
                                    color: Appearance.colors.colOnSurface
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignRight
                                }

                                Rectangle {
                                    Layout.preferredWidth: 74
                                    Layout.preferredHeight: 50
                                    radius: Appearance.rounding.normal
                                    color: root.currentColor
                                    border.color: Appearance.colors.colOutline
                                    border.width: 2
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        FormatField {
                            title: "Hex"
                            value: root.colorToHex(root.currentColor)
                            editable: true
                            onAccepted: text => {
                                const normalized = root.normalizeHex(text);
                                if (normalized === "")
                                    return;
                                root.currentColor = Qt.color(normalized);
                                root.updateFromColor(root.currentColor);
                            }
                            onCopyRequested: text => root.copyText(text)
                        }

                        FormatField {
                            title: "RGB"
                            value: root.rgbString()
                            onCopyRequested: text => root.copyText(text)
                        }

                        FormatField {
                            title: "HSV"
                            value: root.hsvString()
                            onCopyRequested: text => root.copyText(text)
                        }
                    }

                    Button {
                        Layout.alignment: Qt.AlignRight
                        text: "Save"
                        Material.background: Appearance.colors.colPrimary
                        Material.foreground: Appearance.colors.colOnPrimary
                        onClicked: {
                            const hex = root.colorToHex(root.currentColor);
                            PersonalizationConfig.addRecentWallpaperColor(hex);
                            root.colorSelected(hex);
                            root.close();
                        }
                    }
                }
            }
        }
    }

    Process {
        id: pickColorProcess

        command: ["hyprpicker", "-r", "-f", "hex", "-l"]
        stdout: StdioCollector {
            onStreamFinished: root.pickedColorOutput = this.text.trim()
        }
        onExited: exitCode => {
            if (exitCode === 0)
                root.applyPickedColor(root.pickedColorOutput);
            root.open();
        }
    }

    component SectionLabel: Text {
        color: Appearance.colors.colOnSurface
        font.family: Sizes.fontFamily
        font.pixelSize: 15
        font.weight: Font.Medium
    }

    component IconButton: Item {
        id: iconButton

        property string iconName: ""
        property string tooltipText: ""

        signal clicked

        implicitWidth: 36
        implicitHeight: 36

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: iconMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: iconButton.iconName
            iconSize: 20
            color: Appearance.colors.colOnSurface
            fill: iconMouse.containsMouse ? 1 : 0
        }

        MouseArea {
            id: iconMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
        }

        StyledToolTip {
            extraVisibleCondition: iconMouse.containsMouse && iconButton.tooltipText !== ""
            text: iconButton.tooltipText
        }
    }

    component FormatField: ColumnLayout {
        id: formatField

        property string title: ""
        property string value: ""
        property bool editable: false

        signal accepted(string text)
        signal copyRequested(string text)

        Layout.fillWidth: true
        spacing: 6

        Text {
            text: formatField.title
            color: Appearance.colors.colSubtext
            font.family: Sizes.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: input

                Layout.fillWidth: true
                Layout.preferredHeight: 36
                text: formatField.value
                readOnly: !formatField.editable
                selectByMouse: true
                Material.accent: Appearance.colors.colPrimary
                Material.background: Appearance.colors.colLayer2
                Material.foreground: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 13
                onAccepted: formatField.accepted(text)
                onEditingFinished: {
                    if (formatField.editable)
                        formatField.accepted(text);
                }
            }

            IconButton {
                iconName: "content_copy"
                tooltipText: "复制"
                onClicked: formatField.copyRequested(input.text)
            }
        }
    }
}
