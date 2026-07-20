import QtQuick
import Qt.labs.lottieqt
import qs.Common

Item {
    id: root

    property int weatherCode: -1
    property string iconName: ""
    property bool night: false
    property string style: "flat"
    property bool smooth: true
    property bool animated: true
    property bool playing: visible
    property real baseSize: 128
    readonly property string resolvedSlug: iconSlug()
    readonly property url svgSource: Paths.meteoconSvg(normalizedStyle(), resolvedSlug)
    readonly property url lottieSource: Paths.meteoconLottie(resolvedSlug)
    readonly property real fittedScale: Math.min(width / baseSize, height / baseSize)

    function normalizedStyle() {
        if (style === "fill" || style === "line" || style === "monochrome" || style === "flat") return style
        return "flat"
    }

    function slugForCode(code, isNight) {
        if (code === 0) return isNight ? "clear-night" : "clear-day"
        if (code === 1) return isNight ? "mostly-clear-night" : "mostly-clear-day"
        if (code === 2) return isNight ? "partly-cloudy-night" : "partly-cloudy-day"
        if (code === 3) return "cloudy"
        if (code === 45 || code === 48) return isNight ? "fog-night" : "fog-day"
        if (code >= 51 && code <= 57) return "drizzle"
        if (code === 61 || code === 63 || code === 65) return isNight ? "overcast-night-rain" : "overcast-day-rain"
        if (code === 66 || code === 67) return isNight ? "overcast-night-sleet" : "overcast-day-sleet"
        if (code >= 71 && code <= 77) return isNight ? "overcast-night-snow" : "overcast-day-snow"
        if (code >= 80 && code <= 82) return isNight ? "partly-cloudy-night-rain" : "partly-cloudy-day-rain"
        if (code === 85 || code === 86) return isNight ? "partly-cloudy-night-snow" : "partly-cloudy-day-snow"
        if (code === 95) return isNight ? "thunderstorms-night" : "thunderstorms-day"
        if (code === 96 || code === 99) return isNight ? "thunderstorms-night-hail" : "thunderstorms-day-hail"
        return "not-available"
    }

    function slugFromName(name, isNight) {
        if (!name || name.length === 0) return ""
        if (name.indexOf("clear_night") >= 0) return "clear-night"
        if (name.indexOf("sun") >= 0) return "clear-day"
        if (name.indexOf("partly") >= 0) return isNight ? "partly-cloudy-night" : "partly-cloudy-day"
        if (name.indexOf("cloud") >= 0) return "cloudy"
        if (name.indexOf("fog") >= 0) return isNight ? "fog-night" : "fog-day"
        if (name.indexOf("drizzle") >= 0) return "drizzle"
        if (name.indexOf("rain") >= 0) return isNight ? "overcast-night-rain" : "overcast-day-rain"
        if (name.indexOf("snow") >= 0) return isNight ? "overcast-night-snow" : "overcast-day-snow"
        if (name.indexOf("thunder") >= 0) return isNight ? "thunderstorms-night" : "thunderstorms-day"
        return ""
    }

    function iconSlug() {
        const byCode = slugForCode(weatherCode, night)
        if (byCode !== "not-available") return byCode
        const byName = slugFromName(iconName, night)
        return byName.length > 0 ? byName : "not-available"
    }

    LottieAnimation {
        id: lottieIcon
        anchors.centerIn: parent
        width: root.baseSize
        height: root.baseSize
        scale: root.fittedScale
        transformOrigin: Item.Center
        visible: root.animated && status === LottieAnimation.Ready
        source: root.lottieSource
        autoPlay: true
        loops: LottieAnimation.Infinite

        onStatusChanged: {
            if (status === LottieAnimation.Ready && root.playing) play()
        }
    }

    onPlayingChanged: {
        if (!playing) lottieIcon.pause()
        else if (lottieIcon.status === LottieAnimation.Ready) lottieIcon.play()
    }

    Image {
        anchors.fill: parent
        visible: !lottieIcon.visible
        source: root.svgSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: root.smooth
        mipmap: true
        sourceSize.width: Math.max(1, Math.round(width * 2))
        sourceSize.height: Math.max(1, Math.round(height * 2))
    }
}
