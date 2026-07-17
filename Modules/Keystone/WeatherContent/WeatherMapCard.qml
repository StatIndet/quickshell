import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Clavis.WeatherMap 1.0
import qs.Common
import qs.Components
import qs.Widgets.common

Rectangle {
    id: root

    property real latitude: 0
    property real longitude: 0
    property bool active: false
    property bool locationAvailable: true
    property string selectedMode: "temp"
    property int zoomLevel: 6
    property real centerLatitude: latitude
    property real centerLongitude: longitude
    property bool followingLocation: true
    property bool initialized: false
    property int viewportGeneration: 0
    property var visibleTiles: []
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property date layerUpdatedAt
    property date gridUpdatedAt
    property bool gridStale: false
    property string gridErrorCode: ""
    property var rawGridSamples: []
    property var projectedGridSamples: []

    readonly property real maximumMercatorLatitude: 85.05112878
    readonly property int tileSize: 256
    readonly property bool weatherEnabled: selectedMode !== "aqi"
    readonly property string weatherLayer: selectedMode === "temp"
        ? "temp_new"
        : selectedMode === "rain"
            ? "precipitation_new"
            : ""
    readonly property real weatherOpacity: selectedMode === "temp"
        ? 0.56
        : selectedMode === "rain"
            ? 0.72
            : 0
    readonly property bool hasCoordinates: locationAvailable
        && isFinite(latitude)
        && isFinite(longitude)
        && latitude >= -90
        && latitude <= 90
        && longitude >= -180
        && longitude <= 180

    radius: Appearance.rounding.large
    color: Appearance.colors.colSurfaceContainerHigh
    clip: true

    Material.theme: Appearance.m3colors.darkmode ? Material.Dark : Material.Light
    Material.accent: Appearance.colors.colPrimary

    Accessible.name: selectedMode === "temp"
        ? "Temperature weather map"
        : selectedMode === "rain"
            ? "Current precipitation weather map"
            : selectedMode === "aqi"
                ? "Estimated regional air quality map"
                : "Weather map"
    Accessible.description: "Drag to move the map, or use the mouse wheel to zoom"

    function clampLatitude(value) {
        return Math.max(
            -maximumMercatorLatitude,
            Math.min(maximumMercatorLatitude, value)
        )
    }

    function worldSize(zoom) {
        return tileSize * Math.pow(2, zoom)
    }

    function longitudeToWorldX(value, zoom) {
        return (value + 180) / 360 * worldSize(zoom)
    }

    function latitudeToWorldY(value, zoom) {
        const latitudeRadians = clampLatitude(value) * Math.PI / 180
        const sine = Math.sin(latitudeRadians)
        const normalized = 0.5 - Math.log(
            (1 + sine) / (1 - sine)
        ) / (4 * Math.PI)
        return normalized * worldSize(zoom)
    }

    function normalizeWorldX(value, zoom) {
        const size = worldSize(zoom)
        return ((value % size) + size) % size
    }

    function worldXToLongitude(value, zoom) {
        return normalizeWorldX(value, zoom) / worldSize(zoom) * 360 - 180
    }

    function worldYToLatitude(value, zoom) {
        const size = worldSize(zoom)
        const normalized = Math.max(0, Math.min(size, value)) / size
        const mercator = Math.PI - 2 * Math.PI * normalized
        const sinh = (Math.exp(mercator) - Math.exp(-mercator)) / 2
        return Math.atan(sinh) * 180 / Math.PI
    }

    function wrappedTileX(value, zoom) {
        const count = Math.pow(2, zoom)
        return ((value % count) + count) % count
    }

    function gridPoints() {
        if (!root.hasCoordinates
            || mapViewport.width < 2
            || mapViewport.height < 2) {
            return []
        }

        const columns = 6
        const rows = 4
        const centerX = longitudeToWorldX(centerLongitude, zoomLevel)
        const centerY = latitudeToWorldY(centerLatitude, zoomLevel)
        const points = []
        for (let row = 0; row < rows; ++row) {
            const screenY = (row + 0.5) * mapViewport.height / rows
            const worldY = centerY + screenY - mapViewport.height / 2
            for (let column = 0; column < columns; ++column) {
                const screenX = (column + 0.5) * mapViewport.width / columns
                const worldX = centerX + screenX - mapViewport.width / 2
                points.push({
                    latitude: worldYToLatitude(worldY, zoomLevel),
                    longitude: worldXToLongitude(worldX, zoomLevel)
                })
            }
        }
        return points
    }

    function projectSamples(samples) {
        if (!samples || samples.length === 0)
            return []

        const size = worldSize(zoomLevel)
        const centerX = longitudeToWorldX(centerLongitude, zoomLevel)
        const centerY = latitudeToWorldY(centerLatitude, zoomLevel)
        const projected = []
        for (let index = 0; index < samples.length; ++index) {
            const sample = samples[index]
            let deltaX = longitudeToWorldX(
                Number(sample.longitude),
                zoomLevel
            ) - centerX
            if (deltaX > size / 2)
                deltaX -= size
            else if (deltaX < -size / 2)
                deltaX += size

            const next = Object.assign({}, sample)
            next.x = mapViewport.width / 2 + deltaX
            next.y = mapViewport.height / 2
                + latitudeToWorldY(
                    Number(sample.latitude),
                    zoomLevel
                )
                - centerY
            projected.push(next)
        }
        return projected
    }

    function applyGridData(kind, samples, updatedAt, stale) {
        if (kind !== root.selectedMode)
            return

        root.rawGridSamples = samples || []
        root.projectedGridSamples = projectSamples(root.rawGridSamples)
        const parsedTime = new Date(updatedAt)
        if (!isNaN(parsedTime.getTime()))
            root.gridUpdatedAt = parsedTime
        root.gridStale = stale
        root.gridErrorCode = ""
        if (kind === "aqi")
            tileLayer.finishTransition()
    }

    function requestActiveGrid() {
        if (!root.active
            || !root.hasCoordinates
            || root.selectedMode !== "aqi") {
            return
        }

        const result = WeatherMapPlugin.requestGrid(
            root.selectedMode,
            gridPoints(),
            root.viewportGeneration
        )
        const samples = result && result.samples !== undefined
            ? result.samples
            : []
        if (samples && samples.length > 0) {
            applyGridData(
                root.selectedMode,
                samples,
                result.updatedAt || "",
                result.stale === true
            )
        }
    }

    function rebuildTiles() {
        if (!root.active
            || !root.hasCoordinates
            || mapViewport.width < 2
            || mapViewport.height < 2) {
            root.visibleTiles = []
            return
        }

        const centerX = longitudeToWorldX(centerLongitude, zoomLevel)
        const centerY = latitudeToWorldY(centerLatitude, zoomLevel)
        const left = centerX - mapViewport.width / 2
        const top = centerY - mapViewport.height / 2
        const minimumX = Math.floor(left / tileSize) - 1
        const maximumX = Math.floor(
            (left + mapViewport.width) / tileSize
        ) + 1
        const minimumY = Math.max(0, Math.floor(top / tileSize) - 1)
        const tileCount = Math.pow(2, zoomLevel)
        const maximumY = Math.min(
            tileCount - 1,
            Math.floor((top + mapViewport.height) / tileSize) + 1
        )
        const nextTiles = []

        for (let rawY = minimumY; rawY <= maximumY; ++rawY) {
            for (let rawX = minimumX; rawX <= maximumX; ++rawX) {
                const screenX = rawX * tileSize - centerX
                    + mapViewport.width / 2
                const screenY = rawY * tileSize - centerY
                    + mapViewport.height / 2
                nextTiles.push({
                    x: wrappedTileX(rawX, zoomLevel),
                    y: rawY,
                    screenX: screenX,
                    screenY: screenY,
                    inViewport: screenX < mapViewport.width
                        && screenX + tileSize > 0
                        && screenY < mapViewport.height
                        && screenY + tileSize > 0
                })
            }
        }

        root.viewportGeneration += 1
        WeatherMapPlugin.beginViewport(root.viewportGeneration)
        root.visibleTiles = nextTiles
        root.projectedGridSamples = projectSamples(root.rawGridSamples)
        if (root.selectedMode === "aqi")
            gridDebounce.restart()
    }

    function scheduleRebuild() {
        if (root.active)
            rebuildTimer.restart()
    }

    function setCenterFromWorld(worldX, worldY, zoom) {
        const size = worldSize(zoom)
        root.centerLongitude = worldXToLongitude(worldX, zoom)
        root.centerLatitude = worldYToLatitude(
            Math.max(0, Math.min(size, worldY)),
            zoom
        )
    }

    function commitPan() {
        if (dragOffsetX === 0 && dragOffsetY === 0)
            return

        const centerX = longitudeToWorldX(centerLongitude, zoomLevel)
        const centerY = latitudeToWorldY(centerLatitude, zoomLevel)
        setCenterFromWorld(
            centerX - dragOffsetX,
            centerY - dragOffsetY,
            zoomLevel
        )
        dragOffsetX = 0
        dragOffsetY = 0
        followingLocation = false
        rebuildTiles()
    }

    function changeZoom(delta, focusX, focusY) {
        const nextZoom = Math.max(3, Math.min(8, zoomLevel + delta))
        if (nextZoom === zoomLevel)
            return

        const oldZoom = zoomLevel
        const oldCenterX = longitudeToWorldX(centerLongitude, oldZoom)
        const oldCenterY = latitudeToWorldY(centerLatitude, oldZoom)
        const offsetX = focusX - mapViewport.width / 2
        const offsetY = focusY - mapViewport.height / 2
        const scale = Math.pow(2, nextZoom - oldZoom)
        const nextCenterX = (oldCenterX + offsetX) * scale - offsetX
        const nextCenterY = (oldCenterY + offsetY) * scale - offsetY

        zoomLevel = nextZoom
        setCenterFromWorld(nextCenterX, nextCenterY, nextZoom)
        followingLocation = false
        rebuildTiles()
    }

    function recenter() {
        if (!hasCoordinates)
            return
        centerLatitude = clampLatitude(latitude)
        centerLongitude = longitude
        zoomLevel = 6
        followingLocation = true
        rebuildTiles()
    }

    function markerX() {
        const size = worldSize(zoomLevel)
        let delta = longitudeToWorldX(longitude, zoomLevel)
            - longitudeToWorldX(centerLongitude, zoomLevel)
        if (delta > size / 2)
            delta -= size
        else if (delta < -size / 2)
            delta += size
        return mapViewport.width / 2 + delta
    }

    function markerY() {
        return mapViewport.height / 2
            + latitudeToWorldY(latitude, zoomLevel)
            - latitudeToWorldY(centerLatitude, zoomLevel)
    }

    onActiveChanged: {
        WeatherMapPlugin.active = active
        if (active) {
            if (!initialized && hasCoordinates) {
                initialized = true
                centerLatitude = clampLatitude(latitude)
                centerLongitude = longitude
            }
            scheduleRebuild()
        } else {
            rebuildTimer.stop()
            gridDebounce.stop()
        }
    }

    onLatitudeChanged: {
        if (followingLocation && hasCoordinates) {
            centerLatitude = clampLatitude(latitude)
            scheduleRebuild()
        }
    }

    onLongitudeChanged: {
        if (followingLocation && hasCoordinates) {
            centerLongitude = longitude
            scheduleRebuild()
        }
    }

    onSelectedModeChanged: {
        rawGridSamples = []
        projectedGridSamples = []
        gridErrorCode = ""
        gridStale = false
        gridDebounce.stop()
        if (active && selectedMode === "aqi") {
            gridDebounce.restart()
        }
    }

    Component.onCompleted: {
        WeatherMapPlugin.active = active
        if (hasCoordinates) {
            initialized = true
            centerLatitude = clampLatitude(latitude)
            centerLongitude = longitude
        }
        scheduleRebuild()
    }

    Component.onDestruction: WeatherMapPlugin.active = false

    Timer {
        id: rebuildTimer
        interval: 40
        repeat: false
        onTriggered: root.rebuildTiles()
    }

    Timer {
        id: gridDebounce
        interval: 450
        repeat: false
        onTriggered: root.requestActiveGrid()
    }

    Timer {
        interval: 15 * 60 * 1000
        running: root.active
        repeat: true
        onTriggered: {
            tileLayer.refreshWeather()
            if (root.selectedMode === "aqi") {
                gridDebounce.restart()
            }
        }
    }

    Connections {
        target: WeatherMapPlugin

        function onGridReady(kind, generation, samples, updatedAt, stale) {
            if (generation !== root.viewportGeneration
                || kind !== root.selectedMode) {
                return
            }
            root.applyGridData(kind, samples, updatedAt, stale)
        }

        function onGridFailed(kind, generation, errorCode) {
            if (generation !== root.viewportGeneration
                || kind !== root.selectedMode) {
                return
            }
            root.rawGridSamples = []
            root.projectedGridSamples = []
            root.gridErrorCode = errorCode
            if (kind === "aqi")
                tileLayer.finishTransition()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: mapViewport

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            onWidthChanged: root.scheduleRebuild()
            onHeightChanged: root.scheduleRebuild()

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.large
                color: Appearance.colors.colWeatherCardSurface
            }

            Item {
                id: panningLayer

                anchors.fill: parent
                x: root.dragOffsetX
                y: root.dragOffsetY

                WeatherTileLayer {
                    id: tileLayer

                    anchors.fill: parent
                    active: root.active && root.hasCoordinates
                    tiles: root.visibleTiles
                    weatherEnabled: root.weatherEnabled
                    weatherLayer: root.weatherLayer
                    weatherOpacity: root.weatherOpacity
                    zoomLevel: root.zoomLevel
                    generation: root.viewportGeneration
                    onFirstWeatherTileReady: root.layerUpdatedAt = new Date()
                }

                AirQualityOverlay {
                    anchors.fill: parent
                    visible: root.selectedMode === "aqi"
                        && root.projectedGridSamples.length > 0
                    samples: root.projectedGridSamples
                }

                Item {
                    x: root.markerX() - width / 2
                    y: root.markerY() - height
                    width: 32
                    height: 32
                    visible: root.hasCoordinates

                    MaterialSymbol {
                        anchors.fill: parent
                        text: "location_on"
                        iconSize: 30
                        fill: 1
                        color: Appearance.colors.colPrimary
                        style: Text.Outline
                        styleColor: Appearance.colors.colSurfaceContainerHighest
                    }
                }
            }

            MouseArea {
                id: mapInteraction

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                preventStealing: true
                cursorShape: pressed
                    ? Qt.ClosedHandCursor
                    : Qt.OpenHandCursor
                property real pressedX: 0
                property real pressedY: 0

                onPressed: mouse => {
                    pressedX = mouse.x
                    pressedY = mouse.y
                    mouse.accepted = true
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    root.dragOffsetX = mouse.x - pressedX
                    root.dragOffsetY = mouse.y - pressedY
                    mouse.accepted = true
                }

                onReleased: mouse => {
                    root.commitPan()
                    mouse.accepted = true
                }

                onCanceled: {
                    root.dragOffsetX = 0
                    root.dragOffsetY = 0
                }

                onWheel: wheel => {
                    root.changeZoom(
                        wheel.angleDelta.y >= 0 ? 1 : -1,
                        wheel.x,
                        wheel.y
                    )
                    wheel.accepted = true
                }
            }

            WeatherMapLayerSelector {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.topMargin: 12
                z: 20
                currentMode: root.selectedMode
                onModeSelected: mode => root.selectedMode = mode
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.topMargin: 56
                z: 20
                width: Math.min(
                    statusText.implicitWidth + 16,
                    parent.width - 220
                )
                height: 28
                radius: Appearance.rounding.full
                color: Appearance.applyAlpha(
                    Appearance.colors.colSurfaceContainerHighest,
                    0.94
                )
                visible: !WeatherMapPlugin.apiConfigured
                    || WeatherMapPlugin.status === "invalid_key"
                    || WeatherMapPlugin.status === "rate_limited"
                    || WeatherMapPlugin.status === "network_error"
                    || root.gridErrorCode !== ""

                Text {
                    id: statusText
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: WeatherMapPlugin.errorMessage
                        || "Regional model data unavailable"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 10
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            MapLegend {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
                z: 20
                mode: root.selectedMode
                updatedAt: root.selectedMode === "aqi"
                        ? root.gridUpdatedAt
                        : root.layerUpdatedAt
                stale: root.selectedMode === "aqi"
                        ? root.gridStale
                        : WeatherMapPlugin.status === "network_error"
            }

            ToolButton {
                id: recenterButton

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                z: 20
                width: 40
                height: 40
                enabled: root.hasCoordinates
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: "Back to current location"
                onClicked: root.recenter()

                background: Rectangle {
                    radius: Appearance.rounding.full
                    color: recenterButton.down
                        ? Appearance.colors.colSurfaceContainerHighestActive
                        : recenterButton.hovered || recenterButton.activeFocus
                            ? Appearance.colors.colSurfaceContainerHighestHover
                            : Appearance.applyAlpha(
                                Appearance.colors.colSurfaceContainerHighest,
                                0.96
                            )
                    border.width: recenterButton.activeFocus ? 1 : 0
                    border.color: Appearance.colors.colPrimary
                }

                contentItem: MaterialSymbol {
                    text: "my_location"
                    iconSize: 20
                    fill: root.followingLocation ? 1 : 0
                    color: recenterButton.enabled
                        ? Appearance.colors.colOnSurfaceVariant
                        : Appearance.applyAlpha(
                            Appearance.colors.colOnSurface,
                            0.38
                        )
                }

                StyledToolTip {
                    extraVisibleCondition: recenterButton.hovered
                    text: "Back to current location"
                }
            }

            BusyIndicator {
                anchors.right: recenterButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: recenterButton.verticalCenter
                z: 20
                width: 24
                height: 24
                running: root.active && WeatherMapPlugin.busy
                visible: running
                Material.accent: Appearance.colors.colPrimary
            }

            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.bottomMargin: 12
                z: 20
                width: attributionText.implicitWidth + 16
                height: 24
                radius: Appearance.rounding.full
                color: Appearance.applyAlpha(
                    Appearance.colors.colSurfaceContainerHighest,
                    0.92
                )

                Text {
                    id: attributionText

                    anchors.centerIn: parent
                    text: "© OpenStreetMap contributors · "
                        + (root.selectedMode === "aqi"
                            ? "Open-Meteo"
                            : "OpenWeather")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 10
                    textFormat: Text.PlainText
                }
            }

            Rectangle {
                anchors.centerIn: parent
                visible: !root.hasCoordinates
                width: waitingColumn.implicitWidth + 24
                height: waitingColumn.implicitHeight + 18
                radius: Appearance.rounding.normal
                color: Appearance.applyAlpha(
                    Appearance.colors.colSurfaceContainerHighest,
                    0.94
                )

                ColumnLayout {
                    id: waitingColumn

                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "location_off"
                        iconSize: 28
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    Text {
                        text: "Waiting for weather location"
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Sizes.fontFamily
                        font.pixelSize: 11
                        textFormat: Text.PlainText
                    }
                }
            }

            Canvas {
                id: cornerMask

                anchors.fill: parent
                z: 100
                antialiasing: true
                property color maskColor: Appearance.colors.colSurfaceContainerHigh
                property real cornerRadius: Appearance.rounding.large

                onMaskColorChanged: requestPaint()
                onCornerRadiusChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    const radius = Math.min(
                        cornerRadius,
                        width / 2,
                        height / 2
                    )
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = maskColor

                    ctx.beginPath()
                    ctx.moveTo(0, radius)
                    ctx.lineTo(0, 0)
                    ctx.lineTo(radius, 0)
                    ctx.arc(radius, radius, radius, -Math.PI / 2, -Math.PI, true)
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(width - radius, 0)
                    ctx.lineTo(width, 0)
                    ctx.lineTo(width, radius)
                    ctx.arc(
                        width - radius,
                        radius,
                        radius,
                        0,
                        -Math.PI / 2,
                        true
                    )
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(width, height - radius)
                    ctx.lineTo(width, height)
                    ctx.lineTo(width - radius, height)
                    ctx.arc(
                        width - radius,
                        height - radius,
                        radius,
                        Math.PI / 2,
                        0,
                        true
                    )
                    ctx.closePath()
                    ctx.fill()

                    ctx.beginPath()
                    ctx.moveTo(radius, height)
                    ctx.lineTo(0, height)
                    ctx.lineTo(0, height - radius)
                    ctx.arc(
                        radius,
                        height - radius,
                        radius,
                        Math.PI,
                        Math.PI / 2,
                        true
                    )
                    ctx.closePath()
                    ctx.fill()
                }
            }

            Rectangle {
                anchors.fill: parent
                z: 101
                radius: Appearance.rounding.large
                color: "transparent"
                border.width: 1
                border.color: Appearance.applyAlpha(
                    Appearance.colors.colOutlineVariant,
                    0.72
                )
            }
        }
    }
}
