import QtQuick
import Clavis.WeatherMap 1.0

Item {
    id: root

    property bool active: false
    property var tiles: []
    property bool weatherEnabled: true
    property string weatherLayer: "temp_new"
    property int zoomLevel: 6
    property int generation: 0
    property real panX: 0
    property real panY: 0
    property real weatherOpacity: 0.62
    property int readyWeatherTiles: 0
    property real previousWeatherOpacity: 0

    signal firstWeatherTileReady()

    x: panX
    y: panY

    function sourceFrom(result) {
        if (!result || result.url === undefined)
            return ""
        return String(result.url)
    }

    function beginModeTransition() {
        if (!root.active)
            return
        root.readyWeatherTiles = 0
        root.previousWeatherOpacity = root.weatherOpacity
        for (let index = 0; index < tileRepeater.count; ++index) {
            const item = tileRepeater.itemAt(index)
            if (item)
                item.requestWeather(true)
        }
    }

    function finishTransition() {
        root.previousWeatherOpacity = 0
        clearPreviousTimer.restart()
    }

    function refreshWeather() {
        if (!root.active || !root.weatherEnabled)
            return
        root.readyWeatherTiles = 0
        for (let index = 0; index < tileRepeater.count; ++index) {
            const item = tileRepeater.itemAt(index)
            if (item)
                item.requestWeather(false)
        }
    }

    onGenerationChanged: {
        readyWeatherTiles = 0
        previousWeatherOpacity = 0
    }
    onWeatherLayerChanged: transitionTimer.restart()
    onWeatherEnabledChanged: transitionTimer.restart()

    Timer {
        id: transitionTimer
        interval: 0
        onTriggered: root.beginModeTransition()
    }

    Timer {
        id: clearPreviousTimer
        interval: 220
        onTriggered: {
            for (let index = 0; index < tileRepeater.count; ++index) {
                const item = tileRepeater.itemAt(index)
                if (item)
                    item.previousWeatherSource = ""
            }
        }
    }

    Repeater {
        id: tileRepeater

        model: root.tiles

        delegate: Item {
            id: tile

            required property var modelData

            x: modelData.screenX
            y: modelData.screenY
            width: 256
            height: 256

            property string baseSource: ""
            property string weatherSource: ""
            property string previousWeatherSource: ""
            property string requestedLayer: ""
            property bool weatherCounted: false

            function requestTiles() {
                if (!root.active)
                    return

                const baseResult = WeatherMapPlugin.requestTile(
                    "base",
                    "",
                    root.zoomLevel,
                    modelData.x,
                    modelData.y,
                    root.generation
                )
                baseSource = root.sourceFrom(baseResult)

                requestWeather(false)
            }

            function requestWeather(preserveCurrent) {
                if (preserveCurrent && weatherSource !== "")
                    previousWeatherSource = weatherSource
                weatherSource = ""
                weatherCounted = false

                if (!root.active || !root.weatherEnabled)
                    return

                requestedLayer = root.weatherLayer
                const weatherResult = WeatherMapPlugin.requestTile(
                    "weather",
                    requestedLayer,
                    root.zoomLevel,
                    modelData.x,
                    modelData.y,
                    root.generation
                )
                weatherSource = root.sourceFrom(weatherResult)
                if (weatherSource !== "")
                    markWeatherReady()
            }

            function markWeatherReady() {
                if (weatherCounted)
                    return
                weatherCounted = true
                root.readyWeatherTiles += 1
                if (root.readyWeatherTiles === 1) {
                    root.firstWeatherTileReady()
                    root.finishTransition()
                }
            }

            Component.onCompleted: requestTiles()

            Connections {
                target: WeatherMapPlugin

                function onTileReady(
                    kind,
                    layer,
                    zoom,
                    x,
                    y,
                    generation,
                    localUrl,
                    stale
                ) {
                    if (generation !== root.generation
                        || zoom !== root.zoomLevel
                        || x !== tile.modelData.x
                        || y !== tile.modelData.y) {
                        return
                    }

                    if (kind === "base") {
                        tile.baseSource = localUrl
                    } else if (kind === "weather"
                        && layer === tile.requestedLayer
                        && layer === root.weatherLayer) {
                        tile.weatherSource = localUrl
                    }
                }

                function onTileActivity(
                    layer,
                    zoom,
                    x,
                    y,
                    generation,
                    hasSignal
                ) {
                    if (generation !== root.generation
                        || zoom !== root.zoomLevel
                        || x !== tile.modelData.x
                        || y !== tile.modelData.y
                        || layer !== tile.requestedLayer
                        || layer !== root.weatherLayer) {
                        return
                    }
                    tile.markWeatherReady()
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#d9d7d0"
            }

            Image {
                anchors.fill: parent
                source: tile.baseSource
                asynchronous: true
                cache: true
                smooth: false
                mipmap: false
                fillMode: Image.Stretch
            }

            Image {
                anchors.fill: parent
                source: tile.previousWeatherSource
                asynchronous: true
                cache: true
                smooth: false
                mipmap: false
                fillMode: Image.Stretch
                opacity: status === Image.Ready
                    ? root.previousWeatherOpacity
                    : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Image {
                anchors.fill: parent
                source: tile.weatherSource
                asynchronous: true
                cache: true
                smooth: false
                mipmap: false
                fillMode: Image.Stretch
                opacity: status === Image.Ready ? root.weatherOpacity : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
