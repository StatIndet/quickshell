import Qt.labs.folderlistmodel
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string startPath: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    property string currentPath: startPath
    readonly property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string documentsDir: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
    readonly property string musicDir: StandardPaths.writableLocation(StandardPaths.MusicLocation)
    readonly property string videosDir: StandardPaths.writableLocation(StandardPaths.MoviesLocation)
    readonly property string desktopDir: StandardPaths.writableLocation(StandardPaths.DesktopLocation)
    readonly property string picturesDir: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    readonly property string downloadsDir: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
    property bool showHiddenFiles: false
    property bool gridLayout: true

    signal fileSelected(string path)
    signal folderSelected(string path)

    function openAt(path) {
        currentPath = path && path !== "" ? path : picturesDir;
        open();
    }

    function encodeFileUrl(path) {
        if (!path)
            return "";
        return "file://" + path.split("/").map(s => encodeURIComponent(s)).join("/");
    }

    function navigateTo(path) {
        if (!path || path === "")
            return;
        currentPath = path;
    }

    function navigateUp() {
        if (currentPath === homeDir || currentPath === "/")
            return;
        const index = currentPath.lastIndexOf("/");
        currentPath = index <= 0 ? "/" : currentPath.substring(0, index);
    }

    function activateEntry(path, isDir) {
        if (isDir) {
            root.navigateTo(path);
            return;
        }

        root.fileSelected(path);
        root.close();
    }

    property bool shouldBeVisible: false
    readonly property int dialogPadding: 12
    readonly property int bodySpacing: 10
    readonly property int gridColumns: 5
    readonly property int gridCellWidth: 128
    readonly property real modalScreenWidth: modalWindow.screen ? modalWindow.screen.width : 1920
    readonly property real modalScreenHeight: modalWindow.screen ? modalWindow.screen.height : 1080
    readonly property real dialogWidth: Math.max(560, Math.min(860, modalScreenWidth - 24))
    readonly property real dialogHeight: Math.max(460, Math.min(640, modalScreenHeight - 64))
    readonly property real sidebarWidth: Math.max(56, dialogWidth - dialogPadding * 2 - bodySpacing - gridCellWidth * gridColumns)

    function open() {
        shouldBeVisible = true;
        Qt.callLater(() => modalContent.forceActiveFocus());
    }

    function close() {
        shouldBeVisible = false;
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
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif"]
        sortField: FolderListModel.Name
        sortReversed: false
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
        WlrLayershell.namespace: "clavis-wallpaper-file-browser"
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.dialogPadding
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "选择文件夹"
                        color: Appearance.colors.colOnSurface
                        font.family: Sizes.fontFamily
                        font.pixelSize: 19
                        font.weight: Font.Medium
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "选择图片，或使用当前文件夹作为壁纸目录"
                        color: Appearance.colors.colSubtext
                        font.family: Sizes.fontFamily
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    iconName: "close"
                    tooltipText: "关闭"
                    onClicked: root.close()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.bodySpacing

                ColumnLayout {
                    Layout.minimumWidth: root.sidebarWidth
                    Layout.preferredWidth: root.sidebarWidth
                    Layout.maximumWidth: root.sidebarWidth
                    Layout.fillHeight: true
                    spacing: 6

                    SidebarButton {
                        label: "Home"
                        iconName: "home"
                        active: root.currentPath === root.homeDir
                        onClicked: root.navigateTo(root.homeDir)
                    }
                    SidebarButton {
                        label: "Desktop"
                        iconName: "desktop_windows"
                        active: root.currentPath === root.desktopDir
                        visible: root.desktopDir !== ""
                        onClicked: root.navigateTo(root.desktopDir)
                    }
                    SidebarButton {
                        label: "Documents"
                        iconName: "description"
                        active: root.currentPath === root.documentsDir
                        visible: root.documentsDir !== ""
                        onClicked: root.navigateTo(root.documentsDir)
                    }
                    SidebarButton {
                        label: "Pictures"
                        iconName: "image"
                        active: root.currentPath === root.picturesDir
                        onClicked: root.navigateTo(root.picturesDir)
                    }
                    SidebarButton {
                        label: "Downloads"
                        iconName: "download"
                        active: root.currentPath === root.downloadsDir
                        onClicked: root.navigateTo(root.downloadsDir)
                    }
                    SidebarButton {
                        label: "Music"
                        iconName: "music_note"
                        active: root.currentPath === root.musicDir
                        visible: root.musicDir !== ""
                        onClicked: root.navigateTo(root.musicDir)
                    }
                    SidebarButton {
                        label: "Video"
                        iconName: "movie"
                        active: root.currentPath === root.videosDir
                        visible: root.videosDir !== ""
                        onClicked: root.navigateTo(root.videosDir)
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        IconButton {
                            iconName: "arrow_back"
                            tooltipText: "上一级"
                            enabled: root.currentPath !== root.homeDir && root.currentPath !== "/"
                            onClicked: root.navigateUp()
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Appearance.rounding.normal
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

                        IconButton {
                            iconName: root.showHiddenFiles ? "visibility_off" : "visibility"
                            tooltipText: root.showHiddenFiles ? "隐藏隐藏文件" : "显示隐藏文件"
                            active: root.showHiddenFiles
                            onClicked: root.showHiddenFiles = !root.showHiddenFiles
                        }

                        IconButton {
                            iconName: root.gridLayout ? "view_list" : "grid_view"
                            tooltipText: root.gridLayout ? "切换到列表布局" : "切换到网格布局"
                            onClicked: root.gridLayout = !root.gridLayout
                        }

                        ActionButton {
                            text: "使用当前文件夹"
                            iconName: "check"
                            onClicked: {
                                root.folderSelected(root.currentPath);
                                root.close();
                            }
                        }
                    }

                    Item {
                        id: fileViews

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        StyledGridView {
                            id: fileGrid

                            anchors.fill: parent
                            visible: root.gridLayout
                            clip: true
                            cellWidth: root.gridCellWidth
                            cellHeight: 146
                            model: folderModel

                            delegate: Item {
                            id: fileItem

                            required property string fileName
                            required property string filePath
                            required property bool fileIsDir

                            width: fileGrid.cellWidth - 10
                            height: fileGrid.cellHeight - 10

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.normal
                                color: itemMouse.containsMouse ? Appearance.colors.colLayer3 : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            Item {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                height: 86

                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    source: !fileItem.fileIsDir ? root.encodeFileUrl(fileItem.filePath) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    smooth: true
                                    visible: false
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
                                    id: previewMask
                                    anchors.fill: parent
                                    radius: Appearance.rounding.small
                                    color: "black"
                                    visible: false
                                    layer.enabled: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colLayer2
                                    visible: fileItem.fileIsDir || previewImage.status !== Image.Ready

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: fileItem.fileIsDir ? "folder" : "image"
                                        iconSize: 34
                                        color: fileItem.fileIsDir ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                                        fill: fileItem.fileIsDir ? 1 : 0
                                    }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottomMargin: 10
                                text: fileItem.fileName
                                color: Appearance.colors.colOnSurface
                                font.family: Sizes.fontFamily
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideMiddle
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateEntry(fileItem.filePath, fileItem.fileIsDir)
                            }
                        }
                        }

                        StyledListView {
                            id: fileList

                            anchors.fill: parent
                            visible: !root.gridLayout
                            clip: true
                            spacing: 4
                            model: folderModel

                            delegate: Item {
                                id: listItem

                                required property string fileName
                                required property string filePath
                                required property bool fileIsDir

                                width: fileList.width
                                height: 58

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Appearance.rounding.normal
                                    color: listMouse.containsMouse ? Appearance.colors.colLayer3 : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 10
                                    anchors.topMargin: 6
                                    anchors.bottomMargin: 6
                                    spacing: 10

                                    Item {
                                        Layout.preferredWidth: 46
                                        Layout.preferredHeight: 46

                                        Image {
                                            id: listPreviewImage
                                            anchors.fill: parent
                                            source: !listItem.fileIsDir ? root.encodeFileUrl(listItem.filePath) : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            smooth: true
                                            visible: false
                                        }

                                        MultiEffect {
                                            anchors.fill: parent
                                            source: listPreviewImage
                                            maskEnabled: true
                                            maskSource: listPreviewMask
                                            visible: !listItem.fileIsDir && listPreviewImage.status === Image.Ready
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1
                                        }

                                        Rectangle {
                                            id: listPreviewMask
                                            anchors.fill: parent
                                            radius: Appearance.rounding.small
                                            color: "black"
                                            visible: false
                                            layer.enabled: true
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Appearance.rounding.small
                                            color: Appearance.colors.colLayer2
                                            visible: listItem.fileIsDir || listPreviewImage.status !== Image.Ready

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: listItem.fileIsDir ? "folder" : "image"
                                                iconSize: 26
                                                color: listItem.fileIsDir ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                                                fill: listItem.fileIsDir ? 1 : 0
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: listItem.fileName
                                            color: Appearance.colors.colOnSurface
                                            font.family: Sizes.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            elide: Text.ElideMiddle
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: listItem.fileIsDir ? "文件夹" : listItem.filePath
                                            color: Appearance.colors.colSubtext
                                            font.family: listItem.fileIsDir ? Sizes.fontFamily : Sizes.fontFamilyMono
                                            font.pixelSize: 11
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    MaterialSymbol {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        text: listItem.fileIsDir ? "chevron_right" : "wallpaper"
                                        iconSize: 20
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }

                                MouseArea {
                                    id: listMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activateEntry(listItem.filePath, listItem.fileIsDir)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }

    component IconButton: Item {
        id: iconButton

        property string iconName: ""
        property string tooltipText: ""
        property bool active: false
        signal clicked

        implicitWidth: 36
        implicitHeight: 36
        opacity: enabled ? 1 : 0.35

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: iconButton.active
                   ? (iconMouse.containsMouse ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer)
                   : (iconMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2)
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: iconButton.iconName
            iconSize: 20
            fill: iconButton.active ? 1 : 0
            color: iconButton.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            enabled: iconButton.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
        }

        StyledToolTip {
            extraVisibleCondition: iconMouse.containsMouse && iconButton.tooltipText !== ""
            text: iconButton.tooltipText
        }
    }

    component ActionButton: Item {
        id: actionButton

        property string text: ""
        property string iconName: ""

        signal clicked

        implicitWidth: Math.max(128, actionLabel.implicitWidth + (iconName !== "" ? 48 : 28))
        implicitHeight: 36
        opacity: enabled ? 1 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: actionMouse.pressed ? Appearance.colors.colPrimaryActive : actionMouse.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: actionButton.iconName
                iconSize: 18
                fill: 1
                color: Appearance.colors.colOnPrimary
                visible: actionButton.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: actionLabel
                text: actionButton.text
                color: Appearance.colors.colOnPrimary
                font.family: Sizes.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            enabled: actionButton.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }

    component SidebarButton: Item {
        id: sidebarButton

        property string label: ""
        property string iconName: ""
        property bool active: false
        readonly property bool compact: width < 80
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 38

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: sidebarButton.active ? Appearance.colors.colSecondaryContainer : (sideMouse.containsMouse ? Appearance.colors.colLayer3 : "transparent")
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: sidebarButton.compact ? 0 : 12
            anchors.rightMargin: sidebarButton.compact ? 0 : 12
            spacing: sidebarButton.compact ? 0 : 8

            MaterialSymbol {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: sidebarButton.compact ? Qt.AlignCenter : Qt.AlignVCenter
                text: sidebarButton.iconName
                iconSize: 20
                fill: sidebarButton.active ? 1 : 0
                color: sidebarButton.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
            }

            Text {
                Layout.fillWidth: true
                visible: !sidebarButton.compact
                text: sidebarButton.label
                color: sidebarButton.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                font.family: Sizes.fontFamily
                font.pixelSize: 13
                font.weight: sidebarButton.active ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: sideMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sidebarButton.clicked()
        }

        StyledToolTip {
            extraVisibleCondition: sidebarButton.compact && sideMouse.containsMouse
            text: sidebarButton.label
        }
    }
}
