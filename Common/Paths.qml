pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string shellDir: Quickshell.shellDir
    readonly property string assetsDir: shellDir + "/assets"
    readonly property string fontsDir: assetsDir + "/fonts"
    readonly property string iconsDir: assetsDir + "/icons"
    readonly property string appIconsDir: iconsDir + "/apps"
    readonly property string weatherIconsDir: iconsDir + "/weather"
    readonly property string meteoconsDir: weatherIconsDir + "/meteocons"
    readonly property string imagesDir: assetsDir + "/images"

    readonly property string scriptsDir: shellDir + "/scripts"
    readonly property string audioScriptsDir: scriptsDir + "/audio"
    readonly property string captureScriptsDir: scriptsDir + "/capture"
    readonly property string mediaScriptsDir: scriptsDir + "/media"
    readonly property string scheduleScriptsDir: scriptsDir + "/schedule"
    readonly property string systemScriptsDir: scriptsDir + "/system"
    readonly property string themeScriptsDir: scriptsDir + "/theme"
    readonly property string weatherScriptsDir: scriptsDir + "/weather"

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string currentWallpaper: homeDir + "/.cache/wallpaper_rofi/current"
    readonly property string scheduleCache: homeDir + "/.cache/quickshell/schedule.json"
    readonly property string profileAvatar: homeDir + "/.face"
    readonly property string defaultAvatar: homeDir + "/Pictures/avatar/shelby.jpg"

    function fileUrl(path) {
        const value = String(path);
        return value.startsWith("file://") ? value : "file://" + value;
    }

    function icon(name) {
        return fileUrl(iconsDir + "/" + name);
    }

    function appIcon(name) {
        return fileUrl(appIconsDir + "/" + name);
    }

    function scriptPath(group, name) {
        return scriptsDir + "/" + group + "/" + name;
    }

    function meteoconSvg(style, slug) {
        return fileUrl(meteoconsDir + "/svg/" + style + "/" + slug + ".svg");
    }

    function meteoconLottie(slug) {
        return fileUrl(meteoconsDir + "/lottie/fill/" + slug + ".json");
    }
}
