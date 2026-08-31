import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Notifications
import qs.Common

Item {
    id: root

    property string appIcon: ""
    property string image: ""
    property string summary: ""
    property var urgency: NotificationUrgency.Normal
    property bool imageLoaded: false
    property bool imageLoadFailed: false
    property bool appIconLoadFailed: false
    readonly property bool isUrgent: urgency === NotificationUrgency.Critical || String(urgency).endsWith("Critical")
    readonly property bool appIconIsFile: appIcon.startsWith("file://") || appIcon.startsWith("/")
    readonly property string imageSource: normalizeSource(image)
    readonly property string appIconSource: appIcon === "" ? "" : appIconIsFile ? normalizeSource(appIcon) : resolvedIconSource(appIcon)
    readonly property bool hasImage: imageSource !== "" && !image.startsWith("icon:")
    readonly property bool hasAppIcon: appIconSource !== ""
    readonly property bool showImage: hasImage && imageLoaded && !imageLoadFailed
    readonly property bool showAppIcon: !showImage && hasAppIcon && !appIconLoadFailed
    readonly property bool showSymbol: !showImage && (!hasAppIcon || appIconLoadFailed)

    function normalizeSource(source) {
        if (!source)
            return "";

        return source.startsWith("/") ? "file://" + source : source;
    }

    function resolvedIconSource(iconName) {
        const iconPath = Quickshell.iconPath(iconName, "image-missing");
        return iconPath && iconPath !== "" ? iconPath : "image://icon/" + iconName;
    }

    implicitWidth: 44
    implicitHeight: 44
    onImageChanged: {
        root.imageLoaded = false;
        root.imageLoadFailed = false;
    }
    onAppIconChanged: root.appIconLoadFailed = false

    Rectangle {
        anchors.fill: parent
        radius: root.isUrgent ? Appearance.rounding.normal : width / 2
        color: root.isUrgent ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer
    }

    Text {
        anchors.centerIn: parent
        visible: root.showSymbol
        text: root.isUrgent ? "priority_high" : "notifications"
        font.family: Fonts.materialSymbolsRounded
        font.pixelSize: root.width * 0.55
        color: root.isUrgent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
    }

    Image {
        id: appIconImage

        anchors.fill: parent
        anchors.margins: root.appIconIsFile ? 0 : root.width * 0.12
        source: root.appIconSource
        fillMode: root.appIconIsFile ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        asynchronous: true
        visible: root.showAppIcon && !root.appIconIsFile
        onStatusChanged: root.appIconLoadFailed = status === Image.Error
    }

    OpacityMask {
        anchors.fill: parent
        source: appIconImage
        maskSource: imageMask
        visible: root.showAppIcon && root.appIconIsFile
    }

    Image {
        id: notificationImage

        anchors.fill: parent
        source: root.imageSource
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: true
        visible: false
        onStatusChanged: {
            root.imageLoaded = status === Image.Ready;
            root.imageLoadFailed = status === Image.Error;
        }
    }

    Rectangle {
        id: imageMask

        anchors.fill: parent
        radius: width / 2
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: notificationImage
        maskSource: imageMask
        visible: root.showImage
    }

    Rectangle {
        width: 18
        height: 18
        radius: width / 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: Appearance.colors.colLayer4
        visible: root.showImage && root.hasAppIcon

        Image {
            anchors.centerIn: parent
            width: 14
            height: 14
            source: root.appIconSource
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

    }

}
