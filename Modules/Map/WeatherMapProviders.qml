pragma Singleton
import QtQuick

QtObject {
    readonly property var providers: ({
                                          "rainviewer": {
                                              "id": "rainviewer",
                                              "label": qsTr("RainViewer"),
                                              "requiresKey": false,
                                              "maximumTileZoom": 7,
                                              "maximumDisplayZoom": 7.5,
                                              "supportedLayers": ["radar"]
                                          },
                                          "openweather": {
                                              "id": "openweather",
                                              "label": qsTr("OpenWeather"),
                                              "requiresKey": true,
                                              "supportedLayers": ["temperature", "precipitation", "clouds",
                                                  "wind", "pressure"]
                                          }
                                      })
    readonly property var layerMetadata: ({
                                              "radar": {
                                                  "id": "radar",
                                                  "label": qsTr("Radar"),
                                                  "icon": "radar"
                                              },
                                              "temperature": {
                                                  "id": "temperature",
                                                  "label": qsTr("Temperature"),
                                                  "icon": "thermostat"
                                              },
                                              "precipitation": {
                                                  "id": "precipitation",
                                                  "label": qsTr("Precipitation"),
                                                  "icon": "rainy"
                                              },
                                              "clouds": {
                                                  "id": "clouds",
                                                  "label": qsTr("Cloud cover"),
                                                  "icon": "cloud"
                                              },
                                              "wind": {
                                                  "id": "wind",
                                                  "label": qsTr("Wind speed"),
                                                  "icon": "air"
                                              },
                                              "pressure": {
                                                  "id": "pressure",
                                                  "label": qsTr("Pressure"),
                                                  "icon": "compress"
                                              }
                                          })

    function provider(providerId) {
        return providers[providerId] || providers.rainviewer;
    }

    function supports(providerId, layerId) {
        return provider(providerId).supportedLayers.indexOf(layerId) >= 0;
    }

    function normalizedLayer(providerId, layerId) {
        const metadata = provider(providerId);
        return metadata.supportedLayers.indexOf(layerId) >= 0 ? layerId : metadata.supportedLayers[0];
    }

    function layerOptions(providerId) {
        return provider(providerId).supportedLayers.map(layerId => {
            return layerMetadata[layerId];
        });
    }
}
