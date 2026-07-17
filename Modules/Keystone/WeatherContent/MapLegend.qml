import QtQuick
import QtQuick.Layouts
import qs.Common

Rectangle {
    id: root

    property string mode: "temp"
    property date updatedAt
    property bool stale: false
    property Item backdropSource: null
    property rect backdropRect: Qt.rect(0, 0, width, height)

    implicitWidth: 184
    implicitHeight: 70
    radius: Appearance.rounding.normal
    color: "transparent"

    FrostedMapSurface {
        anchors.fill: parent
        z: 0
        sourceItem: root.backdropSource
        sourceRect: root.backdropRect
        radius: root.radius
        blurAmount: 0.64
        tint: Appearance.applyAlpha(
            Appearance.colors.colScrim,
            0.52
        )
    }

    function colorsForMode() {
        if (mode === "temp")
            return ["#6e40aa", "#3b82f6", "#55c667", "#fde725", "#ef4444"]
        if (mode === "rain")
            return ["#dbeafe", "#60a5fa", "#2563eb", "#7c3aed"]
        if (mode === "aqi")
            return ["#00e400", "#ffff00", "#ff7e00", "#ff0000", "#8f3f97", "#7e0023"]
        return ["#6e40aa", "#3b82f6", "#55c667", "#fde725", "#ef4444"]
    }

    function titleText() {
        if (mode === "temp")
            return "Temperature"
        if (mode === "rain")
            return "Precipitation"
        if (mode === "aqi")
            return "AQI · regional estimate"
        return "Weather"
    }

    function minimumLabel() {
        if (mode === "temp")
            return "Cold"
        if (mode === "rain")
            return "Light"
        if (mode === "aqi")
            return "Good"
        return ""
    }

    function maximumLabel() {
        if (mode === "temp")
            return "Hot"
        if (mode === "rain")
            return "Heavy"
        if (mode === "aqi")
            return "Hazardous"
        return ""
    }

    function updateText() {
        let value = ""
        if (updatedAt && !isNaN(updatedAt.getTime()))
            value = Qt.formatDateTime(updatedAt, "hh:mm")
        if (stale)
            value = value === "" ? "Cached" : value + " · cached"
        return value
    }

    ColumnLayout {
        anchors.fill: parent
        z: 1
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.titleText()
                color: Appearance.colors.colOnImage
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                text: root.updateText()
                visible: text !== ""
                color: Appearance.applyAlpha(
                    Appearance.colors.colOnImage,
                    0.82
                )
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 10
                textFormat: Text.PlainText
            }
        }

        Canvas {
            id: colorScale

            Layout.fillWidth: true
            Layout.preferredHeight: 8
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const colors = root.colorsForMode()
                const gradient = ctx.createLinearGradient(0, 0, width, 0)
                for (let index = 0; index < colors.length; ++index) {
                    gradient.addColorStop(
                        index / Math.max(1, colors.length - 1),
                        colors[index]
                    )
                }

                const radius = Math.min(height / 2, width / 2)
                ctx.beginPath()
                ctx.moveTo(radius, 0)
                ctx.lineTo(width - radius, 0)
                ctx.arc(
                    width - radius,
                    radius,
                    radius,
                    -Math.PI / 2,
                    Math.PI / 2,
                    false
                )
                ctx.lineTo(radius, height)
                ctx.arc(
                    radius,
                    radius,
                    radius,
                    Math.PI / 2,
                    Math.PI * 1.5,
                    false
                )
                ctx.closePath()
                ctx.fillStyle = gradient
                ctx.fill()
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: root
                function onModeChanged() {
                    colorScale.requestPaint()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.minimumLabel()
                color: Appearance.colors.colOnImage
                font.family: Sizes.fontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
                textFormat: Text.PlainText
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.maximumLabel()
                color: Appearance.colors.colOnImage
                font.family: Sizes.fontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
                textFormat: Text.PlainText
            }
        }
    }
}
