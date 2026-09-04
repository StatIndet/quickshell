import QtQuick
import qs.Modules.Map
import qs.Widgets.common

StyledButtonGroup {
    id: root

    property string providerId: "rainviewer"
    property string currentLayer: "radar"

    signal layerSelected(string layerId)

    currentValue: currentLayer
    buttonHeight: 34
    horizontalPadding: 11
    buttonMinWidth: 42
    textPixelSize: 11
    model: WeatherMapProviders.layerOptions(providerId).map((layer) => {
        return ({
            "value": layer.id,
            "label": layer.label,
            "icon": layer.icon
        });
    })
    Accessible.name: qsTr("天气地图图层")
    onValueSelected: (value) => {
        return root.layerSelected(value);
    }
}
