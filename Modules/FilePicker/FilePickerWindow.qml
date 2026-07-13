import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property var targetScreen: null
    property string title: "选择图片"
    property string description: "选择一张图片作为用户头像"
    property string startPath: picturesDir
    property var nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif"]
    property string currentPath: startPath
    property string selectedPath: ""
    property string selectedName: ""
    property bool selectedIsDir: false
    property bool showHiddenFiles: false
    property bool shouldBeVisible: false

    readonly property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string desktopDir: StandardPaths.writableLocation(StandardPaths.DesktopLocation)
    readonly property string documentsDir: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
    readonly property string picturesDir: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    readonly property string downloadsDir: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
    readonly property real screenWidth: pickerWindow.screen ? pickerWindow.screen.width : 1920
    readonly property real screenHeight: pickerWindow.screen ? pickerWindow.screen.height : 1080
    readonly property real dialogWidth: Math.min(920, screenWidth - 32)
    readonly property real dialogHeight: Math.min(600, screenHeight - 64)
    readonly property bool selectionValid: selectedPath !== "" && !selectedIsDir

    signal accepted(string path)
    signal rejected()

    function encodeFileUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split("/").map(segment => encodeURIComponent(segment)).join("/");
    }

    function openAt(path) {
        currentPath = path && path !== "" ? path : picturesDir;
        clearSelection();
        shouldBeVisible = true;
        Qt.callLater(() => dialogFocus.forceActiveFocus());
    }

    function dismiss() {
        shouldBeVisible = false;
        clearSelection();
        rejected();
    }

    function acceptSelection() {
        if (!selectionValid)
            return;
        const path = selectedPath;
        shouldBeVisible = false;
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

    PanelWindow {
        id: pickerWindow

        screen: root.targetScreen
        visible: root.shouldBeVisible
        color: "transparent"
        exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clavis-image-file-picker"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: Appearance.applyAlpha(Appearance.m3colors.m3scrim, 0.58)

            MouseArea {
                anchors.fill: parent
                enabled: root.shouldBeVisible
                onClicked: root.dismiss()
            }
        }

        FocusScope {
            id: dialogFocus

            property real revealProgress: root.shouldBeVisible ? 1 : 0

            anchors.centerIn: parent
            width: root.dialogWidth
            height: root.dialogHeight
            focus: root.shouldBeVisible
            opacity: revealProgress
            scale: 0.94 + revealProgress * 0.06

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
                radius: 8
                color: Appearance.m3colors.m3surfaceContainerLow
                border.width: 1
                border.color: Appearance.m3colors.m3outlineVariant
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
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22
                        anchors.rightMargin: 16
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 8
                            color: Appearance.colors.colPrimaryContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "add_photo_alternate"
                                iconSize: 24
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
                                font.pixelSize: 20
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
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Appearance.colors.colOutlineVariant
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Rectangle {
                        Layout.preferredWidth: 172
                        Layout.fillHeight: true
                        color: Appearance.colors.colLayer1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.topMargin: 14
                            anchors.bottomMargin: 14
                            spacing: 4

                            Text {
                                Layout.leftMargin: 10
                                Layout.bottomMargin: 5
                                text: "位置"
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Sizes.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            LocationButton { label: "Home"; iconName: "home"; path: root.homeDir }
                            LocationButton { label: "Desktop"; iconName: "desktop_windows"; path: root.desktopDir; visible: path !== "" }
                            LocationButton { label: "Documents"; iconName: "description"; path: root.documentsDir; visible: path !== "" }
                            LocationButton { label: "Pictures"; iconName: "image"; path: root.picturesDir; visible: path !== "" }
                            LocationButton { label: "Downloads"; iconName: "download"; path: root.downloadsDir; visible: path !== "" }

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 10
                                Layout.rightMargin: 10
                                text: "支持 JPG、PNG、WebP、BMP、GIF"
                                color: Appearance.colors.colSubtext
                                font.family: Sizes.fontFamily
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 8

                                PickerToolButton {
                                    iconName: "arrow_upward"
                                    tooltipText: "上一级"
                                    enabled: root.currentPath !== "/"
                                    onClicked: root.navigateUp()
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    radius: 8
                                    color: Appearance.colors.colLayer2
                                    border.width: 1
                                    border.color: Appearance.colors.colOutlineVariant

                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
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
                            Layout.preferredHeight: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
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

                                delegate: Item {
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
                                    opacity: appeared ? 1 : 0
                                    scale: appeared ? 1 : 0.76
                                    rotation: appeared ? 0 : ((index % 3) - 1) * 3
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

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: fileItem.selected
                                            ? Appearance.colors.colSecondaryContainer
                                            : fileMouse.pressed
                                              ? Appearance.colors.colLayer3Active
                                              : fileMouse.containsMouse
                                                ? Appearance.colors.colLayer3Hover
                                                : "transparent"
                                        border.width: fileItem.selected ? 1 : 0
                                        border.color: Appearance.colors.colPrimary

                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }

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
                                            radius: 8
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
                                            radius: 8
                                            color: Appearance.colors.colLayer2
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
                                            width: 25
                                            height: 25
                                            radius: 13
                                            visible: fileItem.selected
                                            color: Appearance.colors.colPrimary

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "check"
                                                iconSize: 16
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

                                    MouseArea {
                                        id: fileMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectEntry(fileItem.filePath, fileItem.fileName, fileItem.fileIsDir)
                                        onDoubleClicked: root.openEntry(fileItem.filePath, fileItem.fileIsDir)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Appearance.colors.colOutlineVariant
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 10

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

                                Button {
                                    text: "取消"
                                    flat: true
                                    font.family: Sizes.fontFamily
                                    onClicked: root.dismiss()
                                }

                                Button {
                                    id: acceptButton

                                    text: "选择"
                                    enabled: root.selectionValid
                                    highlighted: true
                                    font.family: Sizes.fontFamily
                                    Material.background: Appearance.colors.colPrimary
                                    Material.foreground: Appearance.colors.colOnPrimary
                                    onClicked: root.acceptSelection()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component PickerToolButton: ToolButton {
        id: toolButton

        property string iconName: ""
        property string tooltipText: ""
        property bool active: false

        implicitWidth: 36
        implicitHeight: 36
        padding: 0
        opacity: enabled ? 1 : 0.35
        background: Rectangle {
            radius: 8
            color: toolButton.active
                ? Appearance.colors.colSecondaryContainer
                : toolButton.down
                  ? Appearance.colors.colLayer3Active
                  : toolButton.hovered
                    ? Appearance.colors.colLayer3Hover
                    : "transparent"
        }
        contentItem: MaterialSymbol {
            text: toolButton.iconName
            iconSize: 20
            fill: toolButton.active ? 1 : 0
            color: toolButton.active
                ? Appearance.colors.colOnSecondaryContainer
                : Appearance.colors.colOnSurface
        }
        StyledToolTip {
            extraVisibleCondition: toolButton.hovered && toolButton.tooltipText !== ""
            text: toolButton.tooltipText
        }
    }

    component LocationButton: Item {
        id: locationButton

        required property string label
        required property string iconName
        required property string path
        readonly property bool active: root.currentPath === path

        Layout.fillWidth: true
        Layout.preferredHeight: 42

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: locationButton.active
                ? Appearance.colors.colSecondaryContainer
                : locationMouse.pressed
                  ? Appearance.colors.colLayer2Active
                  : locationMouse.containsMouse
                    ? Appearance.colors.colLayer2Hover
                    : "transparent"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

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
        }

        MouseArea {
            id: locationMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.navigateTo(locationButton.path)
        }
    }
}
