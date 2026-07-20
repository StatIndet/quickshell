import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets.weather

Rectangle {
    id: root

    property bool moon: false
    property string riseText: "--"
    property string setText: "--"
    property real riseEpoch: 0
    property real setEpoch: 0
    property real currentEpoch: Math.floor(Date.now() / 1000)
    property real phaseAngle: 0

    readonly property color cardInk: Appearance.colors.colOnWeatherCardSurface
    readonly property color titleInk: Appearance.colors.colOnWeatherCardSurfaceVariant
    readonly property color sunTrack: Qt.rgba(0.77, 0.60, 0.25, 0.55)
    readonly property color sunTrackMuted: Qt.rgba(0.77, 0.60, 0.25, 0.35)
    readonly property color sunGlowTop: Qt.rgba(0.82, 0.65, 0.31, 0.34)
    readonly property color sunGlowBottom: Qt.rgba(0.45, 0.32, 0.10, 0.04)
    readonly property color moonTrack: Qt.rgba(0.73, 0.67, 0.88, 0.55)
    readonly property color moonTrackMuted: Qt.rgba(0.73, 0.67, 0.88, 0.35)
    readonly property color moonGlowTop: Qt.rgba(0.56, 0.50, 0.74, 0.28)
    readonly property color moonGlowBottom: Qt.rgba(0.31, 0.28, 0.40, 0.03)

    readonly property real progressTarget: progressFromTimes()
    readonly property real displayProgress: progressTarget

    readonly property real trackLeft: width * 0.14
    readonly property real trackRight: width * 0.86
    readonly property real trackBaseY: height * 0.58
    readonly property real trackTopY: height * 0.30
    readonly property point markerPoint: cubicPoint(displayProgress)

    radius: 30
    color: Appearance.colors.colWeatherCardSurface
    clip: true

    function titleIconPath() {
        if (root.moon) {
            return "M17.75,4.09L15.22,6.03L16.13,9.09L13.5,7.28L10.87,9.09L11.78,6.03L9.25,4.09L12.44,4L13.5,1L14.56,4L17.75,4.09M21.25,11L19.61,12.25L20.2,14.23L18.5,13.06L16.8,14.23L17.39,12.25L15.75,11L17.81,10.95L18.5,9L19.19,10.95L21.25,11M18.97,15.95C19.8,15.87 20.69,17.05 20.16,17.8C19.84,18.25 19.5,18.67 19.08,19.07C15.17,23 8.84,23 4.94,19.07C1.03,15.17 1.03,8.83 4.94,4.93C5.34,4.53 5.76,4.17 6.21,3.85C6.96,3.32 8.14,4.21 8.06,5.04C7.79,7.9 8.75,10.87 10.95,13.06C13.14,15.26 16.1,16.22 18.97,15.95M17.33,17.97C14.5,17.81 11.7,16.64 9.53,14.5C7.36,12.31 6.2,9.5 6.04,6.68C3.23,9.82 3.34,14.64 6.35,17.66C9.37,20.67 14.19,20.78 17.33,17.97Z"
        }
        return "M3.55,18.54L4.96,19.95L6.76,18.16L5.34,16.74M11,22.45C11.32,22.45 13,22.45 13,22.45V19.5H11M12,5.5A6,6 0 0,0 6,11.5A6,6 0 0,0 12,17.5A6,6 0 0,0 18,11.5C18,8.18 15.31,5.5 12,5.5M20,12.5H23V10.5H20M17.24,18.16L19.04,19.95L20.45,18.54L18.66,16.74M20.45,4.46L19.04,3.05L17.24,4.84L18.66,6.26M13,0.55H11V3.5H13M4,10.5H1V12.5H4M6.76,4.84L4.96,3.05L3.55,4.46L5.34,6.26L6.76,4.84Z"
    }

    function progressFromTimes() {
        if (!root.riseEpoch || !root.setEpoch) return 0
        let start = root.riseEpoch
        let end = root.setEpoch
        let now = root.currentEpoch > 0 ? root.currentEpoch : Math.floor(Date.now() / 1000)
        if (end < start) {
            end += 24 * 3600
            if (now < start) now += 24 * 3600
        }
        const span = Math.max(1, end - start)
        return Math.max(0, Math.min(1, (Math.max(start, Math.min(now, end)) - start) / span))
    }

    function cubicAxis(t, p0, p1, p2, p3) {
        const mt = 1 - t
        return mt * mt * mt * p0
             + 3 * mt * mt * t * p1
             + 3 * mt * t * t * p2
             + t * t * t * p3
    }

    function cubicPoint(t) {
        const curveInset = (root.trackRight - root.trackLeft) * 0.18
        return Qt.point(
            cubicAxis(t, root.trackLeft, root.trackLeft + curveInset, root.trackRight - curveInset, root.trackRight),
            cubicAxis(t, root.trackBaseY, root.trackTopY, root.trackTopY, root.trackBaseY)
        )
    }

    function cssColor(colorValue) {
        return "rgba(" +
            Math.round(colorValue.r * 255) + "," +
            Math.round(colorValue.g * 255) + "," +
            Math.round(colorValue.b * 255) + "," +
            colorValue.a.toFixed(3) + ")"
    }

    function phaseText(angle) {
        const a = ((angle % 360) + 360) % 360
        if (a < 22.5 || a >= 337.5) return "新月"
        if (a < 67.5) return "娥眉月"
        if (a < 112.5) return "上弦月"
        if (a < 157.5) return "盈凸月"
        if (a < 202.5) return "满月"
        if (a < 247.5) return "亏凸月"
        if (a < 292.5) return "下弦月"
        return "残月"
    }

    function requestArtPaint() {
        artCanvas.requestPaint()
    }

    function requestMoonPhasePaint() {
        moonPhaseCanvas.requestPaint()
    }

    onDisplayProgressChanged: requestArtPaint()
    onMoonChanged: requestArtPaint()
    onWidthChanged: requestArtPaint()
    onHeightChanged: requestArtPaint()
    onPhaseAngleChanged: requestMoonPhasePaint()
    onProgressTargetChanged: requestArtPaint()

    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 16
        anchors.topMargin: 16
        spacing: 8
        z: 3

        Item {
            width: 24
            height: 24

            Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: root.titleInk

                    PathSvg {
                        path: root.titleIconPath()
                    }
                }
            }
        }

        Text {
            text: root.moon ? "月亮" : "太阳"
            color: root.titleInk
            font.family: "LXGW WenKai GB Screen"
            font.pixelSize: 18
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Canvas {
        id: artCanvas
        anchors.fill: parent
        anchors.margins: 0
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const progress = Math.max(0, Math.min(1, root.displayProgress))
            const current = root.cubicPoint(progress)
            const dashColor = root.moon ? root.moonTrack : root.sunTrack
            const dashMutedColor = root.moon ? root.moonTrackMuted : root.sunTrackMuted
            const fillTop = root.moon ? root.moonGlowTop : root.sunGlowTop
            const fillBottom = root.moon ? root.moonGlowBottom : root.sunGlowBottom
            const curveInset = (root.trackRight - root.trackLeft) * 0.18
            const dashA = Math.max(3, Math.round(root.width * 0.015))
            const dashB = Math.max(5, Math.round(root.width * 0.022))

            function traceSegment(uptoT) {
                const steps = 32
                for (let i = 0; i <= steps; ++i) {
                    const t = uptoT * (i / steps)
                    const point = root.cubicPoint(t)
                    if (i === 0) ctx.moveTo(point.x, point.y)
                    else ctx.lineTo(point.x, point.y)
                }
            }

            if (progress > 0.001) {
                ctx.beginPath()
                ctx.moveTo(root.trackLeft, root.trackBaseY)
                traceSegment(progress)
                ctx.lineTo(current.x, root.trackBaseY)
                ctx.closePath()
                const fillGradient = ctx.createLinearGradient(0, root.trackTopY - 6, 0, root.trackBaseY + 10)
                fillGradient.addColorStop(0, root.cssColor(fillTop))
                fillGradient.addColorStop(1, root.cssColor(fillBottom))
                ctx.fillStyle = fillGradient
                ctx.fill()
            }

            ctx.beginPath()
            ctx.moveTo(root.trackLeft, root.trackBaseY)
            ctx.bezierCurveTo(
                root.trackLeft + curveInset, root.trackTopY,
                root.trackRight - curveInset, root.trackTopY,
                root.trackRight, root.trackBaseY
            )
            ctx.lineWidth = Math.max(2, root.width * 0.012)
            ctx.strokeStyle = root.cssColor(dashMutedColor)
            ctx.setLineDash([dashA, dashB])
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(root.trackLeft, root.trackBaseY)
            ctx.lineTo(root.trackRight, root.trackBaseY)
            ctx.lineWidth = Math.max(2, root.width * 0.010)
            ctx.strokeStyle = root.cssColor(dashColor)
            ctx.setLineDash([dashA, dashB])
            ctx.lineCap = "round"
            ctx.stroke()

            if (progress > 0.001) {
                ctx.beginPath()
                traceSegment(progress)
                ctx.setLineDash([])
                ctx.lineWidth = Math.max(8, root.width * 0.042)
                ctx.strokeStyle = root.cssColor(dashColor)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.stroke()

                ctx.beginPath()
                traceSegment(progress)
                ctx.setLineDash([dashA - 1, dashB - 2])
                ctx.lineWidth = Math.max(2, root.width * 0.010)
                ctx.strokeStyle = root.cssColor(root.moon ? Qt.rgba(0.90, 0.88, 0.98, 0.48) : Qt.rgba(0.95, 0.80, 0.49, 0.56))
                ctx.lineCap = "round"
                ctx.stroke()
            }
        }
    }

    MeteoIcon {
        width: root.width * 0.20
        height: width
        x: root.markerPoint.x - width / 2
        y: root.markerPoint.y - height / 2
        weatherCode: 0
        night: root.moon
        style: "fill"
        animated: false
        smooth: true
        playing: false
        visible: root.displayProgress > 0.001
        z: 4
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.bottomMargin: root.moon ? 42 : 40
        text: root.riseText
        color: root.cardInk
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(root.width * 0.095)
        font.bold: true
        z: 3
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 18
        anchors.bottomMargin: root.moon ? 42 : 40
        text: root.setText
        color: root.cardInk
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(root.width * 0.095)
        font.bold: true
        z: 3
    }

    Row {
        visible: root.moon
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 6
        z: 3

        Canvas {
            id: moonPhaseCanvas
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                const cx = width / 2
                const cy = height / 2
                const r = width / 2 - 1.5
                const angle = ((root.phaseAngle % 360) + 360) % 360
                const light = "#efe6c7"
                const dark = "#433d54"
                const stroke = "rgba(234,228,243,0.78)"

                function drawCircle(fill) {
                    ctx.beginPath()
                    ctx.fillStyle = fill
                    ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
                    ctx.fill()
                }

                function drawHalf(fill, start, end) {
                    ctx.beginPath()
                    ctx.fillStyle = fill
                    ctx.moveTo(cx, cy)
                    ctx.arc(cx, cy, r, start, end, false)
                    ctx.closePath()
                    ctx.fill()
                }

                function drawScaledHemisphere(fill, scaleX, start, end) {
                    ctx.save()
                    ctx.translate(cx, cy)
                    ctx.scale(Math.max(0.001, scaleX), 1)
                    ctx.beginPath()
                    ctx.fillStyle = fill
                    ctx.moveTo(0, 0)
                    ctx.arc(0, 0, r, start, end, false)
                    ctx.closePath()
                    ctx.fill()
                    ctx.restore()
                }

                if (angle === 0) {
                    drawCircle(dark)
                } else if (angle < 90) {
                    drawCircle(light)
                    drawHalf(dark, Math.PI / 2, Math.PI * 1.5)
                    drawScaledHemisphere(dark, Math.cos(angle * Math.PI / 180), -Math.PI / 2, Math.PI / 2)
                } else if (angle === 90) {
                    drawCircle(dark)
                    drawHalf(light, -Math.PI / 2, Math.PI / 2)
                } else if (angle < 180) {
                    drawCircle(dark)
                    drawHalf(light, -Math.PI / 2, Math.PI / 2)
                    drawScaledHemisphere(light, Math.sin((angle - 90) * Math.PI / 180), Math.PI / 2, Math.PI * 1.5)
                } else if (angle === 180) {
                    drawCircle(light)
                } else if (angle < 270) {
                    drawCircle(dark)
                    drawHalf(light, Math.PI / 2, Math.PI * 1.5)
                    drawScaledHemisphere(light, Math.cos((angle - 180) * Math.PI / 180), -Math.PI / 2, Math.PI / 2)
                } else if (angle === 270) {
                    drawCircle(dark)
                    drawHalf(light, Math.PI / 2, Math.PI * 1.5)
                } else {
                    drawCircle(light)
                    drawHalf(dark, -Math.PI / 2, Math.PI / 2)
                    drawScaledHemisphere(dark, Math.cos((360 - angle) * Math.PI / 180), Math.PI / 2, Math.PI * 1.5)
                }

                ctx.beginPath()
                ctx.strokeStyle = stroke
                ctx.lineWidth = 1
                ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
                ctx.stroke()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.phaseText(root.phaseAngle)
            color: Appearance.colors.colOnWeatherCardSurfaceVariant
            font.family: "LXGW WenKai GB Screen"
            font.pixelSize: 11
        }
    }
}
