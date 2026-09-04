import QtQuick
import Qt5Compat.GraphicalEffects
import Clavis.WeatherMap
import qs.Common
import qs.Modules.Map
import qs.Services
import qs.Widgets.common

Rectangle {
    id: root

    property real latitude: 0
    property real longitude: 0
    property bool locationAvailable: false
    property bool active: visible
    property bool showLayerSelector: true
    property string selectedLayer: "radar"
    property bool mapTilerRuntimeFallback: false
    readonly property string preferredBase: UiPreferences.weatherMapBaseProvider
    readonly property string preferredOverlay: UiPreferences.weatherMapOverlayProvider
    readonly property bool mapTilerAvailable: WeatherMapPlugin.mapTilerStatus === "ready" || WeatherMapPlugin.mapTilerStatus === "loading"
    readonly property bool openWeatherAvailable: WeatherMapPlugin.status === "ready" || WeatherMapPlugin.status === "loading"
    readonly property string effectiveBase: preferredBase === "maptiler" && WeatherMapPlugin.mapTilerConfigured && mapTilerAvailable && !mapTilerRuntimeFallback ? "maptiler" : "openfreemap"
    readonly property string effectiveOverlay: preferredOverlay === "openweather" && WeatherMapPlugin.apiConfigured && openWeatherAvailable ? "openweather" : "rainviewer"
    readonly property bool darkBase: effectiveOverlay === "openweather" && selectedLayer === "clouds"
    readonly property string baseStyleUrl: effectiveBase === "maptiler" ? WeatherMapPlugin.mapTilerStyleUrl(darkBase ? "dataviz-dark" : "dataviz") : "https://tiles.openfreemap.org/styles/" + (darkBase ? "dark" : "positron")
    readonly property string overlayTileUrl: effectiveOverlay === "rainviewer" ? WeatherMapPlugin.radarTileUrl : WeatherMapPlugin.openWeatherTileUrl(selectedLayer)
    readonly property bool overlayLoading: effectiveOverlay === "rainviewer" && WeatherMapPlugin.radarStatus === "loading"
    readonly property bool overlayFailed: effectiveOverlay === "rainviewer" && WeatherMapPlugin.radarStatus !== "idle" && WeatherMapPlugin.radarStatus !== "loading" && WeatherMapPlugin.radarStatus !== "ready"

    function refreshMap() {
        if (root.effectiveOverlay === "rainviewer")
            WeatherMapPlugin.refreshRadarMetadata();
        else
            WeatherMapPlugin.validateOpenWeatherLayer(root.selectedLayer);
        if (root.effectiveBase === "maptiler")
            WeatherMapPlugin.validateMapTilerStyle(root.darkBase ? "dataviz-dark" : "dataviz");

        map.reload();
    }

    function validatePreferredProviders() {
        if (!root.active)
            return ;

        if (root.preferredBase === "maptiler" && WeatherMapPlugin.mapTilerConfigured)
            WeatherMapPlugin.validateMapTilerStyle(root.darkBase ? "dataviz-dark" : "dataviz");

        if (root.preferredOverlay === "openweather" && WeatherMapPlugin.apiConfigured)
            WeatherMapPlugin.validateOpenWeatherLayer(root.selectedLayer);

    }

    function normalizeLayer() {
        const normalized = WeatherMapProviders.normalizedLayer(root.effectiveOverlay, root.selectedLayer);
        if (root.selectedLayer !== normalized)
            root.selectedLayer = normalized;

    }

    radius: Appearance.rounding.large
    color: Appearance.colors.colSurfaceContainerHigh
    clip: true
    layer.enabled: true
    layer.samples: 4
    onPreferredBaseChanged: mapTilerRuntimeFallback = false
    onSelectedLayerChanged: root.validatePreferredProviders()
    onActiveChanged: {
        WeatherMapPlugin.active = active;
        root.validatePreferredProviders();
    }
    Component.onCompleted: {
        root.normalizeLayer();
        WeatherMapPlugin.active = root.active;
        root.validatePreferredProviders();
    }
    Component.onDestruction: WeatherMapPlugin.active = false
    onEffectiveOverlayChanged: {
        root.normalizeLayer();
    }

    Connections {
        function onApiKeyChanged() {
            root.validatePreferredProviders();
        }

        function onMapTilerApiKeyChanged() {
            root.mapTilerRuntimeFallback = false;
            root.validatePreferredProviders();
        }

        target: WeatherMapPlugin
    }

    MapLibreView {
        id: map

        anchors.fill: parent
        active: root.active && root.locationAvailable
        styleUrl: root.baseStyleUrl
        centerLatitude: root.latitude
        centerLongitude: root.longitude
        markerLatitude: root.latitude
        markerLongitude: root.longitude
        zoomLevel: 6
        markerVisible: root.locationAvailable
        overlayTileUrl: root.overlayTileUrl
        overlayOpacity: 0.72
        overlayMaximumZoom: root.effectiveOverlay === "rainviewer" ? 7 : 19
        onMapStateChanged: {
            if (mapState === "error" && root.effectiveBase === "maptiler")
                root.mapTilerRuntimeFallback = true;

        }
    }

    WeatherMapLayerSelector {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Metrics.spacingM
        visible: root.showLayerSelector && root.locationAvailable
        providerId: root.effectiveOverlay
        currentLayer: root.selectedLayer
        onLayerSelected: (layerId) => {
            return root.selectedLayer = layerId;
        }
    }

    MapLegend {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Metrics.spacingM
        visible: root.locationAvailable && root.overlayTileUrl !== ""
        providerId: root.effectiveOverlay
        mode: root.selectedLayer
        updatedAt: root.effectiveOverlay === "rainviewer" && WeatherMapPlugin.radarFrameTime > 0 ? new Date(WeatherMapPlugin.radarFrameTime * 1000) : new Date(NaN)
        stale: root.overlayFailed
        backdropSource: map
    }

    IconButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Metrics.spacingM
        visible: root.locationAvailable
        iconName: "my_location"
        accessibleName: qsTr("回到天气位置")
        variant: "filled"
        normalContainerColor: "#D9111111"
        iconColor: "white"
        onClicked: map.recenter(root.latitude, root.longitude, 6)
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Metrics.spacingM
        width: overlayStatus.implicitWidth + Metrics.spacingM * 2
        height: overlayStatus.implicitHeight + Metrics.spacingS * 2
        radius: Appearance.rounding.full
        visible: root.overlayLoading || root.overlayFailed || root.preferredBase !== root.effectiveBase || root.preferredOverlay !== root.effectiveOverlay
        color: Appearance.colors.colSurfaceContainerHighest

        Text {
            id: overlayStatus

            anchors.centerIn: parent
            text: root.preferredBase !== root.effectiveBase ? qsTr("当前使用 OpenFreeMap") : root.preferredOverlay !== root.effectiveOverlay ? qsTr("当前使用 RainViewer") : root.overlayLoading ? qsTr("正在加载天气图层") : qsTr("天气图层暂时不可用")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Typography.labelSmall.family
            font.pixelSize: Typography.labelSmall.pixelSize
        }

    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Metrics.spacingM
        anchors.bottomMargin: Metrics.spacingM + Metrics.controlHeightM + 4
        visible: root.effectiveOverlay === "rainviewer"
        text: "Weather data by RainViewer"
        color: Appearance.colors.colOnImage
        font.family: Typography.labelSmall.family
        font.pixelSize: 9
    }

    MapFallback {
        anchors.fill: parent
        visible: !root.locationAvailable
        loading: false
        message: qsTr("天气位置暂不可用")
        onRetryRequested: WeatherPlugin.refresh()
    }

    layer.effect: OpacityMask {

        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }

    }

}
