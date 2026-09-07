import QtQuick
import qs.Modules.FilePicker

FilePickerWindow {
    id: root

    requiresParentWindow: true
    selectionMode: FilePickerWindow.FilesAndFolders
    dialogTitle: qsTr("Select wallpaper or folder")
    description: qsTr("Select an image as wallpaper or a folder as the wallpaper directory")
    windowIconName: "wallpaper"
    emptyStateText: qsTr("This folder contains no selectable wallpapers")
    selectionPrompt: qsTr("Select a wallpaper or folder")
    acceptLabel: qsTr("Apply")
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
