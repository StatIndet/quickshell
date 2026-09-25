import QtQuick
import Clavis.Files
import qs.Services

Item {
    id: root
    required property string entryKey
    readonly property var currentEntry: {
        const revision = DockService.revision;
        const value = DockService.entryFor(entryKey);
        return value ? {
                           url: value.url,
                           kind: value.kind,
                           icon: value.icon,
                           sort: value.sort,
                           display: value.display
                       } : null;
    }
    property var retainedEntry: null
    onCurrentEntryChanged: {
        if (currentEntry)
            retainedEntry = currentEntry;
    }
    Component.onCompleted: retainedEntry = currentEntry
    readonly property var entry: currentEntry || retainedEntry
    readonly property var info: entry && entry.url ? Object.assign({}, DesktopFiles.info(entry.url), {
                                                                       isDirectory: entry.kind === "folder",
                                                                       icon: entry.icon
                                                                   }) : ({})
    DockFileIcon {
        anchors.fill: parent
        info: root.info
        visible: !stack.active || !stack.item || stack.item.count === 0
    }
    Loader {
        id: stack
        anchors.fill: parent
        active: root.visible && !!root.entry && root.entry.kind === "folder" && root.entry.display === "stack"
                && !!root.info.available
        sourceComponent: Item {
            readonly property int count: folder.count
            DockFolderModel {
                id: folder
                folder: root.entry.url
                sort: root.entry.sort
            }
            Repeater {
                model: Math.min(3, folder.count)
                DockFileIcon {
                    required property int index
                    info: folder.get(index)
                    transformed: true
                    width: parent.width * 0.85
                    height: width
                    x: (parent.width - width) / 2 + index * 2
                    y: (parent.height - height) / 2 - index * 3
                    rotation: (index - 1) * 9
                    z: 3 - index
                }
            }
        }
    }
}
