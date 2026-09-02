import QtQuick
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

    coverHeight: Math.round(width / 2.5)
    profileAreaHeight: 112
    avatarSize: 96
    wallpaperPath: resolvedWallpaperPath
    colorWallpaper: WallpaperService.isColorSource(resolvedWallpaperPath)
    avatarUrl: AvatarService.avatarUrl
    fallbackAvatarUrl: Paths.fileUrl(Paths.defaultAvatar)
    accountIdentity: SystemIdentityService.accountIdentity
    distroId: SystemIdentityService.distroId
    distroName: SystemIdentityService.distroName
    uptimeText: SystemIdentityService.uptimeText
    showNetworkStatus: false
    surfaceColor: BlurService.opaqueBackgroundColor(
        Appearance.m3colors.m3surfaceContainerHigh)
    avatarActionLabel: qsTr("打开设置中心")

    onAvatarActivated: {
        WidgetState.leftSidebarOpen = false;
        ControlCenterService.open();
    }
}
