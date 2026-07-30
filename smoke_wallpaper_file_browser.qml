//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.ControlCenter

ShellRoot {
    id: root

    property bool selected: false

    WallpaperFileBrowser {
        id: browser

        onFileSelected: path => {
            root.selected = path === "/tmp/clavis-wallpaper-smoke.png";
        }
    }

    Timer {
        interval: 120
        running: true
        onTriggered: {
            try {
                browser.openAt(Paths.homeDir);
                if (!browser.visible)
                    throw new Error("floating picker did not open");
                if (!browser.acceptFilesOnSingleClick)
                    throw new Error("single-click wallpaper apply disabled");

                browser.selectEntry(
                    "/tmp/clavis-wallpaper-smoke.png",
                    "clavis-wallpaper-smoke.png",
                    false);
                browser.acceptSelection();
                if (!root.selected)
                    throw new Error("file selection was not forwarded");
                console.log("WALLPAPER_FILE_BROWSER_SMOKE_PASS");
            } catch (error) {
                console.error(
                    "WALLPAPER_FILE_BROWSER_SMOKE_FAIL", error);
            }
            Qt.callLater(Qt.quit);
        }
    }
}
