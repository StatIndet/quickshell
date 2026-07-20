import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components
import qs.Services
import "../../../Common/functions/SearchUtils.js" as SearchUtils

Item {
    id: root

    signal wallpaperChanged()

    property var screen: null
    property string query: ""
    property string selectedPath: ""

    readonly property string screenName: screen && screen.name ? screen.name : ""
    readonly property string appliedPath: WallpaperService.wallpaperForScreen(screenName)

    function relativePath(path) {
        const value = String(path || "");
        const folder = String(PersonalizationConfig.wallpaperFolder || "").replace(/\/+$/, "");
        if (folder.length > 0 && value.indexOf(folder + "/") === 0)
            return value.slice(folder.length + 1);
        return WallpaperService.basename(value);
    }

    function modelIndexForPath(path) {
        for (let index = 0; index < wallpaperModel.count; ++index) {
            if (wallpaperModel.get(index).path === path)
                return index;
        }
        return -1;
    }

    function syncSelectedPath() {
        if (view.currentIndex < 0 || view.currentIndex >= wallpaperModel.count) {
            root.selectedPath = "";
            return;
        }
        root.selectedPath = wallpaperModel.get(view.currentIndex).path;
    }

    function selectIndex(index) {
        if (wallpaperModel.count === 0) {
            view.currentIndex = -1;
            root.selectedPath = "";
            return;
        }

        const wrapped = ((index % wallpaperModel.count) + wallpaperModel.count) % wallpaperModel.count;
        view.currentIndex = wrapped;
        root.syncSelectedPath();
    }

    function rebuildFilteredModel(forceFirst) {
        const previousPath = root.selectedPath;
        const ranked = SearchUtils.ranked(
            WallpaperService.wallpapers,
            root.query,
            path => root.relativePath(path)
        );

        wallpaperModel.clear();
        for (let index = 0; index < ranked.length; ++index) {
            const path = ranked[index];
            wallpaperModel.append({
                path: path,
                relativePath: root.relativePath(path)
            });
        }

        if (wallpaperModel.count === 0) {
            view.currentIndex = -1;
            root.selectedPath = "";
            return;
        }

        let targetIndex = -1;
        if (!forceFirst && root.query.trim().length === 0)
            targetIndex = root.modelIndexForPath(root.appliedPath);
        if (targetIndex < 0 && !forceFirst)
            targetIndex = root.modelIndexForPath(previousPath);
        root.selectIndex(targetIndex >= 0 ? targetIndex : 0);
    }

    function applyWallpaper() {
        if (root.selectedPath.length === 0 || WallpaperService.busy)
            return;

        if (WallpaperService.setWallpaper(root.selectedPath, root.screenName))
            root.wallpaperChanged();
    }

    ListModel {
        id: wallpaperModel
    }

    Component.onCompleted: {
        if (WallpaperService.wallpapers.length === 0 && !WallpaperService.scanning)
            WallpaperService.scan();
        root.rebuildFilteredModel(false);
    }

    onVisibleChanged: {
        if (!visible)
            return;

        searchInput.clear();
        root.query = "";
        if (WallpaperService.wallpapers.length === 0 && !WallpaperService.scanning)
            WallpaperService.scan();
        root.rebuildFilteredModel(false);
        searchInput.forceActiveFocus();
    }

    onScreenChanged: {
        if (root.query.trim().length === 0)
            root.rebuildFilteredModel(false);
    }

    Connections {
        target: WallpaperService

        function onWallpapersChanged() {
            if (!WallpaperService.scanning)
                root.rebuildFilteredModel(root.query.trim().length > 0);
        }

        function onScanningChanged() {
            if (!WallpaperService.scanning)
                root.rebuildFilteredModel(root.query.trim().length > 0);
        }

        function onRevisionChanged() {
            if (root.visible && root.query.trim().length === 0)
                root.rebuildFilteredModel(false);
        }
    }

    PathView {
        id: view

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: searchContainer.top
        anchors.bottomMargin: WallpaperPickerTokens.carouselBottomGap

        model: wallpaperModel
        pathItemCount: WallpaperPickerTokens.visibleItemCount
        cacheItemCount: WallpaperPickerTokens.cachedItemCount
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        snapMode: PathView.SnapToItem
        dragMargin: height

        onCurrentIndexChanged: root.syncSelectedPath()

        Keys.onLeftPressed: root.selectIndex(currentIndex - 1)
        Keys.onRightPressed: root.selectIndex(currentIndex + 1)
        Keys.onReturnPressed: root.applyWallpaper()
        Keys.onEnterPressed: root.applyWallpaper()

        path: Path {
            startY: view.height / 2

            PathAttribute {
                name: "itemZ"
                value: 0
            }

            PathLine {
                x: view.width / 2
                relativeY: 0
            }

            PathAttribute {
                name: "itemZ"
                value: 1
            }

            PathLine {
                x: view.width
                relativeY: 0
            }
        }

        delegate: Item {
            id: delegateRoot

            required property int index
            required property string path
            required property string relativePath

            width: WallpaperPickerTokens.delegateWidth
            height: WallpaperPickerTokens.delegateHeight
            scale: WallpaperPickerTokens.initialScale
            opacity: 0
            z: PathView.isCurrentItem ? 2 : (PathView.onPath ? 1 : 0)

            Component.onCompleted: {
                scale = Qt.binding(() => PathView.isCurrentItem
                    ? WallpaperPickerTokens.selectedScale
                    : PathView.onPath
                        ? WallpaperPickerTokens.sideScale
                        : WallpaperPickerTokens.hiddenScale);
                opacity = Qt.binding(() => PathView.onPath ? 1 : 0);
            }

            Behavior on scale {
                NumberAnimation {
                    duration: WallpaperPickerTokens.spatialMotion.duration
                    easing.type: WallpaperPickerTokens.spatialMotion.type
                    easing.bezierCurve: WallpaperPickerTokens.spatialMotion.bezierCurve
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: WallpaperPickerTokens.effectsMotion.duration
                    easing.type: WallpaperPickerTokens.effectsMotion.type
                    easing.bezierCurve: WallpaperPickerTokens.effectsMotion.bezierCurve
                }
            }

            Rectangle {
                id: selectedElevation

                anchors.fill: previewFrame
                radius: WallpaperPickerTokens.previewRadius
                color: Appearance.colors.colLayer1
                opacity: PathView.isCurrentItem ? 1 : 0

                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    radius: 18
                    samples: 37
                    color: Appearance.applyAlpha(Appearance.colors.colShadow, 0.78)
                    verticalOffset: 6
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: WallpaperPickerTokens.effectsMotion.duration
                        easing.type: WallpaperPickerTokens.effectsMotion.type
                        easing.bezierCurve: WallpaperPickerTokens.effectsMotion.bezierCurve
                    }
                }
            }

            Item {
                id: previewFrame

                anchors.horizontalCenter: parent.horizontalCenter
                y: WallpaperPickerTokens.previewTopPadding
                width: WallpaperPickerTokens.previewWidth
                height: width / WallpaperPickerTokens.previewAspectRatio

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: previewFrame.width
                        height: previewFrame.height
                        radius: WallpaperPickerTokens.previewRadius
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.colors.colSurfaceContainer
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "image"
                    iconSize: 36
                    fill: 1
                    color: Appearance.colors.colOutline
                }

                Image {
                    id: previewImage

                    anchors.fill: parent
                    source: Paths.fileUrl(delegateRoot.path)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: !view.moving
                    sourceSize.width: WallpaperPickerTokens.previewWidth * 2
                    sourceSize.height: WallpaperPickerTokens.previewWidth * 2
                        / WallpaperPickerTokens.previewAspectRatio
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    color: previewTap.pressed
                        ? Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.14)
                        : previewHover.hovered
                            ? Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.08)
                            : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: WallpaperPickerTokens.effectsMotion.duration
                            easing.type: WallpaperPickerTokens.effectsMotion.type
                            easing.bezierCurve: WallpaperPickerTokens.effectsMotion.bezierCurve
                        }
                    }
                }

                HoverHandler {
                    id: previewHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: previewTap
                    onTapped: root.selectIndex(delegateRoot.index)
                }
            }

            Text {
                anchors.top: previewFrame.bottom
                anchors.topMargin: WallpaperPickerTokens.labelGap
                anchors.horizontalCenter: parent.horizontalCenter
                width: previewFrame.width - WallpaperPickerTokens.labelWidthInset

                text: delegateRoot.relativePath
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: WallpaperPickerTokens.labelFontSize
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
            }
        }
    }

    Item {
        id: emptyState

        anchors.centerIn: view
        width: emptyRow.implicitWidth
        height: emptyRow.implicitHeight
        opacity: wallpaperModel.count === 0 ? 1 : 0
        scale: wallpaperModel.count === 0 ? 1 : WallpaperPickerTokens.initialScale
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: WallpaperPickerTokens.effectsMotion.duration
                easing.type: WallpaperPickerTokens.effectsMotion.type
                easing.bezierCurve: WallpaperPickerTokens.effectsMotion.bezierCurve
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: WallpaperPickerTokens.spatialMotion.duration
                easing.type: WallpaperPickerTokens.spatialMotion.type
                easing.bezierCurve: WallpaperPickerTokens.spatialMotion.bezierCurve
            }
        }

        Row {
            id: emptyRow

            spacing: 12

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: WallpaperService.scanning ? "progress_activity" : "wallpaper_slideshow"
                iconSize: WallpaperPickerTokens.emptyIconSize
                fill: 1
                color: Appearance.colors.colOnSurfaceVariant
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: WallpaperService.scanning
                        ? "正在扫描壁纸"
                        : root.query.trim().length > 0
                            ? "未找到匹配壁纸"
                            : "未找到壁纸"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.Medium
                }

                Text {
                    text: WallpaperService.scanning
                        ? PersonalizationConfig.wallpaperFolder
                        : root.query.trim().length > 0
                            ? "请尝试其他搜索内容"
                            : "请将图片放入 " + PersonalizationConfig.wallpaperFolder
                    color: Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.72)
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideMiddle
                    width: Math.min(520, implicitWidth)
                }
            }
        }
    }

    Item {
        id: searchContainer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: WallpaperPickerTokens.searchHorizontalMargin
        anchors.rightMargin: WallpaperPickerTokens.searchHorizontalMargin
        anchors.bottomMargin: WallpaperPickerTokens.searchBottomMargin
        height: WallpaperPickerTokens.searchHeight

        TextField {
            id: searchInput

            anchors.fill: parent
            leftPadding: WallpaperPickerTokens.searchTextInset
            rightPadding: WallpaperPickerTokens.searchTextInset
            color: Appearance.colors.colOnSurface
            selectionColor: Appearance.colors.colSecondaryContainer
            selectedTextColor: Appearance.colors.colOnSecondaryContainer
            font.family: Sizes.fontFamily
            font.pixelSize: WallpaperPickerTokens.searchFontSize
            renderType: Text.QtRendering
            selectByMouse: true

            background: Rectangle {
                radius: height / 2
                color: Appearance.colors.colSurfaceContainer
            }

            onTextChanged: {
                root.query = text;
                root.rebuildFilteredModel(true);
            }

            Keys.onReturnPressed: event => {
                root.applyWallpaper();
                event.accepted = true;
            }
            Keys.onEnterPressed: event => {
                root.applyWallpaper();
                event.accepted = true;
            }
            Keys.onUpPressed: event => {
                root.selectIndex(view.currentIndex - 1);
                event.accepted = true;
            }
            Keys.onDownPressed: event => {
                root.selectIndex(view.currentIndex + 1);
                event.accepted = true;
            }
            Keys.onLeftPressed: event => {
                if (text.length === 0 || cursorPosition === 0) {
                    root.selectIndex(view.currentIndex - 1);
                    event.accepted = true;
                }
            }
            Keys.onRightPressed: event => {
                if (text.length === 0 || cursorPosition === text.length) {
                    root.selectIndex(view.currentIndex + 1);
                    event.accepted = true;
                }
            }
        }

        MaterialSymbol {
            anchors.left: parent.left
            anchors.leftMargin: WallpaperPickerTokens.searchIconInset
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            iconSize: WallpaperPickerTokens.searchIconSize
            color: Appearance.colors.colOnSurfaceVariant
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: WallpaperPickerTokens.searchTextInset
            anchors.right: clearButton.left
            anchors.verticalCenter: parent.verticalCenter

            text: "搜索壁纸"
            color: Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.72)
            font.family: Sizes.fontFamily
            font.pixelSize: WallpaperPickerTokens.searchFontSize
            opacity: searchInput.text.length === 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: WallpaperPickerTokens.effectsMotion.duration
                    easing.type: WallpaperPickerTokens.effectsMotion.type
                    easing.bezierCurve: WallpaperPickerTokens.effectsMotion.bezierCurve
                }
            }
        }

        ToolButton {
            id: clearButton

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: WallpaperPickerTokens.clearButtonSize
            height: WallpaperPickerTokens.clearButtonSize
            enabled: searchInput.text.length > 0
            opacity: enabled ? 1 : 0
            hoverEnabled: true
            onClicked: {
                searchInput.clear();
                searchInput.forceActiveFocus();
            }

            background: Rectangle {
                radius: width / 2
                color: clearButton.down
                    ? Appearance.colors.colLayer2Active
                    : clearButton.hovered
                        ? Appearance.colors.colLayer2Hover
                        : "transparent"
            }

            contentItem: MaterialSymbol {
                text: "clear"
                iconSize: 20
                color: Appearance.colors.colOnSurfaceVariant
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: WallpaperPickerTokens.effectsMotion.duration
                    easing.type: WallpaperPickerTokens.effectsMotion.type
                    easing.bezierCurve: WallpaperPickerTokens.effectsMotion.bezierCurve
                }
            }
        }
    }
}
