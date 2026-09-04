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
    property string viewMode: "2d"
    property real candidateLatitude: Number(WeatherPlugin.latitude)
    property real candidateLongitude: Number(WeatherPlugin.longitude)
    property real cameraLatitude: candidateLatitude
    property real cameraLongitude: candidateLongitude
    property real mapZoom: 12
    property real mapBearing: 35
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
            root.coordinateError = qsTr("请输入纬度和经度");
            return ;
        }
        const latitudeValue = Number(values[0]);
        const longitudeValue = Number(values[1]);
        if (!isFinite(latitudeValue) || latitudeValue < -90 || latitudeValue > 90) {
            root.coordinateError = qsTr("纬度必须在 -90 到 90 之间");
            return ;
        }
        if (!isFinite(longitudeValue) || longitudeValue < -180 || longitudeValue > 180) {
            root.coordinateError = qsTr("经度必须在 -180 到 180 之间");
            return ;
        }
        root.setCandidate(latitudeValue, longitudeValue);
        root.cameraLatitude = latitudeValue;
        root.cameraLongitude = longitudeValue;
        embeddedMap.recenter(latitudeValue, longitudeValue, root.mapZoom);
    }

    function saveCoordinate() {
        root.commitCoordinate();
        if (root.coordinateError !== "")
            return ;

        WeatherPlugin.setManualLocation(root.candidateLatitude, root.candidateLongitude, root.coordinateText(root.candidateLatitude, root.candidateLongitude));
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
            bearing: root.viewMode === "3d" ? root.mapBearing : 0
            tilt: root.viewMode === "3d" ? 50 : 0
            onCameraMoved: (latitudeValue, longitudeValue, zoom, bearingValue, tiltValue) => {
                root.mapZoom = zoom;
                root.cameraLatitude = latitudeValue;
                root.cameraLongitude = longitudeValue;
                if (root.viewMode === "3d")
                    root.mapBearing = bearingValue;

            }
            onMarkerMoved: (latitudeValue, longitudeValue) => {
                return root.setCandidate(latitudeValue, longitudeValue);
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Metrics.spacingM

            StyledButtonGroup {
                model: [{
                    "value": "2d",
                    "label": "2D"
                }, {
                    "value": "3d",
                    "label": "3D"
                }]
                currentValue: root.viewMode
                buttonMinWidth: 52
                onValueSelected: (value) => {
                    return root.viewMode = value;
                }
            }

        }

        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Metrics.spacingM

            IconButton {
                iconName: "my_location"
                accessibleName: qsTr("回到已选位置")
                iconColor: "#FF111111"
                normalHoverStateLayerColor: "#14111111"
                normalPressedStateLayerColor: "#1F111111"
                onClicked: embeddedMap.recenter(root.candidateLatitude, root.candidateLongitude, root.mapZoom)
            }

            IconButton {
                iconName: "open_in_full"
                accessibleName: qsTr("展开地图")
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
        labelText: qsTr("坐标")
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

        ActionButton {
            text: qsTr("保存位置")
            iconName: "save"
            onClicked: root.saveCoordinate()
        }

        ActionButton {
            text: qsTr("使用自动位置")
            iconName: "my_location"
            enabled: WeatherPlugin.hasManualLocation && !WeatherPlugin.loading
            onClicked: root.useAutomaticLocation()
        }

        MaterialLoadingIndicator {
            visible: WeatherPlugin.loading
            running: visible
        }

    }

    Connections {
        function onDataChanged() {
            if (WeatherPlugin.hasManualLocation)
                return ;

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
        viewMode: root.viewMode
        onCameraChanged: (latitudeValue, longitudeValue, zoom, bearingValue) => {
            root.mapZoom = zoom;
            if (root.viewMode === "3d")
                root.mapBearing = bearingValue;

            root.cameraLatitude = latitudeValue;
            root.cameraLongitude = longitudeValue;
        }
        onMarkerChanged: (latitudeValue, longitudeValue) => {
            return root.setCandidate(latitudeValue, longitudeValue);
        }
        onSaveRequested: root.saveCoordinate()
        onViewModeChanged: root.viewMode = expandedWindow.viewMode
    }

}
