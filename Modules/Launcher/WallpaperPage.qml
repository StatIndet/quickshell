import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    signal requestCloseLauncher()

    property string query: ""
    property string wallpaperPath: PersonalizationConfig.wallpaperFolder

    property string currentSelectedPreview: ""
    property bool isLoading: true

    RofiStyle {
        id: rofiStyle
    }

    ListModel { id: wallpaperModel }
    ListModel { id: filteredWallpaperModel }

    function decrementCurrentIndex() { setCurrentIndex(wallpaperList.currentIndex - 1) }
    function incrementCurrentIndex() { setCurrentIndex(wallpaperList.currentIndex + 1) }

    function setCurrentIndex(index) {
        if (filteredWallpaperModel.count === 0) {
            wallpaperList.currentIndex = -1
            wallpaperList.contentY = 0
            root.currentSelectedPreview = ""
            return
        }

        wallpaperList.currentIndex = Math.max(0, Math.min(index, filteredWallpaperModel.count - 1))
        ensureCurrentVisible()
        updateSelectedPreview()
    }

    function ensureCurrentVisible() {
        if (wallpaperList.currentIndex < 0)
            return

        let firstVisibleIndex = Math.round(wallpaperList.contentY / rofiStyle.listStep)
        if (wallpaperList.currentIndex < firstVisibleIndex)
            firstVisibleIndex = wallpaperList.currentIndex
        else if (wallpaperList.currentIndex >= firstVisibleIndex + rofiStyle.listRows)
            firstVisibleIndex = wallpaperList.currentIndex - rofiStyle.listRows + 1

        const maxFirstIndex = Math.max(0, filteredWallpaperModel.count - rofiStyle.listRows)
        firstVisibleIndex = Math.max(0, Math.min(firstVisibleIndex, maxFirstIndex))
        wallpaperList.contentY = firstVisibleIndex * rofiStyle.listStep
    }

    function wallpaperMatches(path, fileName, text) {
        const needle = text.trim().toLowerCase()
        if (needle === "")
            return true

        return fileName.toLowerCase().indexOf(needle) !== -1 || path.toLowerCase().indexOf(needle) !== -1
    }

    function updateSelectedPreview() {
        if (wallpaperList.currentIndex >= 0 && wallpaperList.currentIndex < filteredWallpaperModel.count)
            root.currentSelectedPreview = "file://" + filteredWallpaperModel.get(wallpaperList.currentIndex).path
        else
            root.currentSelectedPreview = ""
    }

    function filterWallpapers(text) {
        let previousPath = ""
        if (wallpaperList.currentIndex >= 0 && wallpaperList.currentIndex < filteredWallpaperModel.count)
            previousPath = filteredWallpaperModel.get(wallpaperList.currentIndex).path

        filteredWallpaperModel.clear()

        let nextIndex = -1
        for (let i = 0; i < wallpaperModel.count; i++) {
            const item = wallpaperModel.get(i)
            if (!wallpaperMatches(item.path, item.fileName, text))
                continue

            if (item.path === previousPath)
                nextIndex = filteredWallpaperModel.count
            filteredWallpaperModel.append({ path: item.path, fileName: item.fileName })
        }

        if (filteredWallpaperModel.count === 0) {
            setCurrentIndex(-1)
            return
        }

        wallpaperList.contentY = 0
        setCurrentIndex(nextIndex >= 0 ? nextIndex : 0)
    }

    Process {
        id: scanWallpapers
        command: ["bash", "-c", "find " + root.wallpaperPath + " -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (file) => {
                if (file.trim() !== "") {
                    let name = file.substring(file.lastIndexOf("/") + 1)
                    wallpaperModel.append({ path: file.trim(), fileName: name })
                }
            }
        }
        onExited: {
            root.isLoading = false
            root.filterWallpapers(root.query)

            let currentPath = Appearance.currentWallpaperPreview.replace("file://", "")
            if (currentPath !== "") {
                for (let i = 0; i < filteredWallpaperModel.count; i++) {
                    if (filteredWallpaperModel.get(i).path === currentPath) {
                        root.setCurrentIndex(i)
                        break
                    }
                }
            }
        }
    }

    onQueryChanged: filterWallpapers(query)

    onVisibleChanged: {
        if (visible) {
            wallpaperModel.clear()
            filteredWallpaperModel.clear()
            root.currentSelectedPreview = ""
            root.isLoading = true
            scanWallpapers.running = true
        }
    }

    Text {
        anchors.centerIn: parent
        text: "Scanning wallpapers..."
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Sizes.fontFamilyMono
        font.pixelSize: rofiStyle.fontPixelSize
        visible: root.isLoading
    }

    Text {
        anchors.centerIn: parent
        text: "No wallpapers found."
        color: Appearance.colors.colOnSurfaceVariant
        font.family: Sizes.fontFamilyMono
        font.pixelSize: rofiStyle.fontPixelSize
        visible: !root.isLoading && filteredWallpaperModel.count === 0
    }

    StyledListView {
        id: wallpaperList
        width: parent.width
        height: rofiStyle.listHeight
        anchors.top: parent.top
        clip: true
        spacing: rofiStyle.listSpacing
        animateAppearance: false
        animateMovement: false
        showVerticalScrollBar: false
        smoothWheelEnabled: false
        visible: !root.isLoading && filteredWallpaperModel.count > 0
        model: filteredWallpaperModel

        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        highlightFollowsCurrentItem: true
        highlightRangeMode: ListView.NoHighlightRange

        highlight: Rectangle {
            width: wallpaperList.width
            height: rofiStyle.rowHeight
            color: Appearance.colors.colPrimary
            radius: rofiStyle.controlRadius
        }
        highlightMoveDuration: 0

        onCurrentIndexChanged: root.updateSelectedPreview()

        delegate: Item {
            id: delegateItem
            width: ListView.view.width
            height: rofiStyle.rowHeight

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.setCurrentIndex(index)
                    applyWallpaper()
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: rofiStyle.itemPadding
                spacing: rofiStyle.itemSpacing

                Image {
                    Layout.preferredWidth: rofiStyle.wallpaperThumbWidth
                    Layout.preferredHeight: rofiStyle.wallpaperThumbHeight
                    Layout.alignment: Qt.AlignVCenter
                    source: "file://" + model.path
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: rofiStyle.wallpaperThumbWidth * 2
                    sourceSize.height: rofiStyle.wallpaperThumbHeight * 2
                    asynchronous: true
                    cache: true
                    smooth: true
                    clip: true
                }

                Text {
                    text: model.fileName
                    color: delegateItem.ListView.isCurrentItem ? Appearance.colors.colOnSecondary : Appearance.colors.colOnSurface
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: rofiStyle.fontPixelSize
                    font.bold: false
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    function wallpaperProcessesRunning() {
        return WallpaperService.busy;
    }

    function applyWallpaper() {
        if (filteredWallpaperModel.count === 0 || wallpaperList.currentIndex < 0) return

        if (wallpaperProcessesRunning()) {
            console.log("Wallpaper switch in progress, ignoring extra triggers...")
            return
        }

        let currentPath = filteredWallpaperModel.get(wallpaperList.currentIndex).path

        WallpaperService.setWallpaper(currentPath)
    }
}
