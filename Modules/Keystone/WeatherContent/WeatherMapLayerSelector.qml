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
    horizontalPadding: 8
    buttonMinWidth: 36
    iconOnly: true
    model: WeatherMapProviders.layerOptions(providerId).map((layer) => {
        return ({
            "value": layer.id,
            "label": layer.label,
            "icon": layer.icon,
            "tooltip": layer.label
        });
    })
    Accessible.name: qsTr("天气地图图层")
    onValueSelected: (value) => {
        return root.layerSelected(value);
    }
}
