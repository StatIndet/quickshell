import QtQuick
import qs.Modules.FilePicker

FilePickerWindow {
    id: root

    selectionMode: FilePickerWindow.FilesAndFolders
    acceptFilesOnSingleClick: true
    dialogTitle: qsTr("选择壁纸或文件夹")
    description: qsTr("选择图片作为壁纸，或选择文件夹作为壁纸目录")
    windowIconName: "wallpaper"
    emptyStateText: qsTr("当前文件夹没有可选择的壁纸")
    selectionPrompt: qsTr("选择一张壁纸或一个文件夹")
    acceptLabel: qsTr("应用")
    formatSummary: "JPG · PNG · WebP\nBMP · GIF"

    signal fileSelected(string path)
    signal folderSelected(string path)

    onAccepted: (path, isDirectory) => {
        if (isDirectory)
            root.folderSelected(path);
        else
            root.fileSelected(path);
    }
}
