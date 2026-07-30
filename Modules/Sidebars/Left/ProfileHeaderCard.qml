import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets.common

AccountProfileHeader {
    id: root

    property string screenName: ""
    readonly property int wallpaperRevision: WallpaperService.revision
    readonly property string resolvedWallpaperPath: wallpaperRevision >= 0
        ? (WallpaperService.wallpaperForScreen(screenName)
            || WallpaperService.currentWallpaper
            || PersonalizationConfig.wallpaperPath)
        : ""

    coverHeight: Math.round(width / 3.8)
    profileAreaHeight: 88
    avatarSize: 72
    wallpaperPath: resolvedWallpaperPath
    colorWallpaper: WallpaperService.isColorSource(resolvedWallpaperPath)
    avatarUrl: AvatarService.avatarUrl
    fallbackAvatarUrl: Paths.fileUrl(Paths.defaultAvatar)
    accountIdentity: SystemIdentityService.accountIdentity
    distroId: SystemIdentityService.distroId
    distroName: SystemIdentityService.distroName
    uptimeText: SystemIdentityService.uptimeText
    showPackageStats: false
    avatarActionLabel: qsTr("打开设置中心")

    onAvatarActivated: {
        WidgetState.leftSidebarOpen = false;
        Quickshell.execDetached([
            "qs",
            "--path",
            Paths.shellDir + "/controlcenter.qml"
        ]);
    }
}
