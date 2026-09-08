import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Modules.Map
import qs.Services
import qs.Widgets.common

ColumnLayout {
    id: root

    property var parentModal: null
    property bool active: visible
    property real candidateLatitude: Number(WeatherPlugin.latitude)
    property real candidateLongitude: Number(WeatherPlugin.longitude)
    property real cameraLatitude: candidateLatitude
    property real cameraLongitude: candidateLongitude
    readonly property real initialZoom: 12
    readonly property real initialBearing: 0
    readonly property real initialTilt: 0
    property real mapZoom: initialZoom
    property real mapBearing: initialBearing
    property real mapTilt: initialTilt
    property string coordinateError: ""
    readonly property bool expanded: expandedWindow.visible

    function coordinateText(latitudeValue, longitudeValue) {
        return Number(latitudeValue).toFixed(6) + ", " + Number(longitudeValue).toFixed(6);
    }

    function setCandidate(latitudeValue, longitudeValue) {
        root.candidateLatitude = latitudeValue;
        root.candidateLongitude = longitudeValue;
        coordinateField.text = root.coordinateText(latitudeValue, longitudeValue);
        root.coordinateError = "";
    }

    function commitCoordinate() {
        const values = coordinateField.text.trim().split(/[\s,]+/);
        if (values.length !== 2 || values[0] === "" || values[1] === "") {
            root.coordinateError = qsTr("Enter latitude and longitude");
            return;
        }
        const latitudeValue = Number(values[0]);
        const longitudeValue = Number(values[1]);
        if (!isFinite(latitudeValue) || latitudeValue < -90 || latitudeValue > 90) {
            root.coordinateError = qsTr("Latitude must be between -90 and 90");
            return;
        }
        if (!isFinite(longitudeValue) || longitudeValue < -180 || longitudeValue > 180) {
            root.coordinateError = qsTr("Longitude must be between -180 and 180");
            return;
        }
        root.setCandidate(latitudeValue, longitudeValue);
        root.cameraLatitude = latitudeValue;
        root.cameraLongitude = longitudeValue;
        embeddedMap.recenter(latitudeValue, longitudeValue, root.mapZoom);
    }

    function returnToSavedLocation() {
        const latitudeValue = Number(WeatherPlugin.latitude);
        const longitudeValue = Number(WeatherPlugin.longitude);
        root.setCandidate(latitudeValue, longitudeValue);
        root.cameraLatitude = latitudeValue;
        root.cameraLongitude = longitudeValue;
        root.mapZoom = root.initialZoom;
        root.mapBearing = root.initialBearing;
        root.mapTilt = root.initialTilt;
        embeddedMap.recenter(latitudeValue, longitudeValue, root.initialZoom, root.initialBearing,
                             root.initialTilt);
        expandedWindow.recenter(latitudeValue, longitudeValue, root.initialZoom, root.initialBearing,
                                root.initialTilt);
    }

    function saveCoordinate() {
        root.commitCoordinate();
        if (root.coordinateError !== "")
            return;

        WeatherPlugin.setManualLocation(root.candidateLatitude, root.candidateLongitude, root.coordinateText(
                                            root.candidateLatitude, root.candidateLongitude));
    }

    function useAutomaticLocation() {
        WeatherPlugin.clearManualLocation();
    }

    function closeChildWindows() {
        expandedWindow.dismiss();
    }

    spacing: Metrics.spacingM

    Rectangle {
        id: mapFrame

        Layout.fillWidth: true
        Layout.preferredHeight: 280
        radius: Appearance.rounding.large
        color: Appearance.colors.colSurfaceContainerHigh
        clip: true
        layer.enabled: true
        layer.samples: 4

        MapLibreView {
            id: embeddedMap

            anchors.fill: parent
            active: root.active && !root.expanded
            styleUrl: "https://tiles.openfreemap.org/styles/liberty"
            centerLatitude: root.cameraLatitude
            centerLongitude: root.cameraLongitude
            markerLatitude: root.candidateLatitude
            markerLongitude: root.candidateLongitude
            markerVisible: true
            markerDraggable: true
            zoomLevel: root.mapZoom
            bearing: root.mapBearing
            tilt: root.mapTilt
            onCameraMoved: (latitudeValue, longitudeValue, zoom, bearingValue, tiltValue) => {
                root.mapZoom = zoom;
                root.cameraLatitude = latitudeValue;
                root.cameraLongitude = longitudeValue;
                root.mapBearing = bearingValue;
                root.mapTilt = tiltValue;
            }
            onMarkerMoved: (latitudeValue, longitudeValue) => {
                return root.setCandidate(latitudeValue, longitudeValue);
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Metrics.spacingM

            IconButton {
                iconName: "my_location"
                accessibleName: qsTr("Center current marker")
                iconColor: "#FF111111"
                normalHoverStateLayerColor: "#14111111"
                normalPressedStateLayerColor: "#1F111111"
                onClicked: embeddedMap.recenter(root.candidateLatitude, root.candidateLongitude, root.mapZoom)
            }

            IconButton {
                iconName: "restore"
                accessibleName: qsTr("Return to saved location and initial view")
                iconColor: "#FF111111"
                normalHoverStateLayerColor: "#14111111"
                normalPressedStateLayerColor: "#1F111111"
                onClicked: root.returnToSavedLocation()
            }

            IconButton {
                iconName: "open_in_full"
                accessibleName: qsTr("Expand map")
                iconColor: "#FF111111"
                normalHoverStateLayerColor: "#14111111"
                normalPressedStateLayerColor: "#1F111111"
                onClicked: expandedWindow.showWindow()
            }
        }

        layer.effect: OpacityMask {

            maskSource: Rectangle {
                width: mapFrame.width
                height: mapFrame.height
                radius: Appearance.rounding.large
            }
        }
    }

    OutlinedTextField {
        id: coordinateField

        Layout.fillWidth: true
        labelText: qsTr("Coordinates")
        errorText: root.coordinateError
        text: root.coordinateText(root.candidateLatitude, root.candidateLongitude)
        onTextChanged: root.coordinateError = ""
        onAccepted: root.commitCoordinate()
        onEditingFinished: root.commitCoordinate()
    }

    RowLayout {
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        InlineBusyIndicator {
            busy: WeatherPlugin.loading
        }

        ActionButton {
            id: saveLocationButton

            text: qsTr("Save location")
            iconName: "save"
            onClicked: root.saveCoordinate()
        }

        ActionButton {
            text: qsTr("Use automatic location")
            iconName: "my_location"
            enabled: WeatherPlugin.hasManualLocation && !WeatherPlugin.loading
            onClicked: root.useAutomaticLocation()
        }
    }

    Connections {
        function onDataChanged() {
            if (WeatherPlugin.hasManualLocation)
                return;

            root.candidateLatitude = Number(WeatherPlugin.latitude);
            root.candidateLongitude = Number(WeatherPlugin.longitude);
            root.cameraLatitude = root.candidateLatitude;
            root.cameraLongitude = root.candidateLongitude;
            root.setCandidate(root.candidateLatitude, root.candidateLongitude);
            embeddedMap.recenter(root.candidateLatitude, root.candidateLongitude, root.mapZoom);
        }

        target: WeatherPlugin
    }

    LocationPickerWindow {
        id: expandedWindow

        parentModal: root.parentModal
        centerLatitude: root.cameraLatitude
        centerLongitude: root.cameraLongitude
        markerLatitude: root.candidateLatitude
        markerLongitude: root.candidateLongitude
        zoomLevel: root.mapZoom
        bearing: root.mapBearing
        tilt: root.mapTilt
        onCameraChanged: (latitudeValue, longitudeValue, zoom, bearingValue, tiltValue) => {
            root.mapZoom = zoom;
            root.mapBearing = bearingValue;
            root.mapTilt = tiltValue;
            root.cameraLatitude = latitudeValue;
            root.cameraLongitude = longitudeValue;
        }
        onMarkerChanged: (latitudeValue, longitudeValue) => {
            return root.setCandidate(latitudeValue, longitudeValue);
        }
        onSaveRequested: root.saveCoordinate()
        onRestoreRequested: root.returnToSavedLocation()
    }
}
