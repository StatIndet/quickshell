import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Services
import qs.Components
import qs.Widgets.common

StyledFlickable {
    id: root

    property var parentModal: null
    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 20

    property string selectedDesktopOutput: ""
    property string selectedOverviewOutput: ""
    readonly property bool desktopUsesAwww: PersonalizationConfig.desktopWallpaperBackend === "awww"
    readonly property bool awwwStepSupported: AwwwWallpaperService.supportsStep(
                                                  PersonalizationConfig.awwwDesktopTransitionType)
    readonly property bool awwwDurationSupported: AwwwWallpaperService.supportsDuration(
                                                      PersonalizationConfig.awwwDesktopTransitionType)
    readonly property bool awwwBezierSupported: AwwwWallpaperService.supportsBezier(
                                                    PersonalizationConfig.awwwDesktopTransitionType)
    readonly property bool sharedTransitionParametersEnabled: desktopUsesAwww ? awwwDurationSupported
                                                                                && awwwBezierSupported :
                                                                                PersonalizationConfig.wallpaperTransitionType
                                                                                !== "none"
    readonly property var outputOptions: {
        const result = [({
                             "value": "",
                             "label": qsTr("Global")
                         })];
        for (let index = 0; index < Quickshell.screens.length; index += 1) {
            const name = String(Quickshell.screens[index].name);
            result.push({
                            "value": name,
                            "label": name
                        });
        }
        return result;
    }
    readonly property string currentWallpaperPath: WallpaperService.wallpaperForScreen(selectedDesktopOutput)
    readonly property string currentOverviewPath: WallpaperService.overviewWallpaperForScreen(
                                                      selectedOverviewOutput)
    readonly property bool currentWallpaperIsColor: WallpaperService.isColorSource(currentWallpaperPath)
    readonly property bool currentWallpaperIsImage: currentWallpaperPath !== "" && !currentWallpaperIsColor
    readonly property string currentDesktopFillMode: selectedDesktopOutput !== ""
                                                     ? PersonalizationConfig.monitorFillMode(
                                                           selectedDesktopOutput) :
                                                       PersonalizationConfig.wallpaperFillMode
    readonly property bool panoramaSelected: currentDesktopFillMode === "panorama"
    readonly property real effectivePreferredScale: panoramaSelected ? 1 :
                                                                       PersonalizationConfig.parallaxPreferredScale
    readonly property bool preferredScaleControlEnabled: !desktopUsesAwww && !panoramaSelected
    readonly property var desktopFillModeOptions: PersonalizationConfig.desktopFillModes.map(option => ({
        "value": option.value,
        "label": option.label,
        "enabled": root.desktopFillModeOptionEnabled(option.value, root.desktopUsesAwww)
    }))
    readonly property real pageContentWidth: 600
    property real fillModeGroupRestingWidth: 0

    Component.onCompleted: WallpaperService.refreshOverviewBackdropRule()

    function chooseWallpaperFile() {
        const base = root.currentWallpaperIsImage ? WallpaperService.parentFolder(root.currentWallpaperPath) :
                                                    PersonalizationConfig.wallpaperFolder;
        wallpaperFileBrowser.openAt(base || PersonalizationConfig.wallpaperFolder);
    }

    function chooseWallpaperColor() {
        wallpaperColorPicker.showWithColor(root.currentWallpaperIsColor ? root.currentWallpaperPath :
                                                                          Appearance.colors.colPrimary);
    }

    function closeChildWindows() {
        wallpaperFileBrowser.dismiss();
        wallpaperColorPicker.close();
        overviewFileBrowser.dismiss();
        overviewColorPicker.close();
        bezierCurveLayerEditor.dismiss();
    }

    function chooseOverviewFile() {
        const source = root.currentOverviewPath;
        const base = source !== "" && !WallpaperService.isColorSource(source) ? WallpaperService.parentFolder(
                                                                                    source) : PersonalizationConfig.wallpaperFolder;
        overviewFileBrowser.openAt(base || PersonalizationConfig.wallpaperFolder);
    }

    function chooseOverviewColor() {
        const source = root.currentOverviewPath;
        overviewColorPicker.showWithColor(WallpaperService.isColorSource(source) ? source :
                                                                                   Appearance.colors.colPrimary);
    }

    function desktopFillModeOptionEnabled(value, usesAwww) {
        return value !== "panorama" || !usesAwww;
    }

    component Section: ColumnLayout {
        id: section

        property string title: ""
        property string iconName: "settings"
        property alias headerTrailing: headerTrailingSlot.data
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

            RowLayout {
                id: headerTrailingSlot

                Layout.alignment: Qt.AlignVCenter
                spacing: Metrics.spacingS
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 12
        }
    }

    component FlatSettingsSection: SettingsSection {
        color: "transparent"
        radius: 0
    }

    component HoverActionButton: IconButton {
        id: action

        property bool darkOverlay: false

        controlSize: 32
        iconSize: 18
        iconFill: 1
        iconColor: action.darkOverlay ? "white" : Appearance.colors.colOnSurface
        normalContainerColor: action.darkOverlay ? Appearance.applyAlpha("white", 0.18) :
                                                   Appearance.colors.colSurfaceContainerHigh
        hoverStateLayerColor: action.darkOverlay ? Appearance.applyAlpha("white", 0.28) :
                                                   Appearance.colors.colSurfaceContainerHighest
        pressedStateLayerColor: action.darkOverlay ? Appearance.applyAlpha("white", 0.36) :
                                                     Appearance.colors.colLayer3Active
    }

    component WallpaperPreview: Item {
        id: preview

        property string sourcePath: ""
        property bool actionsEnabled: true
        readonly property bool sourceIsColor: WallpaperService.isColorSource(sourcePath)
        readonly property bool sourceIsImage: sourcePath !== "" && !sourceIsColor

        signal chooseFile
        signal chooseColor
        signal clearWallpaper

        implicitWidth: 340
        implicitHeight: 200

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: preview.sourceIsColor ? preview.sourcePath : Appearance.colors.colLayer2
        }

        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: preview.sourceIsImage ? Paths.fileUrl(preview.sourcePath) : ""
            sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio * 2)), Math.max(1,
                                                                                                      Math.ceil(
                                                                                                          height * Screen.devicePixelRatio
                                                                                                          * 2)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: false
            mipmap: false
            visible: source !== ""
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: previewMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }

        Rectangle {
            id: previewMask
            anchors.fill: parent
            anchors.margins: 1
            radius: Appearance.rounding.normal - 1
            color: Appearance.m3colors.m3scrim
            visible: false
            layer.enabled: true
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "image"
            iconSize: 34
            color: Appearance.colors.colOnSurfaceVariant
            visible: preview.sourcePath === ""
        }

        HoverHandler {
            id: previewHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.applyAlpha(Appearance.m3colors.m3scrim, 0.7)
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
                    tooltipText: qsTr("Choose folder")
                    darkOverlay: true
                    enabled: preview.actionsEnabled
                    onClicked: preview.chooseFile()
                }

                HoverActionButton {
                    iconName: "palette"
                    tooltipText: qsTr("Choose color")
                    darkOverlay: true
                    enabled: preview.actionsEnabled
                    onClicked: preview.chooseColor()
                }

                HoverActionButton {
                    iconName: "clear"
                    tooltipText: qsTr("Clear wallpaper")
                    darkOverlay: true
                    enabled: preview.actionsEnabled
                    onClicked: preview.clearWallpaper()
                }
            }
        }
    }

    component EasingActionGroup: StyledButtonGroup {
        id: group

        property bool playing: false
        property bool flipEnabled: true

        signal playClicked
        signal replayClicked
        signal flipClicked

        iconOnly: true
        buttonHeight: 38
        buttonMinWidth: 44
        horizontalPadding: 23
        currentValue: group.playing ? "play" : ""
        model: [({
                     "value": "play",
                     "icon": group.playing ? "pause" : "play_arrow",
                     "tooltip": group.playing ? qsTr("Pause") : qsTr("Play")
                 }), ({
                          "value": "replay",
                          "icon": "keyboard_double_arrow_left",
                          "tooltip": qsTr("Reverse")
                      }), ({
                               "value": "flip",
                               "icon": "swap_vert",
                               "tooltip": qsTr("Flip"),
                               "enabled": group.flipEnabled
                           })]
        onValueSelected: value => {
            if (value === "play")
                group.playClicked();
            else if (value === "replay")
                group.replayClicked();
            else if (value === "flip")
                group.flipClicked();
        }
    }

    ColumnLayout {
        id: contentColumn
        width: root.pageContentWidth
        x: Math.max(24, (root.width - width) / 2)
        y: 24
        spacing: 30

        Component {
            id: desktopManagerSectionComponent

            Section {
                title: qsTr("Desktop wallpaper manager")
                iconName: "display_settings"

                headerTrailing: SearchSelectMenuField {
                    Layout.preferredWidth: 168
                    Layout.preferredHeight: Metrics.controlHeightM
                    options: [({
                                   "value": "quickshell",
                                   "label": "Quickshell",
                                   "enabled": true
                               }), ({
                                        "value": "awww",
                                        "label": "awww",
                                        "enabled": AwwwWallpaperService.available,
                                        "tooltip": AwwwWallpaperService.available ? "" :
                                                                                    AwwwWallpaperService.probeComplete
                                                                                    ? qsTr("The awww or awww-daemon command is missing") :
                                                                                      qsTr("Detecting awww…")
                                    })]
                    value: PersonalizationConfig.desktopWallpaperBackend
                    Accessible.name: qsTr("Desktop wallpaper manager")
                    onAccepted: value => WallpaperService.setDesktopWallpaperBackend(value)
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible: AwwwWallpaperService.lastError !== "" || WallpaperService.lastDesktopError !== ""
                    tone: "error"
                    message: AwwwWallpaperService.lastError !== "" ? AwwwWallpaperService.lastError :
                                                                     WallpaperService.lastDesktopError
                }
            }
        }

        Component {
            id: currentWallpaperSectionComponent

            Section {
                title: qsTr("Current wallpaper")
                iconName: "wallpaper"

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 24

                    WallpaperPreview {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 340
                        Layout.preferredHeight: 200
                        sourcePath: root.currentWallpaperPath
                        onChooseFile: root.chooseWallpaperFile()
                        onChooseColor: root.chooseWallpaperColor()
                        onClearWallpaper: WallpaperService.clearWallpaper(root.selectedDesktopOutput)
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Math.min(450, Math.max(330, root.width - 420))
                        spacing: 12

                        Text {
                            Layout.fillWidth: true
                            text: root.currentWallpaperPath !== "" ? WallpaperService.basename(
                                                                         root.currentWallpaperPath) : qsTr(
                                                                         "No wallpaper selected")
                            color: Appearance.colors.colOnSurface
                            font.family: Fonts.ui
                            font.pixelSize: 22
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideMiddle
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.currentWallpaperPath
                            color: Appearance.colors.colSubtext
                            font.family: Fonts.mono
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideMiddle
                            visible: root.currentWallpaperPath !== ""
                        }

                        StyledButtonGroup {
                            Layout.alignment: Qt.AlignLeft
                            model: [({
                                         "value": "previous",
                                         "label": qsTr("Previous")
                                     }), ({
                                              "value": "random",
                                              "label": qsTr("Random")
                                          }), ({
                                                   "value": "next",
                                                   "label": qsTr("Next")
                                               })]
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

                StyledButtonGroup {
                    id: fillModeButtonGroup

                    Layout.alignment: Qt.AlignHCenter
                    model: root.desktopFillModeOptions
                    currentValue: root.currentDesktopFillMode
                    Component.onCompleted: root.fillModeGroupRestingWidth = implicitWidth
                    onValueSelected: value => WallpaperService.setWallpaperFillModeForScreen(
                                                  root.selectedDesktopOutput, value)
                }

                FlatSettingsSection {
                    Layout.fillWidth: true

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "splitscreen"
                        title: qsTr("Per-monitor wallpapers")

                        trailing: StyledSwitch {
                            checked: PersonalizationConfig.perMonitorWallpaper
                            Accessible.name: qsTr("Per-monitor wallpapers")
                            onToggled: PersonalizationConfig.setPerMonitorWallpaper(checked)
                        }
                    }

                    SearchSelectMenuField {
                        Layout.fillWidth: true
                        options: root.outputOptions
                        value: root.selectedDesktopOutput
                        placeholder: qsTr("Select output")
                        Accessible.name: qsTr("Desktop wallpaper output")
                        onAccepted: value => root.selectedDesktopOutput = value
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            sourceComponent: currentWallpaperSectionComponent
        }

        Loader {
            Layout.fillWidth: true
            sourceComponent: desktopManagerSectionComponent
        }

        Section {
            title: qsTr("Transition")
            iconName: "animation"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Transition type")
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.fillModeGroupRestingWidth > 0
                                           ? root.fillModeGroupRestingWidth : implicitWidth
                    Layout.preferredHeight: transitionButtonColumn.implicitHeight

                    ColumnLayout {
                        id: transitionButtonColumn

                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        StyledButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            model: root.desktopUsesAwww ? PersonalizationConfig.awwwTransitionTypes.slice(0,
                                                                                                          5) : PersonalizationConfig.transitionTypes.slice(
                                                              0, 5)
                            currentValue: root.desktopUsesAwww
                                          ? PersonalizationConfig.awwwDesktopTransitionType :
                                            PersonalizationConfig.wallpaperTransitionType
                            horizontalPadding: 24
                            onValueSelected: value => {
                                if (root.desktopUsesAwww)
                                    PersonalizationConfig.setAwwwDesktopTransitionType(value);
                                else
                                    WallpaperService.setWallpaperTransitionType(value);
                            }
                        }

                        StyledButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            model: root.desktopUsesAwww ? PersonalizationConfig.awwwTransitionTypes.slice(5,
                                                                                                          10) : PersonalizationConfig.transitionTypes.slice(
                                                              5, 9)
                            currentValue: root.desktopUsesAwww
                                          ? PersonalizationConfig.awwwDesktopTransitionType :
                                            PersonalizationConfig.wallpaperTransitionType
                            horizontalPadding: 24
                            onValueSelected: value => {
                                if (root.desktopUsesAwww)
                                    PersonalizationConfig.setAwwwDesktopTransitionType(value);
                                else
                                    WallpaperService.setWallpaperTransitionType(value);
                            }
                        }

                        StyledButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.desktopUsesAwww
                            model: PersonalizationConfig.awwwTransitionTypes.slice(10, 14)
                            currentValue: PersonalizationConfig.awwwDesktopTransitionType
                            horizontalPadding: 24
                            onValueSelected: value => PersonalizationConfig.setAwwwDesktopTransitionType(
                                                          value)
                        }
                    }
                }
            }

            ColumnLayout {
                id: fpsSetting

                Layout.fillWidth: true
                spacing: 6
                opacity: root.desktopUsesAwww && root.awwwStepSupported ? 1 : 0.45

                HoverHandler {
                    id: fpsHover
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("awww FPS")
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                MaterialSlider {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(520, root.pageContentWidth - 60)
                    from: 10
                    to: 240
                    stepSize: 5
                    value: PersonalizationConfig.awwwTransitionFps
                    enabled: root.desktopUsesAwww && root.awwwStepSupported
                    accessibleName: qsTr("awww transition FPS")
                    valueFormatter: sliderValue => Math.round(sliderValue) + " FPS"
                    onMoved: PersonalizationConfig.setAwwwTransitionFps(Math.round(value))
                }

                StyledToolTip {
                    extraVisibleCondition: fpsHover.hovered && (!root.desktopUsesAwww ||
                                                                !root.awwwStepSupported)
                    text: root.desktopUsesAwww ? qsTr("The none transition does not use FPS.") : qsTr(
                                                     "Independent FPS is available only with awww.")
                }
            }

            ColumnLayout {
                id: stepSetting

                Layout.fillWidth: true
                spacing: 6
                opacity: root.desktopUsesAwww && root.awwwStepSupported ? 1 : 0.45

                HoverHandler {
                    id: stepHover
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Transition step · %1").arg(PersonalizationConfig.awwwTransitionStep)
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                MaterialSlider {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(520, root.pageContentWidth - 60)
                    from: 0
                    to: 255
                    stepSize: 1
                    value: PersonalizationConfig.awwwTransitionStep
                    enabled: root.desktopUsesAwww && root.awwwStepSupported
                    accessibleName: qsTr("awww transition step")
                    valueFormatter: sliderValue => Math.round(sliderValue).toString()
                    onMoved: PersonalizationConfig.setAwwwTransitionStep(Math.round(value))
                }

                StyledToolTip {
                    extraVisibleCondition: stepHover.hovered
                    text: !root.desktopUsesAwww ? qsTr(
                                                      "Transition step is only available with the awww desktop backend.") :
                                                  !root.awwwStepSupported ? qsTr(
                                                                                "The none transition does not use transition step.") :
                                                                            qsTr("Step controls the amount of change per frame.")
                }
            }

            ColumnLayout {
                id: durationSetting

                Layout.fillWidth: true
                spacing: 6
                opacity: root.sharedTransitionParametersEnabled ? 1 : 0.45

                HoverHandler {
                    id: durationHover
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Transition duration")
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }

                    Text {
                        text: PersonalizationConfig.transitionDurationMs + " ms"
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.numeric
                        font.pixelSize: Typography.bodyMedium.pixelSize
                        font.weight: Font.Medium
                    }
                }

                MaterialSlider {
                    id: transitionDurationSlider

                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    from: 0
                    to: 5000
                    stepSize: 50
                    value: PersonalizationConfig.transitionDurationMs
                    enabled: root.sharedTransitionParametersEnabled
                    accessibleName: qsTr("Wallpaper transition duration")
                    valueFormatter: sliderValue => Math.round(sliderValue).toString()
                    onMoved: value => WallpaperService.setTransitionDurationMs(Math.round(value))
                }

                StyledToolTip {
                    extraVisibleCondition: durationHover.hovered && !root.sharedTransitionParametersEnabled
                    text: qsTr("The current transition does not use duration.")
                }
            }

            ColumnLayout {
                id: bezierSetting

                Layout.fillWidth: true
                spacing: 10
                opacity: root.sharedTransitionParametersEnabled ? 1 : 0.45

                HoverHandler {
                    id: bezierHover
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Easing curve")
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                RowLayout {
                    id: bezierControls

                    Layout.fillWidth: true
                    spacing: 20
                    enabled: root.sharedTransitionParametersEnabled

                    property real controlsWidth: 172
                    property real chartSide: Math.min(420, Math.max(360, root.pageContentWidth
                                                                    - controlsWidth - spacing))

                    BezierCurveEditor {
                        id: easingCurveEditor

                        Layout.preferredWidth: parent.chartSide
                        Layout.preferredHeight: implicitHeight
                        chartSize: parent.chartSide
                        curve: PersonalizationConfig.transitionBezierCurve
                        easingMode: PersonalizationConfig.transitionEasingMode
                        playDurationMs: Math.max(200, PersonalizationConfig.transitionDurationMs)
                        onControlsEdited: nextCurve => WallpaperService.setTransitionBezierCurve(nextCurve)
                        onEditRequested: bezierCurveLayerEditor.openWithCurve(
                                             PersonalizationConfig.transitionBezierCurve)
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

                        RippleButton {
                            id: editBezierButton

                            Layout.alignment: Qt.AlignLeft
                            Layout.preferredWidth: 154
                            Layout.preferredHeight: 44
                            enabled: easingCurveEditor.editable
                            opacity: enabled ? 1 : 0.45
                            buttonRadius: 13
                            containerColor: Appearance.colors.colPrimaryContainer
                            rippleColor: Appearance.colors.colOnPrimaryContainer
                            stateLayerColor: Appearance.colors.colPrimaryContainerHover
                            pressedStateLayerColor: Appearance.colors.colPrimaryContainerActive
                            Accessible.name: qsTr("Edit Bézier curve")
                            onClicked: easingCurveEditor.openCoordinateEditor()

                            contentItem: ButtonLabel {
                                iconName: "edit"
                                primaryText: qsTr("Edit Bézier curve")
                                spacing: 8
                                iconSize: 19
                                iconFill: 1
                                iconColor: Appearance.colors.colOnPrimaryContainer
                                primaryColor: Appearance.colors.colOnPrimaryContainer
                                primaryPixelSize: 14
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

                StyledToolTip {
                    extraVisibleCondition: bezierHover.hovered && !root.sharedTransitionParametersEnabled
                    text: qsTr("The current transition does not use an easing curve.")
                }
            }
        }

        Section {
            title: qsTr("Parallax effects")
            iconName: "view_in_ar"

            FlatSettingsSection {
                id: parallaxSection

                Layout.fillWidth: true
                opacity: root.desktopUsesAwww ? 0.45 : 1

                HoverHandler {
                    id: parallaxHover
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "swap_vert"
                    title: qsTr("Vertical parallax")

                    trailing: StyledSwitch {
                        enabled: !root.desktopUsesAwww
                        checked: PersonalizationConfig.parallaxVerticalEnabled
                        Accessible.name: qsTr("Vertical parallax")
                        onToggled: PersonalizationConfig.setParallaxVerticalEnabled(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "workspaces"
                    title: qsTr("Follow workspaces")

                    trailing: Item {
                        Layout.preferredWidth: workspaceParallaxSwitch.implicitWidth
                        Layout.preferredHeight: workspaceParallaxSwitch.implicitHeight

                        HoverHandler {
                            id: workspaceParallaxHover
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        }

                        StyledSwitch {
                            id: workspaceParallaxSwitch

                            anchors.centerIn: parent
                            enabled: !root.desktopUsesAwww && PersonalizationConfig.parallaxVerticalEnabled
                            checked: PersonalizationConfig.parallaxFollowWorkspaces
                            Accessible.name: qsTr("Follow workspaces")
                            onToggled: PersonalizationConfig.setParallaxFollowWorkspaces(checked)
                        }

                        StyledToolTip {
                            extraVisibleCondition: workspaceParallaxHover.hovered && !root.desktopUsesAwww &&
                                                   !PersonalizationConfig.parallaxVerticalEnabled
                            text: qsTr("Enable vertical parallax first.")
                        }
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "dock_to_left"
                    title: qsTr("Follow sidebars")

                    trailing: StyledSwitch {
                        enabled: !root.desktopUsesAwww
                        checked: PersonalizationConfig.parallaxFollowSidebars
                        Accessible.name: qsTr("Follow sidebars")
                        onToggled: PersonalizationConfig.setParallaxFollowSidebars(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "view_column"
                    title: qsTr("Follow tiled-window focus")

                    trailing: StyledSwitch {
                        enabled: !root.desktopUsesAwww
                        checked: PersonalizationConfig.parallaxFollowTiledColumns
                        Accessible.name: qsTr("Follow tiled-window focus")
                        onToggled: PersonalizationConfig.setParallaxFollowTiledColumns(checked)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Wallpaper scale")
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodyMedium.pixelSize
                        font.weight: Font.Medium
                    }

                    MaterialSlider {
                        Layout.fillWidth: true
                        enabled: root.preferredScaleControlEnabled
                        from: 1
                        to: 1.35
                        stepSize: 0.01
                        value: root.effectivePreferredScale
                        accessibleName: qsTr("Wallpaper scale")
                        valueFormatter: sliderValue => Number(sliderValue).toFixed(2)
                        onMoved: PersonalizationConfig.setParallaxPreferredScale(value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Horizontal travel columns")
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodyMedium.pixelSize
                        font.weight: Font.Medium
                    }

                    MaterialSlider {
                        Layout.fillWidth: true
                        enabled: !root.desktopUsesAwww
                        from: 2
                        to: 12
                        stepSize: 1
                        value: PersonalizationConfig.parallaxTiledColumnSpan
                        accessibleName: qsTr("Horizontal travel columns")
                        valueFormatter: sliderValue => Math.round(sliderValue).toString()
                        onMoved: PersonalizationConfig.setParallaxTiledColumnSpan(Math.round(value))
                    }
                }

                StyledToolTip {
                    extraVisibleCondition: parallaxHover.hovered && root.desktopUsesAwww
                    text: qsTr("Desktop parallax is available only with Quickshell.")
                }
            }
        }

        Section {
            title: qsTr("Overview background")
            iconName: "overview"

            FlatSettingsSection {
                Layout.fillWidth: true

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible: WallpaperService.overviewBackdropRuleProbeComplete &&
                             !WallpaperService.overviewBackdropRuleDetected
                    tone: "error"
                    message: qsTr(
                                 "The niri backdrop rule is missing. Configure clavis-overview-wallpaper manually as documented.")
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible: WallpaperService.overviewBackdropRuleProbeComplete &&
                             !WallpaperService.niriTransparentBackgroundDetected
                    tone: "error"
                    message: qsTr(
                                 "The niri workspace background is opaque. Manually set background-color \"transparent\" in layout.")
                }

                WallpaperPreview {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 176
                    sourcePath: root.currentOverviewPath
                    actionsEnabled: !PersonalizationConfig.overviewUseDesktopWallpaper
                    onChooseFile: root.chooseOverviewFile()
                    onChooseColor: root.chooseOverviewColor()
                    onClearWallpaper: WallpaperService.clearOverviewWallpaper(root.selectedOverviewOutput)
                }

                StyledButtonGroup {
                    Layout.alignment: Qt.AlignHCenter
                    model: PersonalizationConfig.fillModes
                    currentValue: root.selectedOverviewOutput !== ""
                                  ? PersonalizationConfig.overviewMonitorFillMode(
                                        root.selectedOverviewOutput) :
                                    PersonalizationConfig.overviewWallpaperFillMode
                    onValueSelected: value => WallpaperService.setOverviewFillModeForScreen(
                                                  root.selectedOverviewOutput, value)
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "visibility"
                    title: qsTr("Enable background")

                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.overviewEnabled
                        Accessible.name: qsTr("Enable background")
                        onToggled: PersonalizationConfig.setOverviewEnabled(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "sync"
                    title: qsTr("Use desktop wallpaper")

                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.overviewUseDesktopWallpaper
                        Accessible.name: qsTr("Use desktop wallpaper")
                        onToggled: PersonalizationConfig.setOverviewUseDesktopWallpaper(checked)
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    iconName: "splitscreen"
                    title: qsTr("Per-monitor wallpapers")

                    trailing: StyledSwitch {
                        checked: PersonalizationConfig.overviewPerMonitorWallpaper
                        Accessible.name: qsTr("Per-monitor wallpapers")
                        onToggled: PersonalizationConfig.setOverviewPerMonitorWallpaper(checked)
                    }
                }

                SearchSelectMenuField {
                    Layout.fillWidth: true
                    options: root.outputOptions
                    value: root.selectedOverviewOutput
                    placeholder: qsTr("Select output")
                    Accessible.name: qsTr("Overview wallpaper output")
                    onAccepted: value => root.selectedOverviewOutput = value
                }
            }

            FlatSettingsSection {
                Layout.fillWidth: true
                title: qsTr("Transition type")

                StyledButtonGroup {
                    Layout.alignment: Qt.AlignHCenter
                    model: PersonalizationConfig.transitionTypes.slice(0, 5)
                    currentValue: PersonalizationConfig.overviewTransitionType
                    onValueSelected: value => PersonalizationConfig.setOverviewTransitionType(value)
                }

                StyledButtonGroup {
                    Layout.alignment: Qt.AlignHCenter
                    model: PersonalizationConfig.transitionTypes.slice(5, 9)
                    currentValue: PersonalizationConfig.overviewTransitionType
                    onValueSelected: value => PersonalizationConfig.setOverviewTransitionType(value)
                }
            }

            FlatSettingsSection {
                Layout.fillWidth: true
                title: qsTr("Image effects")
                opacity: PersonalizationConfig.overviewEnabled ? 1 : 0.45

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("Blur")
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodyMedium.pixelSize
                    }

                    MaterialSlider {
                        Layout.fillWidth: true
                        enabled: PersonalizationConfig.overviewEnabled
                        from: 0
                        to: 100
                        stepSize: 1
                        value: PersonalizationConfig.overviewBlurRadius
                        accessibleName: qsTr("Overview blur")
                        valueFormatter: value => Math.round(value) + "%"
                        onMoved: PersonalizationConfig.setOverviewBlurRadius(value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("Dim")
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodyMedium.pixelSize
                    }

                    MaterialSlider {
                        Layout.fillWidth: true
                        enabled: PersonalizationConfig.overviewEnabled
                        from: 0
                        to: 1
                        stepSize: 0.01
                        value: PersonalizationConfig.overviewDim
                        accessibleName: qsTr("Overview dimming")
                        valueFormatter: value => Math.round(value * 100) + "%"
                        onMoved: PersonalizationConfig.setOverviewDim(value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("Saturation")
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodyMedium.pixelSize
                    }

                    MaterialSlider {
                        Layout.fillWidth: true
                        enabled: PersonalizationConfig.overviewEnabled
                        from: 0
                        to: 2
                        stepSize: 0.05
                        value: PersonalizationConfig.overviewSaturation
                        accessibleName: qsTr("Overview saturation")
                        valueFormatter: value => Number(value).toFixed(2)
                        onMoved: PersonalizationConfig.setOverviewSaturation(value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("Contrast")
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.ui
                        font.pixelSize: Typography.bodyMedium.pixelSize
                    }

                    MaterialSlider {
                        Layout.fillWidth: true
                        enabled: PersonalizationConfig.overviewEnabled
                        from: 0.5
                        to: 2
                        stepSize: 0.05
                        value: PersonalizationConfig.overviewContrast
                        accessibleName: qsTr("Overview contrast")
                        valueFormatter: value => Number(value).toFixed(2)
                        onMoved: PersonalizationConfig.setOverviewContrast(value)
                    }
                }

                InlineStatusBanner {
                    Layout.fillWidth: true
                    visible: WallpaperService.lastOverviewError !== ""
                    tone: "error"
                    message: WallpaperService.lastOverviewError
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
        parentModal: root.parentModal
        startPath: PersonalizationConfig.wallpaperFolder
        onFolderSelected: path => {
            WallpaperService.setWallpaperFolder(path);
        }
        onFileSelected: path => {
            WallpaperService.setWallpaperFromFile(path, root.selectedDesktopOutput);
        }
    }

    WallpaperColorPicker {
        id: wallpaperColorPicker
        parentModal: root.parentModal
        onColorSelected: color => WallpaperService.setWallpaper(color, root.selectedDesktopOutput)
    }

    WallpaperFileBrowser {
        id: overviewFileBrowser
        parentModal: root.parentModal
        startPath: PersonalizationConfig.wallpaperFolder
        onFileSelected: path => WallpaperService.setOverviewWallpaper(path, root.selectedOverviewOutput)
    }

    WallpaperColorPicker {
        id: overviewColorPicker
        parentModal: root.parentModal
        onColorSelected: color => WallpaperService.setOverviewWallpaper(color, root.selectedOverviewOutput)
    }

    BezierCurveLayerEditor {
        id: bezierCurveLayerEditor
        parentModal: root.parentModal
        onCurveEdited: nextCurve => WallpaperService.setTransitionBezierCurve(nextCurve)
    }
}
