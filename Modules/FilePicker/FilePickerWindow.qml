import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Common
import qs.Components
import qs.Widgets.common

ApplicationWindow {
    id: root

    property var targetScreen: null
    property string description: "选择一张图片作为用户头像"
    property string startPath: picturesDir
    property var nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif"]
    property string currentPath: startPath
    property string selectedPath: ""
    property string selectedName: ""
    property bool selectedIsDir: false
    property bool showHiddenFiles: false

    readonly property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string desktopDir: StandardPaths.writableLocation(StandardPaths.DesktopLocation)
    readonly property string documentsDir: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
    readonly property string picturesDir: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    readonly property string downloadsDir: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
    readonly property bool selectionValid: selectedPath !== "" && !selectedIsDir

    signal accepted(string path)
    signal rejected()

    visible: false
    title: "选择图片"
    flags: Qt.Window | Qt.FramelessWindowHint
    width: 920
    height: 600
    minimumWidth: 680
    minimumHeight: 440
    color: "transparent"
    Material.theme: Appearance.m3colors.darkmode ? Material.Dark : Material.Light
    Material.accent: Appearance.colors.colPrimary

    onTargetScreenChanged: {
        const mappedScreen = qtScreenFor(targetScreen);
        if (mappedScreen)
            screen = mappedScreen;
    }
    onClosing: event => {
        event.accepted = false;
        dismiss();
    }

    function encodeFileUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split("/").map(segment => encodeURIComponent(segment)).join("/");
    }

    function qtScreenFor(shellScreen) {
        if (!shellScreen)
            return null;
        for (let i = 0; i < Application.screens.length; ++i) {
            const candidate = Application.screens[i];
            if (candidate.name === shellScreen.name)
                return candidate;
        }
        return null;
    }

    function openAt(path) {
        currentPath = path && path !== "" ? path : picturesDir;
        clearSelection();
        const mappedScreen = qtScreenFor(targetScreen);
        if (mappedScreen)
            screen = mappedScreen;
        show();
        raise();
        requestActivate();
        Qt.callLater(() => {
            dialogFocus.forceActiveFocus();
            fileGrid.forceActiveFocus();
        });
    }

    function dismiss() {
        if (!visible)
            return;
        visible = false;
        clearSelection();
        rejected();
    }

    function acceptSelection() {
        if (!selectionValid)
            return;
        const path = selectedPath;
        visible = false;
        clearSelection();
        accepted(path);
    }

    function clearSelection() {
        selectedPath = "";
        selectedName = "";
        selectedIsDir = false;
    }

    function navigateTo(path) {
        if (!path || path === "")
            return;
        currentPath = path;
        clearSelection();
    }

    function navigateUp() {
        if (currentPath === "/")
            return;
        const index = currentPath.lastIndexOf("/");
        navigateTo(index <= 0 ? "/" : currentPath.substring(0, index));
    }

    function selectEntry(path, name, isDir) {
        selectedPath = path;
        selectedName = name;
        selectedIsDir = isDir;
    }

    function openEntry(path, isDir) {
        if (isDir)
            navigateTo(path);
        else {
            selectedPath = path;
            selectedIsDir = false;
            acceptSelection();
        }
    }

    FolderListModel {
        id: folderModel

        folder: root.encodeFileUrl(root.currentPath)
        showDirs: true
        showFiles: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.showHiddenFiles
        caseSensitive: false
        nameFilters: root.nameFilters
        sortField: FolderListModel.Name
    }

    FocusScope {
        id: dialogFocus

        property real revealProgress: root.visible ? 1 : 0

        anchors.fill: parent
        focus: root.visible
        opacity: revealProgress
        scale: 0.97 + revealProgress * 0.03

        Behavior on revealProgress {
            NumberAnimation {
                duration: Appearance.animation.expressiveDefaultSpatial.duration
                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
            }
        }

        Keys.onEscapePressed: event => {
            root.dismiss();
            event.accepted = true;
        }
        Keys.onReturnPressed: event => {
            root.acceptSelection();
            event.accepted = root.selectionValid;
        }
        Keys.onEnterPressed: event => {
            root.acceptSelection();
            event.accepted = root.selectionValid;
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace) {
                root.navigateUp();
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.veryLarge
            color: Appearance.m3colors.m3surface
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            z: -1
            onPressed: event => event.accepted = true
            onClicked: event => event.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Item {
                id: titleBar

                Layout.fillWidth: true
                Layout.preferredHeight: 58

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 2
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colPrimaryContainer

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add_photo_alternate"
                            iconSize: 25
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: root.title
                            color: Appearance.colors.colOnSurface
                            font.family: Sizes.fontFamily
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.description
                            color: Appearance.colors.colSubtext
                            font.family: Sizes.fontFamily
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    PickerToolButton {
                        iconName: "close"
                        tooltipText: "关闭"
                        onClicked: root.dismiss()
                    }
                }

                DragHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton
                    onActiveChanged: {
                        if (active)
                            root.startSystemMove();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 184
                    Layout.fillHeight: true
                    radius: Appearance.rounding.large
                    color: Appearance.colors.colSurfaceContainer

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 5

                        Text {
                            Layout.leftMargin: 12
                            Layout.topMargin: 4
                            Layout.bottomMargin: 6
                            text: "位置"
                            color: Appearance.colors.colOnSurface
                            font.family: Sizes.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        LocationButton { label: "Home"; iconName: "home"; path: root.homeDir }
                        LocationButton { label: "Desktop"; iconName: "desktop_windows"; path: root.desktopDir; visible: path !== "" }
                        LocationButton { label: "Documents"; iconName: "description"; path: root.documentsDir; visible: path !== "" }
                        LocationButton { label: "Pictures"; iconName: "image"; path: root.picturesDir; visible: path !== "" }
                        LocationButton { label: "Downloads"; iconName: "download"; path: root.downloadsDir; visible: path !== "" }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: formatLabel.implicitHeight + 20
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colSurfaceContainerHigh

                            Text {
                                id: formatLabel

                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: "JPG · PNG · WebP\nBMP · GIF"
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Sizes.fontFamily
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSurfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 8

                            PickerToolButton {
                                iconName: "arrow_upward"
                                tooltipText: "上一级"
                                enabled: root.currentPath !== "/"
                                onClicked: root.navigateUp()
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colSurfaceContainerHighest

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    text: root.currentPath
                                    color: Appearance.colors.colOnSurface
                                    font.family: Sizes.fontFamilyMono
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideMiddle
                                }
                            }

                            PickerToolButton {
                                iconName: root.showHiddenFiles ? "visibility_off" : "visibility"
                                tooltipText: root.showHiddenFiles ? "隐藏隐藏文件" : "显示隐藏文件"
                                active: root.showHiddenFiles
                                onClicked: root.showHiddenFiles = !root.showHiddenFiles
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colSurfaceContainer
                        clip: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: folderModel.count === 0

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "scan_delete"
                                iconSize: 52
                                color: Appearance.colors.colOutline
                            }

                            Text {
                                text: "当前文件夹没有可选择的图片"
                                color: Appearance.colors.colSubtext
                                font.family: Sizes.fontFamily
                                font.pixelSize: 14
                            }
                        }

                        StyledGridView {
                            id: fileGrid

                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            cellWidth: width > 0 ? width / Math.max(1, Math.floor(width / 146)) : 146
                            cellHeight: 142
                            model: folderModel

                            delegate: MaterialRippleButton {
                                id: fileItem

                                required property int index
                                required property string fileName
                                required property string filePath
                                required property bool fileIsDir

                                property bool appeared: false
                                readonly property bool selected: root.selectedPath === filePath
                                readonly property real initialX: ((index * 37) % 3 - 1) * 24
                                readonly property real initialY: ((index * 53) % 5 - 2) * 10

                                width: fileGrid.cellWidth - 8
                                height: fileGrid.cellHeight - 8
                                padding: 0
                                opacity: appeared ? 1 : 0
                                scale: appeared ? 1 : 0.76
                                rotation: appeared ? 0 : ((index % 3) - 1) * 3
                                toggled: selected
                                buttonRadius: Appearance.rounding.large
                                buttonRadiusPressed: Appearance.rounding.normal
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer3Hover
                                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                                colRipple: Appearance.colors.colLayer3Active
                                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                                releaseAction: () => root.selectEntry(filePath, fileName, fileIsDir)
                                doubleClickAction: () => root.openEntry(filePath, fileIsDir)
                                transform: Translate {
                                    x: fileItem.appeared ? 0 : fileItem.initialX
                                    y: fileItem.appeared ? 0 : fileItem.initialY
                                }

                                Behavior on opacity { NumberAnimation { duration: 190 } }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Appearance.animation.expressiveDefaultSpatial.duration
                                        easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                        easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                                    }
                                }
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: Appearance.animation.expressiveDefaultSpatial.duration
                                        easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                        easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                                    }
                                }

                                Timer {
                                    interval: Math.min(260, fileItem.index * 18) + ((fileItem.index * 29) % 5) * 8
                                    running: true
                                    onTriggered: fileItem.appeared = true
                                }

                                contentItem: Item {
                                    Item {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 8
                                        height: 92

                                        Image {
                                            id: previewImage

                                            anchors.fill: parent
                                            source: fileItem.fileIsDir ? "" : root.encodeFileUrl(fileItem.filePath)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            visible: false
                                        }

                                        Rectangle {
                                            id: previewMask

                                            anchors.fill: parent
                                            radius: Appearance.rounding.normal
                                            color: "black"
                                            visible: false
                                            layer.enabled: true
                                        }

                                        MultiEffect {
                                            anchors.fill: parent
                                            source: previewImage
                                            maskEnabled: true
                                            maskSource: previewMask
                                            visible: !fileItem.fileIsDir && previewImage.status === Image.Ready
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Appearance.rounding.normal
                                            color: Appearance.colors.colSurfaceContainerHighest
                                            visible: fileItem.fileIsDir || previewImage.status !== Image.Ready

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: fileItem.fileIsDir ? "folder" : "image"
                                                iconSize: 38
                                                fill: fileItem.fileIsDir ? 1 : 0
                                                color: fileItem.fileIsDir
                                                    ? Appearance.colors.colPrimary
                                                    : Appearance.colors.colOnSurfaceVariant
                                            }
                                        }

                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 6
                                            width: 27
                                            height: 27
                                            radius: Appearance.rounding.full
                                            visible: fileItem.selected
                                            color: Appearance.colors.colPrimary

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "check"
                                                iconSize: 17
                                                color: Appearance.colors.colOnPrimary
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        anchors.bottomMargin: 9
                                        text: fileItem.fileName
                                        color: fileItem.selected
                                            ? Appearance.colors.colOnSecondaryContainer
                                            : Appearance.colors.colOnSurface
                                        font.family: Sizes.fontFamily
                                        font.pixelSize: 12
                                        font.weight: fileItem.selected ? Font.DemiBold : Font.Normal
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colSurfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colSurfaceContainerHighest

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 13
                                    anchors.rightMargin: 13
                                    spacing: 8

                                    MaterialSymbol {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        text: root.selectedIsDir ? "folder" : root.selectionValid ? "image" : "info"
                                        iconSize: 20
                                        color: root.selectionValid
                                            ? Appearance.colors.colPrimary
                                            : Appearance.colors.colOnSurfaceVariant
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.selectedPath === ""
                                            ? "选择一张图片"
                                            : root.selectedIsDir
                                              ? "双击进入 " + root.selectedName
                                              : root.selectedName
                                        color: Appearance.colors.colOnSurfaceVariant
                                        font.family: Sizes.fontFamily
                                        font.pixelSize: 13
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }

                            PickerActionButton {
                                label: "取消"
                                iconName: "close"
                                onClicked: root.dismiss()
                            }

                            PickerActionButton {
                                label: "选择"
                                iconName: "check"
                                primary: true
                                enabled: root.selectionValid
                                onClicked: root.acceptSelection()
                            }
                        }
                    }
                }
            }
        }
    }

    component PickerToolButton: MaterialRippleButton {
        id: toolButton

        property string iconName: ""
        property string tooltipText: ""
        property bool active: false

        implicitWidth: 40
        implicitHeight: 40
        padding: 0
        toggled: active
        buttonRadius: Appearance.rounding.full
        buttonRadiusPressed: Appearance.rounding.normal
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer3Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colLayer3Active
        colRippleToggled: Appearance.colors.colSecondaryContainerActive

        contentItem: MaterialSymbol {
            text: toolButton.iconName
            iconSize: 20
            fill: toolButton.active ? 1 : 0
            color: toolButton.active
                ? Appearance.colors.colOnSecondaryContainer
                : Appearance.colors.colOnSurface
        }

        StyledToolTip {
            extraVisibleCondition: toolButton.pointerHovered && toolButton.tooltipText !== ""
            text: toolButton.tooltipText
        }
    }

    component LocationButton: MaterialRippleButton {
        id: locationButton

        required property string label
        required property string iconName
        required property string path
        readonly property bool active: root.currentPath === path

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        padding: 0
        toggled: active
        buttonRadius: Appearance.rounding.full
        buttonRadiusPressed: Appearance.rounding.normal
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colLayer2Active
        colRippleToggled: Appearance.colors.colSecondaryContainerActive
        onClicked: root.navigateTo(locationButton.path)

        contentItem: RowLayout {
            spacing: 10

            Item { Layout.preferredWidth: 2 }

            MaterialSymbol {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                text: locationButton.iconName
                iconSize: 20
                fill: locationButton.active ? 1 : 0
                color: locationButton.active
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnSurfaceVariant
            }

            Text {
                Layout.fillWidth: true
                text: locationButton.label
                color: locationButton.active
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: 13
                font.weight: locationButton.active ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Item { Layout.preferredWidth: 4 }
        }
    }

    component PickerActionButton: MaterialRippleButton {
        id: actionButton

        required property string label
        property string iconName: ""
        property bool primary: false

        implicitWidth: Math.max(92, actionContent.implicitWidth + 30)
        implicitHeight: 44
        padding: 0
        buttonRadius: Appearance.rounding.full
        buttonRadiusPressed: Appearance.rounding.normal
        colBackground: primary ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest
        colBackgroundHover: primary ? Appearance.colors.colPrimaryHover : Appearance.colors.colSurfaceContainerHighestHover
        colRipple: primary ? Appearance.colors.colPrimaryActive : Appearance.colors.colSurfaceContainerHighestActive

        contentItem: RowLayout {
            id: actionContent

            spacing: 7

            MaterialSymbol {
                Layout.preferredWidth: actionButton.iconName === "" ? 0 : 19
                Layout.preferredHeight: 19
                visible: actionButton.iconName !== ""
                text: actionButton.iconName
                iconSize: 18
                color: actionButton.primary
                    ? Appearance.colors.colOnPrimary
                    : Appearance.colors.colOnSurface
            }

            Text {
                text: actionButton.label
                color: actionButton.primary
                    ? Appearance.colors.colOnPrimary
                    : Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }
    }
}
