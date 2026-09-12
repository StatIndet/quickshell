import QtQuick

Rectangle {
    id: root

    property string mode: "radar"

    function colorsForMode() {
        if (mode === "radar")
            return ["#8ec7ff", "#3f83f8", "#22c55e", "#facc15", "#ef4444"];

        if (mode === "temperature")
            return ["#6e40aa", "#3b82f6", "#55c667", "#fde725", "#ef4444"];

        if (mode === "precipitation")
            return ["#dbeafe", "#93c5fd", "#60a5fa", "#2563eb", "#7c3aed"];

        if (mode === "clouds")
            return ["#eef2f6", "#d9e0e8", "#b9c3cf", "#8e99a6", "#66717f"];

        if (mode === "wind")
            return ["#dbeafe", "#5eead4", "#facc15", "#f97316", "#dc2626"];

        if (mode === "pressure")
            return ["#7c3aed", "#3b82f6", "#22c55e", "#facc15", "#ef4444"];

        return ["#6e40aa", "#3b82f6", "#55c667", "#fde725", "#ef4444"];
    }

    implicitWidth: 164
    implicitHeight: 6
    radius: height / 2

    gradient: Gradient {
        orientation: Gradient.Horizontal

        GradientStop {
            position: 0
            color: root.colorsForMode()[0]
        }
        GradientStop {
            position: 0.25
            color: root.colorsForMode()[1]
        }
        GradientStop {
            position: 0.5
            color: root.colorsForMode()[2]
        }
        GradientStop {
            position: 0.75
            color: root.colorsForMode()[3]
        }
        GradientStop {
            position: 1
            color: root.colorsForMode()[4]
        }
    }
}
