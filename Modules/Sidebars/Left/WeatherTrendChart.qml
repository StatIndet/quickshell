import QtQuick
import qs.Common

Canvas {
    id: root

    property var sourceModel
    property string mode: "hourly"
    property int maxItems: 8
    property color lineColor: Appearance.colors.colPrimary
    property color secondLineColor: Appearance.colors.colSecondary
    property color fillColor: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.18)
    property color outlineColor: Qt.rgba(
        Appearance.colors.colOutline.r,
        Appearance.colors.colOutline.g,
        Appearance.colors.colOutline.b,
        0.22
    )
    property color textColor: Appearance.colors.colOnSurfaceVariant
    property bool dualLine: false

    antialiasing: true

    function modelCount() {
        return sourceModel && sourceModel.count ? Math.min(maxItems, sourceModel.count()) : 0
    }

    function itemAt(index) {
        return sourceModel && sourceModel.get ? sourceModel.get(index) : ({})
    }

    function numberValue(item, key, fallback) {
        const v = item ? item[key] : undefined
        return (v === undefined || v === null || isNaN(v)) ? fallback : Number(v)
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        const count = modelCount()
        if (count < 2) return

        let values = []
        let lowValues = []
        let min = 9999
        let max = -9999
        for (let i = 0; i < count; ++i) {
            const item = itemAt(i)
            const high = mode === "daily"
                ? numberValue(item, "temperatureMaxC", 0)
                : numberValue(item, "temperatureC", 0)
            const low = mode === "daily"
                ? numberValue(item, "temperatureMinC", high)
                : high
            values.push(high)
            lowValues.push(low)
            min = Math.min(min, high, low)
            max = Math.max(max, high, low)
        }
        if (Math.abs(max - min) < 0.1) {
            max += 1
            min -= 1
        }

        const padX = 18
        const padY = 16
        const usableW = width - padX * 2
        const usableH = height - padY * 2

        function xAt(i) {
            return padX + usableW * i / (count - 1)
        }

        function yAt(v) {
            return padY + usableH * (1 - (v - min) / (max - min))
        }

        ctx.strokeStyle = root.outlineColor
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(padX, yAt((min + max) / 2))
        ctx.lineTo(width - padX, yAt((min + max) / 2))
        ctx.stroke()

        ctx.beginPath()
        for (let j = 0; j < count; ++j) {
            if (j === 0) ctx.moveTo(xAt(j), yAt(values[j]))
            else ctx.lineTo(xAt(j), yAt(values[j]))
        }
        for (let k = count - 1; k >= 0; --k) {
            ctx.lineTo(xAt(k), root.dualLine ? yAt(lowValues[k]) : height - padY)
        }
        ctx.closePath()
        ctx.fillStyle = root.fillColor
        ctx.fill()

        drawLine(ctx, values, root.lineColor, 4)
        if (root.dualLine) drawLine(ctx, lowValues, root.secondLineColor, 3)

        ctx.fillStyle = root.textColor
        ctx.font = "11px \"JetBrainsMono Nerd Font\""
        ctx.textAlign = "center"
        for (let n = 0; n < count; ++n) {
            if (n !== 0 && n !== count - 1 && n % 2 !== 0) continue
            ctx.fillText(Math.round(values[n]) + "°", xAt(n), Math.max(11, yAt(values[n]) - 8))
        }
    }

    function drawLine(ctx, values, color, lineWidth) {
        const count = values.length
        const padX = 18
        const padY = 16
        const usableW = width - padX * 2
        const usableH = height - padY * 2
        let min = Math.min.apply(Math, values)
        let max = Math.max.apply(Math, values)
        if (root.dualLine && root.mode === "daily") {
            for (let i = 0; i < root.modelCount(); ++i) {
                const item = root.itemAt(i)
                min = Math.min(min, root.numberValue(item, "temperatureMinC", min))
                max = Math.max(max, root.numberValue(item, "temperatureMaxC", max))
            }
        }
        if (Math.abs(max - min) < 0.1) {
            max += 1
            min -= 1
        }
        function xAt(i) { return padX + usableW * i / (count - 1) }
        function yAt(v) { return padY + usableH * (1 - (v - min) / (max - min)) }

        ctx.strokeStyle = color
        ctx.lineWidth = lineWidth
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.beginPath()
        for (let j = 0; j < count; ++j) {
            if (j === 0) ctx.moveTo(xAt(j), yAt(values[j]))
            else ctx.lineTo(xAt(j), yAt(values[j]))
        }
        ctx.stroke()
    }

    Connections {
        target: root.sourceModel
        ignoreUnknownSignals: true
        function onModelReset() { root.requestPaint() }
        function onDataChanged() { root.requestPaint() }
        function onRowsInserted() { root.requestPaint() }
        function onRowsRemoved() { root.requestPaint() }
    }

    onSourceModelChanged: requestPaint()
    onModeChanged: requestPaint()
    onMaxItemsChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onSecondLineColorChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onOutlineColorChanged: requestPaint()
    onTextColorChanged: requestPaint()
    onDualLineChanged: requestPaint()
    onVisibleChanged: {
        if (visible)
            requestPaint()
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
}
