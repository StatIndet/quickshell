import QtQuick
import QtLocation
import QtPositioning
import MapLibre 3.0
import qs.Common

Item {
    id: root

    required property string styleUrl
    property real centerLatitude: 0
    property real centerLongitude: 0
    property real markerLatitude: 0
    property real markerLongitude: 0
    property real zoomLevel: 10
    property real bearing: 0
    property real tilt: 0
    property bool markerVisible: true
    readonly property bool ready: mapView.map.mapReady
    readonly property string errorString: mapView.map.error !== 0 ? mapView.map.errorString : ""

    signal mapReady()
    signal mapFailed(string message)
    signal coordinateTapped(real latitude, real longitude)
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
        }

    }

    MapQuickItem {
        parent: mapView.map
        visible: root.markerVisible
        coordinate: QtPositioning.coordinate(root.markerLatitude, root.markerLongitude)
        anchorPoint: Qt.point(11, 11)
        zoomLevel: 0

        sourceItem: Rectangle {
            width: 22
            height: 22
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary
            border.width: 3
            border.color: Appearance.colors.colOnPrimary
        }

    }

}
