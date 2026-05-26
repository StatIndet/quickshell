import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 20

    readonly property string currentWallpaperPath: WallpaperService.currentWallpaper || PersonalizationConfig.wallpaperPath
    readonly property bool currentWallpaperIsColor: WallpaperService.isColorSource(currentWallpaperPath)
    readonly property bool currentWallpaperIsImage: currentWallpaperPath !== "" && !currentWallpaperIsColor
    readonly property real pageContentWidth: 600
    property real fillModeGroupRestingWidth: 0

    function chooseWallpaperFile() {
        const base = root.currentWallpaperIsImage ? WallpaperService.parentFolder(root.currentWallpaperPath) : PersonalizationConfig.wallpaperFolder;
        wallpaperFileBrowser.openAt(base || PersonalizationConfig.wallpaperFolder);
    }

    function chooseWallpaperColor() {
        wallpaperColorPicker.showWithColor(root.currentWallpaperIsColor ? root.currentWallpaperPath : Appearance.colors.colPrimary);
    }

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
            spacing: 12
        }
    }

    component ActionPillButton: Item {
        id: pill

        property string text: ""
        property string iconName: ""

        signal clicked

        implicitWidth: Math.max(78, label.implicitWidth + (iconName !== "" ? 42 : 28))
        implicitHeight: 34
        opacity: enabled ? 1 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: pillMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: pill.iconName
                iconSize: 18
                color: Appearance.colors.colOnLayer2
                visible: pill.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: label
                text: pill.text
                color: Appearance.colors.colOnLayer2
                font.family: Sizes.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            enabled: pill.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component HoverActionButton: Item {
        id: action

        property string iconName: ""
        property string tooltipText: ""

        signal clicked

        width: 32
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: actionMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.9)
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: action.iconName
            iconSize: 18
            color: "black"
            fill: 1
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }

        StyledToolTip {
            extraVisibleCondition: actionMouse.containsMouse && action.tooltipText !== ""
            text: action.tooltipText
        }
    }

    component EasingGroupButton: Item {
        id: groupButton

        required property string iconName
        property string tooltipText: ""
        property bool active: false
        property bool first: false
        property bool last: false
        property int buttonHeight: 38
        property int baseWidth: 44
        property int innerRadius: 6
        property int pressedExpansion: 10
        property real edgeRadius: buttonHeight / 2
        property real rLeft: (active || first || buttonMouse.pressed) ? edgeRadius : innerRadius
        property real rRight: (active || last || buttonMouse.pressed) ? edgeRadius : innerRadius
        property color bgColor: active
                                ? (buttonMouse.pressed ? Appearance.colors.colPrimaryActive : buttonMouse.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary)
                                : (buttonMouse.pressed ? Appearance.colors.colSecondaryContainerActive : buttonMouse.containsMouse ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer)

        signal clicked

        Layout.preferredWidth: baseWidth + (buttonMouse.pressed ? pressedExpansion : 0)
        Layout.preferredHeight: buttonHeight
        opacity: enabled ? 1 : 0.45
        scale: buttonMouse.pressed ? 0.97 : 1

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        Behavior on bgColor {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutSine
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: groupButton.rLeft > groupButton.rRight ? groupButton.rLeft : groupButton.rRight
            color: groupButton.bgColor

            Behavior on radius {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutSine
                }
            }
        }

        Rectangle {
            anchors.left: groupButton.rLeft < groupButton.rRight ? parent.left : undefined
            anchors.right: groupButton.rRight < groupButton.rLeft ? parent.right : undefined
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width / 2 + 5
            visible: groupButton.rLeft !== groupButton.rRight
            radius: groupButton.rLeft < groupButton.rRight ? groupButton.rLeft : groupButton.rRight
            color: groupButton.bgColor

            Behavior on radius {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutSine
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: groupButton.iconName
            iconSize: 21
            fill: groupButton.active ? 1 : 0
            color: groupButton.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            enabled: groupButton.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: groupButton.clicked()
        }

        StyledToolTip {
            extraVisibleCondition: buttonMouse.containsMouse && groupButton.tooltipText !== ""
            text: groupButton.tooltipText
        }
    }

    component EasingActionGroup: RowLayout {
        id: group

        property bool playing: false
        property bool flipEnabled: true

        signal playClicked
        signal replayClicked
        signal flipClicked

        spacing: 2

        EasingGroupButton {
            first: true
            active: group.playing
            iconName: group.playing ? "pause" : "play_arrow"
            tooltipText: group.playing ? "暂停" : "播放"
            onClicked: group.playClicked()
        }

        EasingGroupButton {
            iconName: "keyboard_double_arrow_left"
            tooltipText: "倒放"
            onClicked: group.replayClicked()
        }

        EasingGroupButton {
            last: true
            enabled: group.flipEnabled
            iconName: "swap_vert"
            tooltipText: "翻转"
            onClicked: group.flipClicked()
        }
    }

    ColumnLayout {
        id: contentColumn
        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 24
        spacing: 30

        Section {
            title: "当前壁纸"
            iconName: "wallpaper"

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                Item {
                    id: wallpaperPreview

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 340
                    Layout.preferredHeight: 200

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: root.currentWallpaperIsColor ? root.currentWallpaperPath : Appearance.colors.colLayer2
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.currentWallpaperIsImage ? Paths.fileUrl(root.currentWallpaperPath) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                        visible: source !== ""
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: wallpaperMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                    }

                    Rectangle {
                        id: wallpaperMask
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Appearance.rounding.normal - 1
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "image"
                        iconSize: 34
                        color: Appearance.colors.colOnSurfaceVariant
                        visible: root.currentWallpaperPath === ""
                    }

                    HoverHandler {
                        id: previewHover
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Appearance.rounding.normal - 1
                        color: Qt.rgba(0, 0, 0, 0.7)
                        opacity: previewHover.hovered ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutSine
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            HoverActionButton {
                                iconName: "folder_open"
                                tooltipText: "选择文件夹"
                                onClicked: root.chooseWallpaperFile()
                            }

                            HoverActionButton {
                                iconName: "palette"
                                tooltipText: "选择颜色"
                                onClicked: root.chooseWallpaperColor()
                            }

                            HoverActionButton {
                                iconName: "clear"
                                tooltipText: "清除壁纸"
                                onClicked: WallpaperService.clearWallpaper()
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Math.min(450, Math.max(330, root.width - 420))
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: root.currentWallpaperPath !== "" ? WallpaperService.basename(root.currentWallpaperPath) : "未选择壁纸"
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideMiddle
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentWallpaperPath
                        color: Appearance.colors.colSubtext
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideMiddle
                        visible: root.currentWallpaperPath !== ""
                    }

                    SegmentedButtonGroup {
                        Layout.alignment: Qt.AlignLeft
                        model: [
                            ({ "value": "previous", "label": "上一张" }),
                            ({ "value": "random", "label": "随机" }),
                            ({ "value": "next", "label": "下一张" })
                        ]
                        currentValue: ""
                        onValueSelected: value => {
                            if (value === "previous")
                                WallpaperService.cyclePrevious();
                            else if (value === "random")
                                WallpaperService.cycleRandom();
                            else
                                WallpaperService.cycleNext();
                        }
                    }
                }
            }

            SegmentedButtonGroup {
                id: fillModeButtonGroup

                Layout.alignment: Qt.AlignHCenter
                model: PersonalizationConfig.fillModes
                currentValue: PersonalizationConfig.wallpaperFillMode
                Component.onCompleted: root.fillModeGroupRestingWidth = implicitWidth
                onValueSelected: value => WallpaperService.setWallpaperFillMode(value)
            }
        }

        Section {
            title: "过渡效果"
            iconName: "animation"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "动画效果"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.fillModeGroupRestingWidth > 0 ? root.fillModeGroupRestingWidth : implicitWidth
                    Layout.preferredHeight: transitionButtonColumn.implicitHeight

                    ColumnLayout {
                        id: transitionButtonColumn

                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        SegmentedButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            model: PersonalizationConfig.transitionTypes.slice(0, 5)
                            currentValue: PersonalizationConfig.wallpaperTransitionType
                            horizontalPadding: 24
                            onValueSelected: value => WallpaperService.setWallpaperTransitionType(value)
                        }

                        SegmentedButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            model: PersonalizationConfig.transitionTypes.slice(5, 9)
                            currentValue: PersonalizationConfig.wallpaperTransitionType
                            horizontalPadding: 24
                            onValueSelected: value => WallpaperService.setWallpaperTransitionType(value)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "过渡时间"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    MaterialAccessibleSlider {
                        id: transitionDurationSlider

                        Layout.preferredWidth: Math.min(460, Math.max(330, root.pageContentWidth - 140))
                        Layout.preferredHeight: 72
                        from: 0
                        to: 5000
                        stepSize: 50
                        value: PersonalizationConfig.transitionDurationMs
                        accessibleName: "壁纸过渡时间"
                        valueFormatter: sliderValue => Math.round(sliderValue).toString()
                        onMoved: WallpaperService.setTransitionDurationMs(Math.round(transitionDurationSlider.value))
                    }

                    Item {
                        id: transitionDurationEditor

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 92
                        Layout.preferredHeight: 36

                        property bool editing: false
                        property bool invalid: false
                        property string draft: ""

                        function startEdit() {
                            draft = String(PersonalizationConfig.transitionDurationMs);
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

                            WallpaperService.setTransitionDurationMs(Math.max(0, Math.min(5000, Math.round(value))));
                            invalid = false;
                            editing = false;
                        }

                        function cancelEdit() {
                            invalid = false;
                            editing = false;
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.extraSmall
                            color: transitionDurationEditor.editing
                                   ? Appearance.colors.colLayer2
                                   : durationValueMouse.containsMouse
                                     ? Appearance.colors.colLayer1Hover
                                     : "transparent"
                            border.width: transitionDurationEditor.editing ? 1 : 0
                            border.color: transitionDurationEditor.invalid ? Appearance.colors.colError : Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.28)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.expressiveEffects.duration
                                    easing.type: Appearance.animation.expressiveEffects.type
                                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !transitionDurationEditor.editing
                            text: PersonalizationConfig.transitionDurationMs + " ms"
                            color: durationValueMouse.containsMouse ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        TextField {
                            id: transitionDurationInput

                            anchors.fill: parent
                            visible: transitionDurationEditor.editing
                            text: transitionDurationEditor.draft
                            color: Appearance.colors.colOnSurface
                            selectedTextColor: Appearance.colors.colOnPrimary
                            selectionColor: Appearance.colors.colPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            selectByMouse: true
                            validator: IntValidator {
                                bottom: 0
                                top: 5000
                            }
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            padding: 0
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            Material.accent: Appearance.colors.colPrimary
                            background: Item {}
                            onTextChanged: {
                                if (transitionDurationEditor.editing) {
                                    transitionDurationEditor.draft = text;
                                    transitionDurationEditor.invalid = false;
                                }
                            }
                            onVisibleChanged: {
                                if (visible) {
                                    Qt.callLater(() => {
                                        transitionDurationInput.forceActiveFocus();
                                        transitionDurationInput.selectAll();
                                    });
                                }
                            }
                            onEditingFinished: transitionDurationEditor.applyEdit()
                            Keys.onReturnPressed: transitionDurationEditor.applyEdit()
                            Keys.onEnterPressed: transitionDurationEditor.applyEdit()
                            Keys.onEscapePressed: event => {
                                transitionDurationEditor.cancelEdit();
                                event.accepted = true;
                            }
                        }

                        MouseArea {
                            id: durationValueMouse

                            anchors.fill: parent
                            enabled: !transitionDurationEditor.editing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: transitionDurationEditor.startEdit()
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "缓动曲线"
                    color: Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    property real controlsWidth: 172
                    property real chartSide: Math.min(420, Math.max(360, root.pageContentWidth - controlsWidth - spacing))

                    BezierCurveEditor {
                        id: easingCurveEditor

                        Layout.preferredWidth: parent.chartSide
                        Layout.preferredHeight: implicitHeight
                        chartSize: parent.chartSide
                        curve: PersonalizationConfig.transitionBezierCurve
                        easingMode: PersonalizationConfig.transitionEasingMode
                        playDurationMs: Math.max(200, PersonalizationConfig.transitionDurationMs)
                        onControlsEdited: nextCurve => WallpaperService.setTransitionBezierCurve(nextCurve)
                        onEditRequested: console.log("edit custom bezier", JSON.stringify(PersonalizationConfig.transitionBezierCurve))
                    }

                    ColumnLayout {
                        Layout.preferredWidth: parent.controlsWidth
                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        spacing: 12

                        EasingActionGroup {
                            Layout.alignment: Qt.AlignLeft
                            playing: easingCurveEditor.playing
                            flipEnabled: easingCurveEditor.editable
                            onPlayClicked: easingCurveEditor.togglePlayback()
                            onReplayClicked: easingCurveEditor.reversePlayback()
                            onFlipClicked: easingCurveEditor.flipCurve()
                        }

                        Rectangle {
                            id: editBezierButton

                            Layout.alignment: Qt.AlignLeft
                            Layout.preferredWidth: 154
                            Layout.preferredHeight: 44
                            enabled: easingCurveEditor.editable
                            opacity: enabled ? 1 : 0.45
                            radius: 13
                            clip: true
                            color: editBezierMouse.pressed
                                   ? Appearance.colors.colPrimaryContainerActive
                                   : editBezierMouse.containsMouse
                                     ? Appearance.colors.colPrimaryContainerHover
                                     : Appearance.colors.colPrimaryContainer

                            function startRipple(x, y) {
                                ripple.centerX = x;
                                ripple.centerY = y;
                                rippleAnimation.diameter = Math.sqrt(width * width + height * height) * 2.2;
                                rippleAnimation.restart();
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.expressiveEffects.duration
                                    easing.type: Appearance.animation.expressiveEffects.type
                                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                }
                            }

                            Rectangle {
                                id: ripple

                                property real centerX: editBezierButton.width / 2
                                property real centerY: editBezierButton.height / 2
                                property real diameter: 0

                                x: centerX - width / 2
                                y: centerY - height / 2
                                width: diameter
                                height: diameter
                                radius: width / 2
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0
                                visible: opacity > 0
                            }

                            ParallelAnimation {
                                id: rippleAnimation

                                property real diameter: 0

                                NumberAnimation {
                                    target: ripple
                                    property: "diameter"
                                    from: 0
                                    to: rippleAnimation.diameter
                                    duration: Appearance.animation.standardLarge.duration
                                    easing.type: Appearance.animation.standardDecel.type
                                    easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
                                }

                                NumberAnimation {
                                    target: ripple
                                    property: "opacity"
                                    from: 0.18
                                    to: 0
                                    duration: Appearance.animation.standardLarge.duration
                                    easing.type: Appearance.animation.standardDecel.type
                                    easing.bezierCurve: Appearance.animation.standardDecel.bezierCurve
                                }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                MaterialSymbol {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    text: "edit"
                                    iconSize: 19
                                    fill: 1
                                    color: Appearance.colors.colOnPrimaryContainer
                                }

                                Text {
                                    text: "编辑贝塞尔"
                                    color: Appearance.colors.colOnPrimaryContainer
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: editBezierMouse

                                anchors.fill: parent
                                enabled: editBezierButton.enabled
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => {
                                    if (mouse.button === Qt.LeftButton)
                                        editBezierButton.startRipple(mouse.x, mouse.y);
                                }
                                onClicked: easingCurveEditor.openCoordinateEditor()
                            }
                        }

                        SplitMenuButton {
                            Layout.alignment: Qt.AlignLeft
                            minimumWidth: 136
                            maximumWidth: 172
                            model: PersonalizationConfig.transitionEasingModes
                            currentValue: PersonalizationConfig.transitionEasingMode
                            onValueSelected: value => WallpaperService.setTransitionEasingMode(value)
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
        }
    }

    WallpaperFileBrowser {
        id: wallpaperFileBrowser
        startPath: PersonalizationConfig.wallpaperFolder
        onFolderSelected: path => {
            WallpaperService.setWallpaperFolder(path);
        }
        onFileSelected: path => {
            const folder = WallpaperService.parentFolder(path);
            if (folder !== "")
                WallpaperService.setWallpaperFolder(folder);
            WallpaperService.setWallpaper(path);
        }
    }

    WallpaperColorPicker {
        id: wallpaperColorPicker
        onColorSelected: color => WallpaperService.setWallpaper(color)
    }
}
