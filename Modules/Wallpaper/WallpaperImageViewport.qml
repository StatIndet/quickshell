import QtQuick
import qs.Common
import "../../Common/functions/WallpaperSource.js" as WallpaperSource
import "../../Common/functions/WallpaperMath.js" as WallpaperMath

Item {
    id: root

    property string sourcePath: ""
    property int imageFillMode: Image.PreserveAspectCrop
    property bool panoramaEnabled: false
    // DesktopWallpaper supplies the per-output WallpaperScene transform.
    // Overview surfaces leave this null and retain their local transition
    // geometry.
    property var sharedTransform: null
    property real horizontalProgress: 0.5
    property int textureWidth: Math.min(Math.max(1, Math.round(width)), 8192)
    property int textureHeight: Math.min(Math.max(1, Math.round(height)), 8192)
    property string lastReadySourcePath: ""
    property real lastReadyImageWidth: 0
    property real lastReadyImageHeight: 0

    readonly property var paletteState: WallpaperSource.decode(sourcePath)
    readonly property bool sourceIsImage: WallpaperSource.isImage(sourcePath)
    readonly property bool sourceIsColor: root.isColorSource(root.sourcePath)
    readonly property bool ready: root.sourcePath === "" || !root.sourceIsImage || (image.status
                                                                                    === Image.Ready
                                                                                    && root.lastReadySourcePath
                                                                                    === root.sourcePath)
    readonly property int imageStatus: image.status
    readonly property real imagePixelWidth: Math.max(1, root.lastReadyImageWidth)
    readonly property real imagePixelHeight: Math.max(1, root.lastReadyImageHeight)
    readonly property var panoramaGeometry: WallpaperMath.panoramaGeometry(width, height, lastReadyImageWidth,
                                                                           lastReadyImageHeight,
                                                                           panoramaEnabled && sourceIsImage)
    readonly property real wallpaperX: root.sharedTransform && root.sharedTransform.panoramaSelected
                                       && panoramaGeometry.active ? root.sharedTransform.animatedOffsetX :
                                                                    panoramaGeometry.active
                                                                    ? WallpaperMath.wallpaperPosition(
                                                                          panoramaGeometry.overflowX,
                                                                          horizontalProgress) : 0

    signal loadFailed(string source)

    clip: true

    function imageUrl(path) {
        return path && path !== "" ? Paths.fileUrl(path) : "";
    }

    function isColorSource(path) {
        return WallpaperSource.isSolid(path);
    }

    function rememberReadyImageSize() {
        if (image.status !== Image.Ready)
            return;
        const sourceWidth = Number(image.sourceSize.width);
        const sourceHeight = Number(image.sourceSize.height);
        const imageWidth = sourceWidth > 0 ? sourceWidth : Number(image.implicitWidth);
        const imageHeight = sourceHeight > 0 ? sourceHeight : Number(image.implicitHeight);
        if (isFinite(imageWidth) && imageWidth > 0 && isFinite(imageHeight) && imageHeight > 0) {
            root.lastReadySourcePath = root.sourcePath;
            root.lastReadyImageWidth = imageWidth;
            root.lastReadyImageHeight = imageHeight;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.sourceIsColor ? root.sourcePath : "transparent"
        visible: root.sourceIsColor
    }

    Loader {
        anchors.fill: parent
        active: root.paletteState !== null
        sourceComponent: ZenPaletteRenderer {
            paletteState: root.paletteState
        }
    }

    Item {
        id: imageCanvas

        x: root.wallpaperX
        y: 0
        width: root.panoramaGeometry.canvasWidth
        height: root.panoramaGeometry.canvasHeight
        visible: root.sourceIsImage

        Image {
            id: image

            anchors.fill: parent
            source: root.sourceIsImage ? root.imageUrl(root.sourcePath) : ""
            fillMode: root.panoramaGeometry.active ? Image.PreserveAspectCrop : root.imageFillMode
            asynchronous: true
            cache: true
            retainWhileLoading: true
            smooth: true
            sourceSize: root.panoramaEnabled ? Qt.size(0, root.textureHeight) : Qt.size(root.textureWidth,
                                                                                        root.textureHeight)

            onStatusChanged: {
                if (status === Image.Ready) {
                    root.rememberReadyImageSize();
                } else if (status === Image.Error && root.sourcePath !== "") {
                    root.loadFailed(root.sourcePath);
                }
            }
        }
    }
}
