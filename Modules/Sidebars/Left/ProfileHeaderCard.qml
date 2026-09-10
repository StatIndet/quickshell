import QtQuick
import Quickshell
import qs.Modules.FilePicker
import qs.Modules.ControlCenter
import qs.Common
import qs.Services
import qs.Widgets.common

AccountProfileHeader {
    id: root

    property string screenName: ""
    coverHeight: Math.round(width / 2.5)
    profileAreaHeight: 112
    avatarSize: 96
    wallpaperPath: bannerEditor.source
    colorWallpaper: WallpaperService.isColorSource(wallpaperPath)
    avatarUrl: AvatarService.avatarUrl
    fallbackAvatarUrl: Paths.fileUrl(Paths.defaultAvatar)
    accountIdentity: SystemIdentityService.accountIdentity
    distroId: SystemIdentityService.distroId
    distroName: SystemIdentityService.distroName
    uptimeText: SystemIdentityService.uptimeText
    showNetworkStatus: false
    surfaceColor: BlurService.opaqueBackgroundColor(Appearance.m3colors.m3surfaceContainerHigh)

    ProfileBannerEditor {
        id: bannerEditor
        parentModal: root.QsWindow.window
    }
    onBannerFileActivated: bannerEditor.chooseFile()
    onBannerColorActivated: bannerEditor.chooseColor()
    onBannerCleared: bannerEditor.clear()
    Connections {
        target: WidgetState
        function onLeftSidebarOpenChanged() {
            if (!WidgetState.leftSidebarOpen) {
                bannerEditor.close();
                avatarPicker.dismiss();
            }
        }
    }
    onAvatarActivated: avatarPicker.openAt(avatarPicker.picturesDir)

    FilePickerWindow {
        id: avatarPicker
        parentModal: root.QsWindow.window
        requiresParentWindow: true
        dialogTitle: qsTranslate("AccountPage", "Choose avatar")
        onAccepted: (path, isDirectory) => {
            if (!isDirectory)
                AvatarService.setAvatar(path);
        }
    }
}
