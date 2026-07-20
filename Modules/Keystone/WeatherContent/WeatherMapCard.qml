import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
    property string tileSetSignature: ""
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property bool dragging: false
    property date layerUpdatedAt

    readonly property real maximumMercatorLatitude: 85.05112878
    readonly property int tileSize: 256
    readonly property string weatherLayer: selectedMode === "temp"
        ? "temp_new"
        : selectedMode === "rain"
            ? "precipitation_new"
            : selectedMode === "clouds"
                ? "clouds_new"
                : selectedMode === "wind"
                    ? "wind_new"
                    : selectedMode === "pressure"
                        ? "pressure_new"
                        : "temp_new"
    readonly property real weatherOpacity: selectedMode === "temp"
        ? 0.56
        : selectedMode === "rain"
            ? 0.72
            : selectedMode === "clouds"
                ? 0.64
                : selectedMode === "wind"
                    ? 0.62
                    : 0.62
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
            : selectedMode === "clouds"
                ? "Cloud cover weather map"
                : selectedMode === "wind"
                    ? "Wind speed weather map"
                    : selectedMode === "pressure"
                        ? "Atmospheric pressure weather map"
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

    function refreshMap() {
        if (!root.active || !root.hasCoordinates)
            return

        tileLayer.refreshBase(true)
        tileLayer.refreshWeather(true)
    }

    function mapStatusText() {
        switch (WeatherMapPlugin.mapTilerStatus) {
        case "not_configured":
            return "MapTiler 底图未配置"
        case "keychain_error":
            return "无法访问 MapTiler 密钥"
        case "invalid_key":
            return "MapTiler API key 无效"
        case "rate_limited":
            return "MapTiler 请求频率受限"
        case "network_error":
            return "底图网络不可用，正在使用缓存"
        default:
            return WeatherMapPlugin.errorMessage
        }
    }

    function hasMapError() {
        const baseStatus = WeatherMapPlugin.mapTilerStatus
        return (WeatherMapPlugin.credentialsReady
                && !WeatherMapPlugin.mapTilerConfigured)
            || baseStatus === "keychain_error"
            || baseStatus === "invalid_key"
            || baseStatus === "rate_limited"
            || baseStatus === "network_error"
            || (WeatherMapPlugin.credentialsReady
                && !WeatherMapPlugin.apiConfigured)
            || WeatherMapPlugin.status === "keychain_error"
            || WeatherMapPlugin.status === "invalid_key"
            || WeatherMapPlugin.status === "rate_limited"
            || WeatherMapPlugin.status === "network_error"
    }

    function rebuildTiles() {
        if (!root.active
            || !root.hasCoordinates
            || mapViewport.width < 2
            || mapViewport.height < 2) {
            root.visibleTiles = []
            root.tileSetSignature = ""
            return
        }

        const anchorCenterX = longitudeToWorldX(
            centerLongitude,
            zoomLevel
        )
        const anchorCenterY = latitudeToWorldY(
            centerLatitude,
            zoomLevel
        )
        const effectiveCenterX = anchorCenterX - dragOffsetX
        const effectiveCenterY = anchorCenterY - dragOffsetY
        const left = effectiveCenterX - mapViewport.width / 2
        const top = effectiveCenterY - mapViewport.height / 2
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
        const nextKeys = []

        for (let rawY = minimumY; rawY <= maximumY; ++rawY) {
            for (let rawX = minimumX; rawX <= maximumX; ++rawX) {
                const tileX = wrappedTileX(rawX, zoomLevel)
                const key = zoomLevel + "/" + tileX + "/" + rawY
                const screenX = rawX * tileSize - anchorCenterX
                    + mapViewport.width / 2
                const screenY = rawY * tileSize - anchorCenterY
                    + mapViewport.height / 2
                nextKeys.push(key)
                nextTiles.push({
                    key: key,
                    zoom: zoomLevel,
                    x: tileX,
                    y: rawY,
                    screenX: screenX,
                    screenY: screenY
                })
            }
        }

        const nextSignature = nextKeys.join("|")
        if (nextSignature !== root.tileSetSignature) {
            root.viewportGeneration += 1
            WeatherMapPlugin.beginViewport(root.viewportGeneration)
            root.tileSetSignature = nextSignature
        }
        root.visibleTiles = nextTiles
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
        id: panSyncTimer
        interval: 32
        repeat: true
        running: root.active && root.dragging
        onTriggered: root.rebuildTiles()
    }

    Timer {
        interval: 15 * 60 * 1000
        running: root.active
        repeat: true
        onTriggered: tileLayer.refreshWeather(false)
    }

    Connections {
        target: WeatherMapPlugin

        function onApiKeyChanged() {
            if (root.active)
                tileLayer.refreshWeather(true)
        }

        function onMapTilerApiKeyChanged() {
            if (root.active)
                tileLayer.refreshBase(true)
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

            Item {
                id: mapBackdrop

                anchors.fill: parent
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: mapBackdrop.width
                        height: mapBackdrop.height
                        radius: root.radius
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.colors.colWeatherCardSurface
                }

                Item {
                    id: panningLayer

                    anchors.fill: parent
                    transform: Translate {
                        x: root.dragOffsetX
                        y: root.dragOffsetY
                    }

                    WeatherTileLayer {
                        id: tileLayer

                        anchors.fill: parent
                        active: root.active && root.hasCoordinates
                        tiles: root.visibleTiles
                        weatherLayer: root.weatherLayer
                        weatherOpacity: root.weatherOpacity
                        zoomLevel: root.zoomLevel
                        generation: root.viewportGeneration
                        onFirstWeatherTileReady: root.layerUpdatedAt = new Date()
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
                    root.dragging = true
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
                    root.dragging = false
                    root.commitPan()
                    mouse.accepted = true
                }

                onCanceled: {
                    root.dragOffsetX = 0
                    root.dragOffsetY = 0
                    root.dragging = false
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
                visible: root.hasMapError()

                Text {
                    id: statusText
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: root.mapStatusText()
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamily
                    font.pixelSize: 10
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            MapLegend {
                id: mapLegend

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
                z: 20
                backdropSource: mapBackdrop
                backdropRect: Qt.rect(x, y, width, height)
                mode: root.selectedMode
                updatedAt: root.layerUpdatedAt
                stale: WeatherMapPlugin.status === "network_error"
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

                background: FrostedMapSurface {
                    sourceItem: mapBackdrop
                    sourceRect: Qt.rect(
                        recenterButton.x,
                        recenterButton.y,
                        recenterButton.width,
                        recenterButton.height
                    )
                    radius: Appearance.rounding.full
                    blurAmount: 0.66
                    tint: recenterButton.down
                        ? Appearance.applyAlpha(
                            Appearance.colors.colScrim,
                            0.68
                        )
                        : recenterButton.hovered || recenterButton.activeFocus
                            ? Appearance.applyAlpha(
                                Appearance.colors.colScrim,
                                0.60
                            )
                            : Appearance.applyAlpha(
                                Appearance.colors.colScrim,
                                0.52
                            )
                }

                contentItem: MaterialSymbol {
                    text: "my_location"
                    iconSize: 20
                    fill: root.followingLocation ? 1 : 0
                    color: recenterButton.enabled
                        ? Appearance.colors.colOnImage
                        : Appearance.applyAlpha(
                            Appearance.colors.colOnImage,
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
                running: root.active
                    && (WeatherMapPlugin.busy
                        || WeatherMapPlugin.credentialBusy)
                visible: running
                Material.accent: Appearance.colors.colPrimary
            }

            Text {
                id: attributionText

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.bottomMargin: 12
                z: 20
                text: "© MapTiler · © OpenStreetMap contributors"
                    + " · Weather: OpenWeather"
                color: Appearance.colors.colOnPrimaryFixed
                font.family: Sizes.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                textFormat: Text.PlainText
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

        }
    }
}
