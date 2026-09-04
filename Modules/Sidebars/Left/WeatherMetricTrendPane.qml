import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property var sourceModel
    property string metric: "uv"
    property bool daily: false
    property int maxItems: daily ? 16 : 25
    property real itemWidth: width > 0 ? width / 6 : 122
    property var items: []
    property real primaryMin: 0
    property real primaryMax: 1
    property real secondaryMin: 0
    property real secondaryMax: 1
    property bool initialPositionApplied: false
    property color primaryColor: Appearance.colors.colPrimary
    property color secondaryColor: Appearance.colors.colSecondary
    readonly property bool barChart: metric === "precipitation" || metric === "sunshine" || metric === "cloud"
    readonly property bool percentScale: metric === "humidity" || metric === "cloud"
    readonly property real chartTop: daily ? 84 : 72
    readonly property real chartBottom: height - 22
    readonly property real contentWidth: Math.max(width, items.length * itemWidth)

    function validNumber(value) {
        return value !== undefined && value !== null && !isNaN(value);
    }

    function numberAt(map, key, fallback) {
        const value = map ? map[key] : undefined;
        return root.validNumber(value) ? Number(value) : fallback;
    }

    function dayLabel(index, epoch) {
        if (index === 0)
            return qsTr("昨天");

        if (index === 1)
            return qsTr("今天");

        if (index === 2)
            return qsTr("明天");

        if (!epoch)
            return "--";

        const week = [qsTr("周日"), qsTr("周一"), qsTr("周二"), qsTr("周三"), qsTr("周四"), qsTr("周五"), qsTr("周六")];
        return week[new Date(epoch * 1000).getDay()];
    }

    function timeLabel(index, epoch) {
        return daily ? root.dayLabel(index, epoch) : epoch ? UiPreferences.hourTime(new Date(epoch * 1000)) : "--";
    }

    function rounded(value, digits) {
        if (!root.validNumber(value))
            return "--";

        const factor = Math.pow(10, digits);
        const roundedValue = Math.round(value * factor) / factor;
        return digits > 0 && Math.abs(roundedValue - Math.round(roundedValue)) >= 0.05 ? roundedValue.toFixed(digits) : Math.round(roundedValue).toString();
    }

    function formatTemperature(value) {
        return root.validNumber(value) ? Math.round(UiPreferences.weatherTemperature(value)) + "°" : "--";
    }

    function formatPrimary(value) {
        if (metric === "feels")
            return root.formatTemperature(value);

        if (metric === "precipitation")
            return root.rounded(value, 1) + " mm";

        if (metric === "sunshine")
            return root.rounded(value, 1) + " h";

        if (metric === "humidity" || metric === "cloud")
            return root.rounded(value, 0) + "%";

        if (metric === "pressure")
            return root.rounded(value, 0) + " hPa";

        if (metric === "visibility")
            return root.rounded(value, 1) + " km";

        return root.rounded(value, 1);
    }

    function formatSecondary(value) {
        return root.formatTemperature(value);
    }

    function metricValues(item) {
        const day = item.day || ({
        });
        const night = item.night || ({
        });
        if (metric === "uv")
            return [root.numberAt(item, daily ? "uvIndexMax" : "uvIndex", NaN), NaN];

        if (metric === "precipitation") {
            const value = daily ? root.numberAt(day, "precipitationMm", 0) + root.numberAt(night, "precipitationMm", 0) : root.numberAt(item, "precipitationMm", NaN);
            return [value, NaN];
        }
        if (metric === "sunshine")
            return [root.numberAt(item, "sunshineDurationS", NaN) / 3600, NaN];

        if (metric === "feels")
            return daily ? [root.numberAt(item, "apparentTemperatureMaxC", NaN), root.numberAt(item, "apparentTemperatureMinC", NaN)] : [root.numberAt(item, "feelsLikeC", NaN), NaN];

        if (metric === "humidity")
            return [root.numberAt(item, "relativeHumidity", NaN), root.numberAt(item, "dewPointC", NaN)];

        if (metric === "pressure")
            return [root.numberAt(item, "pressureHpa", NaN), NaN];

        if (metric === "cloud")
            return [root.numberAt(item, "cloudCover", NaN), NaN];

        if (metric === "visibility")
            return [root.numberAt(item, "visibilityM", NaN) / 1000, NaN];

        return [NaN, NaN];
    }

    function paddedRange(minimum, maximum, zeroBased) {
        if (!root.validNumber(minimum) || !root.validNumber(maximum))
            return [0, 1];

        if (zeroBased)
            return [0, Math.max(1, maximum * 1.12)];

        if (Math.abs(maximum - minimum) < 0.1)
            return [minimum - 1, maximum + 1];

        const padding = (maximum - minimum) * 0.16;
        return [minimum - padding, maximum + padding];
    }

    function rebuild() {
        const list = [];
        let pMin = Infinity;
        let pMax = -Infinity;
        let sMin = Infinity;
        let sMax = -Infinity;
        const modelCount = sourceModel ? (typeof sourceModel.count === "function" ? sourceModel.count() : Number(sourceModel.count || 0)) : 0;
        const count = Math.min(maxItems, modelCount);
        for (let i = 0; i < count; ++i) {
            const source = sourceModel.get(i) || ({
            });
            const values = root.metricValues(source);
            if (root.validNumber(values[0])) {
                pMin = Math.min(pMin, values[0]);
                pMax = Math.max(pMax, values[0]);
            }
            if (root.validNumber(values[1])) {
                sMin = Math.min(sMin, values[1]);
                sMax = Math.max(sMax, values[1]);
            }
            list.push({
                "time": source.time || 0,
                "timeText": root.timeLabel(i, source.time || 0),
                "dateText": daily && source.time ? Qt.formatDateTime(new Date(source.time * 1000), "M/d") : "",
                "primary": values[0],
                "secondary": values[1],
                "primaryText": root.formatPrimary(values[0]),
                "secondaryText": root.formatSecondary(values[1])
            });
        }
        items = list;
        const fixedPercent = root.percentScale ? [0, 100] : root.paddedRange(pMin, pMax, root.barChart || metric === "uv");
        primaryMin = fixedPercent[0];
        primaryMax = fixedPercent[1];
        const secondaryRange = root.paddedRange(sMin, sMax, false);
        secondaryMin = secondaryRange[0];
        secondaryMax = secondaryRange[1];
        chartCanvas.requestPaint();
    }

    function yFor(value, minimum, maximum) {
        if (!root.validNumber(value) || maximum <= minimum)
            return chartBottom;

        return chartBottom - (value - minimum) / (maximum - minimum) * (chartBottom - chartTop);
    }

    function applyInitialPosition() {
        if (!root.daily || root.initialPositionApplied)
            return ;

        trendFlick.contentX = Math.min(root.itemWidth, Math.max(0, trendFlick.contentWidth - trendFlick.width));
        root.initialPositionApplied = true;
    }

    clip: true
    onSourceModelChanged: rebuild()
    onMetricChanged: rebuild()
    onDailyChanged: rebuild()
    onWidthChanged: chartCanvas.requestPaint()
    onHeightChanged: chartCanvas.requestPaint()
    onPrimaryColorChanged: chartCanvas.requestPaint()
    onSecondaryColorChanged: chartCanvas.requestPaint()
    Component.onCompleted: rebuild()

    Timer {
        id: initialPositionTimer

        interval: 0
        repeat: false
        onTriggered: root.applyInitialPosition()
    }

    Connections {
        function onModelReset() {
            root.rebuild();
        }

        function onRowsInserted() {
            root.rebuild();
        }

        function onRowsRemoved() {
            root.rebuild();
        }

        function onDataChanged() {
            root.rebuild();
        }

        target: root.sourceModel
        ignoreUnknownSignals: true
    }

    Connections {
        function onWeatherTemperatureUnitChanged() {
            root.rebuild();
        }

        function onUseTwelveHourClockChanged() {
            root.rebuild();
        }

        target: UiPreferences
    }

    StyledFlickable {
        id: trendFlick

        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        showVerticalScrollBar: false
        contentWidth: root.contentWidth
        contentHeight: height
        Component.onCompleted: initialPositionTimer.restart()
        onContentWidthChanged: initialPositionTimer.restart()
        onWidthChanged: initialPositionTimer.restart()

        Item {
            width: trendFlick.contentWidth
            height: trendFlick.height

            Canvas {
                id: chartCanvas

                function pointX(index) {
                    return index * root.itemWidth + root.itemWidth / 2;
                }

                function drawLine(ctx, key, minimum, maximum, color) {
                    let started = false;
                    ctx.strokeStyle = color;
                    ctx.lineWidth = 3;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    for (let i = 0; i < root.items.length; ++i) {
                        const value = root.items[i][key];
                        if (!root.validNumber(value)) {
                            started = false;
                            continue;
                        }
                        const x = pointX(i);
                        const y = root.yFor(value, minimum, maximum);
                        if (!started)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                        started = true;
                    }
                    ctx.stroke();
                    for (let j = 0; j < root.items.length; ++j) {
                        const pointValue = root.items[j][key];
                        if (!root.validNumber(pointValue))
                            continue;

                        ctx.fillStyle = color;
                        ctx.beginPath();
                        ctx.arc(pointX(j), root.yFor(pointValue, minimum, maximum), 4, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (root.items.length === 0)
                        return ;

                    if (root.barChart) {
                        const barWidth = Math.max(9, Math.min(18, root.itemWidth * 0.22));
                        for (let i = 0; i < root.items.length; ++i) {
                            const value = root.items[i].primary;
                            if (!root.validNumber(value))
                                continue;

                            const top = root.yFor(value, root.primaryMin, root.primaryMax);
                            ctx.fillStyle = i === 0 && root.daily ? Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.34) : root.primaryColor;
                            ctx.beginPath();
                            ctx.roundedRect(pointX(i) - barWidth / 2, top, barWidth, Math.max(2, root.chartBottom - top), barWidth / 2, barWidth / 2);
                            ctx.fill();
                        }
                    } else {
                        drawLine(ctx, "primary", root.primaryMin, root.primaryMax, root.primaryColor);
                    }
                    if (root.items.some(function(item) {
                        return root.validNumber(item.secondary);
                    }))
                        drawLine(ctx, "secondary", root.secondaryMin, root.secondaryMax, root.secondaryColor);

                }
            }

            Repeater {
                model: root.items

                delegate: Item {
                    required property var modelData
                    required property int index

                    x: index * root.itemWidth
                    width: root.itemWidth
                    height: parent.height
                    opacity: root.daily && index === 0 ? 0.48 : 1

                    Text {
                        width: parent.width
                        y: 6
                        text: modelData.timeText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: root.daily ? Fonts.ui : Fonts.numeric
                        font.pixelSize: 12
                        font.bold: root.daily && index === 1
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: root.daily
                        width: parent.width
                        y: 23
                        text: modelData.dateText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.numeric
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        width: parent.width
                        y: root.daily ? 43 : 27
                        text: root.validNumber(modelData.secondary) ? modelData.primaryText + " · " + modelData.secondaryText : modelData.primaryText
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.numeric
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                }

            }

        }

    }

}
