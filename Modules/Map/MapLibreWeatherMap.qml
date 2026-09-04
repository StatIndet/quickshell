import QtQuick
import QtLocation
import QtPositioning
import MapLibre 3.0
import qs.Common

Item {
    id: root

    required property string styleUrl
    required property string overlayTileUrl
    property real centerLatitude: 0
    property real centerLongitude: 0
    property real markerLatitude: 0
    property real markerLongitude: 0
    property real zoomLevel: 10
    property real bearing: 0
    property real tilt: 0
    property bool markerVisible: true
    property bool markerDraggable: false
    property real overlayOpacity: 0.72
    property int overlayMaximumZoom: 7
    readonly property bool ready: mapView.map.mapReady
    readonly property string errorString: mapView.map.error !== 0 ? mapView.map.errorString : ""

    signal mapReady()
    signal mapFailed(string message)
    signal coordinateTapped(real latitude, real longitude)
    signal markerMoved(real latitude, real longitude)
    signal cameraMoved(real latitude, real longitude, real zoom, real bearing, real tilt)

    function recenter(latitudeValue, longitudeValue, zoomValue) {
        mapView.map.center = QtPositioning.coordinate(latitudeValue, longitudeValue);
        if (zoomValue !== undefined)
            mapView.map.zoomLevel = zoomValue;

    }

    Component.onCompleted: {
        if (root.ready)
            root.mapReady();

    }

    Plugin {
        id: mapLibrePlugin

        name: "maplibre"

        PluginParameter {
            name: "maplibre.map.styles"
            value: root.styleUrl
        }

    }

    MapView {
        id: mapView

        anchors.fill: parent
        map.plugin: mapLibrePlugin
        map.center: QtPositioning.coordinate(root.centerLatitude, root.centerLongitude)
        map.zoomLevel: root.zoomLevel
        map.bearing: root.bearing
        map.tilt: root.tilt
        map.copyrightsVisible: true
        map.color: Appearance.colors.colSurfaceContainerHigh

        Connections {
            function onMapReadyChanged() {
                if (mapView.map.mapReady)
                    root.mapReady();

            }

            function onErrorChanged() {
                if (mapView.map.error !== 0)
                    root.mapFailed(mapView.map.errorString);

            }

            function onCenterChanged() {
                root.cameraMoved(mapView.map.center.latitude, mapView.map.center.longitude, mapView.map.zoomLevel, mapView.map.bearing, mapView.map.tilt);
            }

            function onZoomLevelChanged() {
                root.cameraMoved(mapView.map.center.latitude, mapView.map.center.longitude, mapView.map.zoomLevel, mapView.map.bearing, mapView.map.tilt);
            }

            function onBearingChanged() {
                root.cameraMoved(mapView.map.center.latitude, mapView.map.center.longitude, mapView.map.zoomLevel, mapView.map.bearing, mapView.map.tilt);
            }

            function onTiltChanged() {
                root.cameraMoved(mapView.map.center.latitude, mapView.map.center.longitude, mapView.map.zoomLevel, mapView.map.bearing, mapView.map.tilt);
            }

            target: mapView.map
        }

        MapLibre.style: Style {
            SourceParameter {
                property var tiles: [root.overlayTileUrl]
                property int tileSize: 256

                styleId: "clavis-weather-overlay-source"
                type: "raster"
            }

            LayerParameter {
                property string source: "clavis-weather-overlay-source"
                // MapLibre Native Qt 3.0 drops source maxzoom, but forwards layer maxzoom.
                property real maxzoom: root.overlayMaximumZoom + 1

                styleId: "clavis-weather-overlay-layer"
                type: "raster"
                paint: {
                    "raster-opacity": root.overlayOpacity,
                    "raster-opacity-transition": {
                        "duration": 200,
                        "delay": 0
                    }
                }
            }

        }

    }

    MapQuickItem {
        parent: mapView.map
        visible: root.markerVisible
        coordinate: QtPositioning.coordinate(root.markerLatitude, root.markerLongitude)
        anchorPoint: Qt.point(24, 24)
        zoomLevel: 0

        sourceItem: MapCoordinateMarker {
        }

    }

}
