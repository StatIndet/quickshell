import QtQuick
import qs.Widgets.common

StyledButtonGroup {
    id: root

    property string currentMode: "temp"
    signal modeSelected(string mode)

    currentValue: currentMode
    style: StyledButtonGroup.Style.Primary
    buttonHeight: 36
    horizontalPadding: 18
    buttonMinWidth: 48
    pressedExpansion: 6
    textPixelSize: 12
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
            "value": "aqi",
            "label": "AQI",
            "tooltip": "Estimated regional air quality"
        })
    ]

    Accessible.name: "Weather map layer"
    onValueSelected: value => root.modeSelected(value)
}
