import QtQuick
import QtQml.Models
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

    function tileKey(tile) {
        if (!tile)
            return ""
        if (tile.key !== undefined)
            return String(tile.key)
        return String(tile.zoom) + "/" + String(tile.x) + "/" + String(tile.y)
    }

    function modelIndexForKey(key) {
        for (let index = 0; index < tileModel.count; ++index) {
            if (tileModel.get(index).tileKey === key)
                return index
        }
        return -1
    }

    function syncTiles(nextTiles) {
        const safeTiles = nextTiles || []
        const retainedKeys = ({})

        for (let index = 0; index < safeTiles.length; ++index)
            retainedKeys[tileKey(safeTiles[index])] = true

        for (let index = tileModel.count - 1; index >= 0; --index) {
            if (!retainedKeys[tileModel.get(index).tileKey])
                tileModel.remove(index)
        }

        for (let index = 0; index < safeTiles.length; ++index) {
            const next = safeTiles[index]
            const key = tileKey(next)
            const existingIndex = modelIndexForKey(key)
            if (existingIndex < 0) {
                tileModel.append({
                    tileKey: key,
                    tileZoom: Number(next.zoom),
                    tileX: Number(next.x),
                    tileY: Number(next.y),
                    screenX: Number(next.screenX),
                    screenY: Number(next.screenY)
                })
                continue
            }

            const current = tileModel.get(existingIndex)
            const nextScreenX = Number(next.screenX)
            const nextScreenY = Number(next.screenY)
            if (Math.abs(current.screenX - nextScreenX) > 0.01) {
                tileModel.setProperty(
                    existingIndex,
                    "screenX",
                    nextScreenX
                )
            }
            if (Math.abs(current.screenY - nextScreenY) > 0.01) {
                tileModel.setProperty(
                    existingIndex,
                    "screenY",
                    nextScreenY
                )
            }
        }
    }

    function scheduleVisibleTileRequests(forceRequests) {
        if (forceRequests)
            generationRefreshTimer.forceRequests = true
        generationRefreshTimer.restart()
    }

    function requestVisibleTiles(forceRequests) {
        if (!root.active)
            return
        for (let index = 0; index < tileRepeater.count; ++index) {
            const item = tileRepeater.itemAt(index)
            if (item)
                item.requestTiles(forceRequests)
        }
    }

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
                item.requestWeather(true, true)
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
                item.requestWeather(false, true)
        }
    }

    onTilesChanged: syncTiles(tiles)
    onActiveChanged: {
        if (active)
            scheduleVisibleTileRequests(true)
    }
    onGenerationChanged: {
        readyWeatherTiles = 0
        previousWeatherOpacity = 0
        scheduleVisibleTileRequests(false)
    }
    onWeatherLayerChanged: transitionTimer.restart()
    onWeatherEnabledChanged: transitionTimer.restart()

    Component.onCompleted: syncTiles(tiles)

    Timer {
        id: generationRefreshTimer
        property bool forceRequests: false

        interval: 0
        onTriggered: {
            root.requestVisibleTiles(forceRequests)
            forceRequests = false
        }
    }

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

    ListModel {
        id: tileModel
    }

    Repeater {
        id: tileRepeater

        model: tileModel

        delegate: Item {
            id: tile

            required property string tileKey
            required property int tileZoom
            required property int tileX
            required property int tileY
            required property real screenX
            required property real screenY

            x: screenX
            y: screenY
            width: 256
            height: 256

            property string baseSource: ""
            property string weatherSource: ""
            property string previousWeatherSource: ""
            property string requestedLayer: ""
            property bool weatherCounted: false
            property int baseRequestGeneration: -1
            property int weatherRequestGeneration: -1

            function requestTiles(forceRequest) {
                if (!root.active)
                    return

                if (forceRequest
                    || baseRequestGeneration !== root.generation) {
                    baseRequestGeneration = root.generation
                    const baseResult = WeatherMapPlugin.requestTile(
                        "base",
                        "",
                        tile.tileZoom,
                        tile.tileX,
                        tile.tileY,
                        tile.baseRequestGeneration
                    )
                    const nextBaseSource = root.sourceFrom(baseResult)
                    if (nextBaseSource !== "")
                        baseSource = nextBaseSource
                }

                requestWeather(false, forceRequest)
            }

            function requestWeather(preserveCurrent, forceRequest) {
                const nextLayer = root.weatherLayer
                const layerChanged = requestedLayer !== ""
                    && requestedLayer !== nextLayer
                if (preserveCurrent
                    && (layerChanged || !root.weatherEnabled)
                    && weatherSource !== "") {
                    previousWeatherSource = weatherSource
                }
                if (layerChanged || !root.weatherEnabled)
                    weatherSource = ""

                if (!root.active || !root.weatherEnabled) {
                    weatherCounted = false
                    requestedLayer = ""
                    weatherRequestGeneration = -1
                    return
                }

                if (!forceRequest
                    && !layerChanged
                    && requestedLayer === nextLayer
                    && weatherRequestGeneration === root.generation) {
                    return
                }

                weatherCounted = false
                requestedLayer = nextLayer
                weatherRequestGeneration = root.generation
                const weatherResult = WeatherMapPlugin.requestTile(
                    "weather",
                    requestedLayer,
                    tile.tileZoom,
                    tile.tileX,
                    tile.tileY,
                    tile.weatherRequestGeneration
                )
                const nextWeatherSource = root.sourceFrom(weatherResult)
                if (nextWeatherSource !== "")
                    weatherSource = nextWeatherSource
                if (weatherSource !== "" && requestedLayer === nextLayer)
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
                    if (zoom !== tile.tileZoom
                        || x !== tile.tileX
                        || y !== tile.tileY) {
                        return
                    }

                    if (kind === "base") {
                        if (generation !== tile.baseRequestGeneration)
                            return
                        tile.baseSource = localUrl
                    } else if (kind === "weather"
                        && generation === tile.weatherRequestGeneration
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
                    if (generation !== tile.weatherRequestGeneration
                        || zoom !== tile.tileZoom
                        || x !== tile.tileX
                        || y !== tile.tileY
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
                retainWhileLoading: true
                smooth: false
                mipmap: false
                fillMode: Image.Stretch
            }

            Image {
                anchors.fill: parent
                source: tile.previousWeatherSource
                asynchronous: true
                cache: true
                retainWhileLoading: true
                smooth: false
                mipmap: false
                fillMode: Image.Stretch
                opacity: source !== ""
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
                retainWhileLoading: true
                smooth: false
                mipmap: false
                fillMode: Image.Stretch
                opacity: source !== "" ? root.weatherOpacity : 0

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
