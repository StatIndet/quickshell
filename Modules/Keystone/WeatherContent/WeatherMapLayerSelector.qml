import QtQuick
import qs.Widgets.common

StyledButtonGroup {
    id: root

    property string currentMode: "temp"
    signal modeSelected(string mode)

    currentValue: currentMode
    style: StyledButtonGroup.Style.Primary
    buttonHeight: 34
    horizontalPadding: 11
    buttonMinWidth: 42
    pressedExpansion: 4
    textPixelSize: 11
    model: [
        ({
            "value": "temp",
            "label": "Temp",
            "tooltip": "Temperature heat map"
        }),
        ({
            "value": "rain",
            "label": "Rain",
            "tooltip": "Current precipitation map"
        }),
        ({
            "value": "clouds",
            "label": "Clouds",
            "tooltip": "Current cloud cover map"
        }),
        ({
            "value": "wind",
            "label": "Wind",
            "tooltip": "Current wind speed map"
        }),
        ({
            "value": "pressure",
            "label": "Pressure",
            "tooltip": "Current atmospheric pressure map"
        })
    ]

    Accessible.name: "Weather map layer"
    onValueSelected: value => root.modeSelected(value)
}
