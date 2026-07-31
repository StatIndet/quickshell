//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.FilePicker

ShellRoot {
    id: root

    property int phase: 0
    property int layoutWaitTicks: 0
    property bool wallpaperSelected: false
    property bool avatarSelected: false
    readonly property string testPath:
        Quickshell.env("CLAVIS_FILE_PICKER_SMOKE_PATH")
            || Paths.assetsDir + "/wlogout/icons"

    function verify(condition, message) {
        if (!condition)
            throw new Error(message);
    }

    function gridLayoutReady(grid) {
        if (grid.count < 12 || grid.width <= 0)
            return false;
        const columns = Math.max(
            1, Math.floor(grid.width / 146));
        const sampleCount = Math.min(
            grid.count, columns * 2);
        const occupied = {};
        for (let index = 0; index < sampleCount; ++index) {
            const item = grid.itemAtIndex(index);
            if (!item)
                return false;
            const expectedX = (index % columns) * grid.cellWidth;
            const expectedY = Math.floor(index / columns)
                * grid.cellHeight;
            if (Math.abs(item.x - expectedX) > 1
                    || Math.abs(item.y - expectedY) > 1)
                return false;
            const slot = Math.round(item.x) + ","
                + Math.round(item.y);
            if (occupied[slot])
                return false;
            occupied[slot] = true;
        }
        return true;
    }

    WallpaperFileBrowser {
        id: browser

        onFileSelected: path => {
            root.wallpaperSelected =
                path === "/tmp/clavis-wallpaper-smoke.png";
        }
    }

    FilePickerWindow {
        id: avatarPicker

        onAccepted: path => {
            root.avatarSelected =
                path === "/tmp/clavis-avatar-smoke.png";
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: true

        onTriggered: {
            try {
                if (root.phase === 0) {
                    browser.blurController.compositorEnabled = true;
                    browser.openAt(root.testPath);
                    root.verify(browser.visible,
                        "floating picker did not open");
                    root.verify(browser.acceptFilesOnSingleClick,
                        "single-click wallpaper apply disabled");
                    root.verify(
                        !browser.fileGridView.animateAppearance
                        && !browser.fileGridView.animateMovement,
                        "file grid still animates stale layout positions");
                    root.phase = 1;
                    return;
                }

                if (root.phase === 1) {
                    if (!browser.blurController.surfaceReady)
                        return;
                    root.verify(
                        browser.BackgroundEffect.blurRegion
                            === browser.blurController.region,
                        "file picker blur region was not submitted");
                    root.verify(
                        browser.blurController.regionObjects.length
                            === 1
                        && browser.blurController
                            .regionObjects[0].item
                            === browser.blurBackground,
                        "blur region does not target outer background");
                    root.verify(
                        browser.blurController
                            .regionObjects[0].radius
                            === Math.round(
                                browser.blurBackground.radius),
                        "blur radius does not match outer background");
                    if (!root.gridLayoutReady(
                            browser.fileGridView)) {
                        ++root.layoutWaitTicks;
                        root.verify(root.layoutWaitTicks < 50,
                            "grid did not lay out all initial columns");
                        return;
                    }
                    browser.implicitWidth = 960;
                    browser.implicitHeight = 640;
                    root.layoutWaitTicks = 0;
                    root.phase = 2;
                    return;
                }

                if (root.phase === 2) {
                    if (!root.gridLayoutReady(
                            browser.fileGridView)) {
                        ++root.layoutWaitTicks;
                        root.verify(root.layoutWaitTicks < 50,
                            "grid did not relayout after resize");
                        return;
                    }
                    root.verify(
                        browser.blurBackground.width
                            === browser.width
                        && browser.blurBackground.height
                            === browser.height,
                        "blur background did not follow resize");
                    browser.selectEntry(
                        "/tmp/clavis-wallpaper-smoke.png",
                        "clavis-wallpaper-smoke.png",
                        false);
                    browser.acceptSelection();
                    root.phase = 3;
                    return;
                }

                if (root.phase === 3) {
                    root.verify(root.wallpaperSelected,
                        "wallpaper selection was not forwarded");
                    root.verify(
                        browser.BackgroundEffect.blurRegion === null,
                        "hidden wallpaper picker retained blur");
                    avatarPicker.blurController.compositorEnabled = true;
                    avatarPicker.openAt(Paths.homeDir);
                    root.phase = 4;
                    return;
                }

                if (root.phase === 4) {
                    if (!avatarPicker.blurController.surfaceReady)
                        return;
                    avatarPicker.selectEntry(
                        "/tmp/clavis-avatar-smoke.png",
                        "clavis-avatar-smoke.png",
                        false);
                    avatarPicker.acceptSelection();
                    root.phase = 5;
                    return;
                }

                if (root.phase === 5) {
                    root.verify(root.avatarSelected,
                        "avatar selection was not returned");
                    root.verify(
                        avatarPicker.BackgroundEffect.blurRegion
                            === null,
                        "hidden avatar picker retained blur");
                    stop();
                    console.log(
                        "WALLPAPER_FILE_BROWSER_SMOKE_PASS");
                    Qt.callLater(Qt.quit);
                }
            } catch (error) {
                stop();
                console.error(
                    "WALLPAPER_FILE_BROWSER_SMOKE_FAIL", error);
                Qt.callLater(Qt.quit);
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: {
            console.error(
                "WALLPAPER_FILE_BROWSER_SMOKE_FAIL",
                "timeout phase=" + root.phase);
            Qt.quit();
        }
    }
}
