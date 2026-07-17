import QtQuick

Canvas {
    id: root

    property var samples: []

    antialiasing: true
    opacity: 0.78

    function aqiColor(value) {
        if (value <= 50)
            return "#00e400"
        if (value <= 100)
            return "#ffff00"
        if (value <= 150)
            return "#ff7e00"
        if (value <= 200)
            return "#ff0000"
        if (value <= 300)
            return "#8f3f97"
        return "#7e0023"
    }

    function rgba(colorValue, alpha) {
        const color = Qt.color(colorValue)
        return "rgba("
            + Math.round(color.r * 255) + ","
            + Math.round(color.g * 255) + ","
            + Math.round(color.b * 255) + ","
            + Math.max(0, Math.min(1, alpha)).toFixed(3) + ")"
    }

    onSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: {
        if (visible)
            requestPaint()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (!samples || samples.length === 0)
            return

        const radius = Math.max(
            34,
            Math.min(62, width / 7, height / 3)
        )
        for (let index = 0; index < samples.length; ++index) {
            const sample = samples[index]
            if (!isFinite(sample.x)
                || !isFinite(sample.y)
                || !isFinite(sample.aqi)) {
                continue
            }

            const color = aqiColor(Number(sample.aqi))
            const gradient = ctx.createRadialGradient(
                sample.x,
                sample.y,
                radius * 0.08,
                sample.x,
                sample.y,
                radius
            )
            gradient.addColorStop(0, rgba(color, 0.52))
            gradient.addColorStop(0.56, rgba(color, 0.28))
            gradient.addColorStop(1, rgba(color, 0))
            ctx.beginPath()
            ctx.arc(sample.x, sample.y, radius, 0, Math.PI * 2)
            ctx.fillStyle = gradient
            ctx.fill()
        }
    }
}
