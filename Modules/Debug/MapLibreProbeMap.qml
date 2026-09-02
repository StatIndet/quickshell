import QtQuick
import QtLocation
import QtPositioning
import MapLibre 3.0
import qs.Common

Item {
    id: root

    readonly property real testLatitude: 30.2741
    readonly property real testLongitude: Number("120.1551")
    required property string styleUrl
    readonly property bool ready: mapView.map.mapReady
    readonly property string errorString: mapView.map.error !== 0 ? mapView.map.errorString : ""

    signal mapReady()
    signal mapFailed(string message)
    signal coordinateClicked(string coordinate)

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
        map.center: QtPositioning.coordinate(root.testLatitude, root.testLongitude)
        map.zoomLevel: 12
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

            target: mapView.map
        }

        MapLibre.style: Style {
        }

    }

    MapQuickItem {
        parent: mapView.map
        coordinate: QtPositioning.coordinate(root.testLatitude, root.testLongitude)
        anchorPoint: Qt.point(10, 10)
        zoomLevel: 0

        sourceItem: Rectangle {
            width: 20
            height: 20
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary
            border.width: 3
            border.color: Appearance.colors.colOnPrimary
        }

    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (eventPoint) => {
            const coordinate = mapView.map.toCoordinate(eventPoint.position, true);
            if (!coordinate.isValid)
                return ;

            root.coordinateClicked(coordinate.latitude.toFixed(6) + ", " + coordinate.longitude.toFixed(6));
        }
    }

}
