import QtQuick
import qs.Services
import qs.Modules.FilePicker

Item {
    id: root
    property var parentModal: null
    readonly property string source: WallpaperPaletteSession.previewForScreen("banner", "")
                                     || PersonalizationConfig.bannerSource
                                     || WallpaperService.currentWallpaper

    function chooseFile() {
        filePicker.openAt(WallpaperService.isImagePath(root.source) ? WallpaperService.parentFolder(
                                                                          root.source) :
                                                                      PersonalizationConfig.wallpaperFolder);
    }
    function chooseColor() {
        colorPicker.showFor("banner", "");
    }
    function clear() {
        PersonalizationConfig.setBannerSource("");
    }
    function close() {
        filePicker.dismiss();
        colorPicker.close();
    }
    WallpaperFileBrowser {
        id: filePicker
        parentModal: root.parentModal
        selectionMode: FilePickerWindow.Files
        dialogTitle: qsTranslate("AccountProfileHeader", "Choose banner image")
        description: ""
        selectionPrompt: dialogTitle
        onFileSelected: path => PersonalizationConfig.setBannerSource(path)
    }
    WallpaperColorPicker {
        id: colorPicker
        parentModal: root.parentModal
    }
}
