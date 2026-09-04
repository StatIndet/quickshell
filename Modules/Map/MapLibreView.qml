import QtQuick

Item {
    id: root

    property bool active: visible
    property string styleUrl: "https://tiles.openfreemap.org/styles/liberty"
    property real centerLatitude: 0
    property real centerLongitude: 0
    property real markerLatitude: 0
    property real markerLongitude: 0
    property real zoomLevel: 10
    property real bearing: 0
    property real tilt: 0
    property bool markerVisible: true
    property string overlayTileUrl: ""
    property real overlayOpacity: 0.72
    property int overlayMaximumZoom: 7
    property string mapState: "inactive"
    property string errorMessage: ""
    property var styleRequest: null
    readonly property bool ready: mapState === "ready"

    signal coordinateTapped(real latitude, real longitude)
    signal cameraMoved(real latitude, real longitude, real zoom, real bearing, real tilt)

    function reload() {
        root.unload();
        if (!root.active)
            return ;

        root.mapState = "loading";
        root.errorMessage = "";
        const request = new XMLHttpRequest();
        root.styleRequest = request;
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || root.styleRequest !== request)
                return ;

            root.styleRequest = null;
            if (request.status < 200 || request.status >= 300) {
                root.fail(qsTr("地图样式暂时不可用"));
                return ;
            }
            try {
                JSON.parse(request.responseText);
            } catch (error) {
                root.fail(qsTr("地图样式无效"));
                return ;
            }
            const properties = {
                "styleUrl": root.styleUrl,
                "centerLatitude": root.centerLatitude,
                "centerLongitude": root.centerLongitude,
                "markerLatitude": root.markerLatitude,
                "markerLongitude": root.markerLongitude,
                "zoomLevel": root.zoomLevel,
                "bearing": root.bearing,
                "tilt": root.tilt,
                "markerVisible": root.markerVisible
            };
            let renderer = "MapLibreMap.qml";
            if (root.overlayTileUrl !== "") {
                renderer = "MapLibreWeatherMap.qml";
                properties.overlayTileUrl = root.overlayTileUrl;
                properties.overlayOpacity = root.overlayOpacity;
                properties.overlayMaximumZoom = root.overlayMaximumZoom;
            }
            mapLoader.setSource(Qt.resolvedUrl(renderer), properties);
            mapLoader.active = true;
        };
        request.open("GET", root.styleUrl);
        request.send();
    }

    function unload() {
        if (root.styleRequest) {
            root.styleRequest.abort();
            root.styleRequest = null;
        }
        mapLoader.active = false;
        mapLoader.source = "";
        root.mapState = root.active ? "loading" : "inactive";
    }

    function fail(message) {
        mapLoader.active = false;
        root.mapState = "error";
        root.errorMessage = message || qsTr("地图暂时不可用");
    }

    function recenter(latitudeValue, longitudeValue, zoomValue) {
        root.centerLatitude = latitudeValue;
        root.centerLongitude = longitudeValue;
        if (zoomValue !== undefined)
            root.zoomLevel = zoomValue;

        if (mapLoader.item)
            mapLoader.item.recenter(latitudeValue, longitudeValue, zoomValue);

    }

    onActiveChanged: active ? reload() : unload()
    onStyleUrlChanged: {
        if (active)
            reload();

    }
    onOverlayTileUrlChanged: {
        if (active)
            reload();

    }
    Component.onCompleted: {
        if (active)
            reload();

    }
    Component.onDestruction: unload()

    Loader {
        id: mapLoader

        anchors.fill: parent
        active: false
        asynchronous: true
        onStatusChanged: {
            if (status === Loader.Error) {
                root.fail(qsTr("无法创建地图"));
            } else if (status === Loader.Ready && item) {
                item.mapReady.connect(function() {
                    root.mapState = "ready";
                });
                item.mapFailed.connect(root.fail);
                item.coordinateTapped.connect(root.coordinateTapped);
                item.cameraMoved.connect(root.cameraMoved);
                if (item.ready)
                    root.mapState = "ready";
                else if (item.errorString.length > 0)
                    root.fail(item.errorString);
            }
        }
    }

    Binding {
        target: mapLoader.item
        property: "centerLatitude"
        value: root.centerLatitude
        when: mapLoader.status === Loader.Ready
    }

    Binding {
        target: mapLoader.item
        property: "centerLongitude"
        value: root.centerLongitude
        when: mapLoader.status === Loader.Ready
    }

    Binding {
        target: mapLoader.item
        property: "markerLatitude"
        value: root.markerLatitude
        when: mapLoader.status === Loader.Ready
    }

    Binding {
        target: mapLoader.item
        property: "markerLongitude"
        value: root.markerLongitude
        when: mapLoader.status === Loader.Ready
    }

    Binding {
        target: mapLoader.item
        property: "zoomLevel"
        value: root.zoomLevel
        when: mapLoader.status === Loader.Ready
    }

    Binding {
        target: mapLoader.item
        property: "bearing"
        value: root.bearing
        when: mapLoader.status === Loader.Ready
    }

    Binding {
        target: mapLoader.item
        property: "tilt"
        value: root.tilt
        when: mapLoader.status === Loader.Ready
    }

    Binding {
        target: mapLoader.item
        property: "markerVisible"
        value: root.markerVisible
        when: mapLoader.status === Loader.Ready
    }

    MapFallback {
        anchors.fill: parent
        visible: root.mapState !== "ready"
        loading: root.mapState === "loading"
        message: root.errorMessage.length > 0 ? root.errorMessage : qsTr("地图暂时不可用")
        onRetryRequested: root.reload()
    }

}
