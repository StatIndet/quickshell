import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Widgets.weather

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
    property color outlineColor: Appearance.colors.colOutlineVariant
    property color labelColor: Appearance.colors.colOnSurfaceVariant
    readonly property bool pureBarChart: metric === "uv" || metric === "sunshine" || metric === "cloud" || metric === "precipitation"
    readonly property bool doublePrecipitation: daily && metric === "precipitation"
    readonly property bool hasHistogram: metric === "humidity" || metric === "feels"
    readonly property bool showHourlyIcon: !daily && (metric === "precipitation" || metric === "feels" || metric === "humidity" || metric === "pressure" || metric === "visibility")
    readonly property bool showDailyIcons: daily && (metric === "precipitation" || metric === "feels")
    readonly property real chartTop: daily ? showDailyIcons ? 116 : 72 : showHourlyIcon ? 76 : 48
    readonly property real chartBottom: daily ? showDailyIcons ? height - 94 : height - 40 : height - 32
    readonly property real precipitationMiddle: (chartTop + chartBottom) / 2
    readonly property real contentWidth: Math.max(width, items.length * itemWidth)
    readonly property bool keyLineVisible: metric === "pressure" || metric === "uv"
    readonly property real keyLineValue: metric === "pressure" ? 1013.25 : 6
    readonly property string keyLineValueText: metric === "pressure" ? "1,013" : "6"
    readonly property string keyLineLabel: metric === "pressure" ? qsTr("标准") : qsTr("预警水平")

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

    function formatValue(value) {
        if (metric === "feels" || metric === "humidity")
            return root.formatTemperature(value);

        if (metric === "precipitation")
            return root.rounded(value, 1);

        if (metric === "sunshine")
            return root.rounded(value, 1) + " h";

        if (metric === "cloud")
            return root.rounded(value, 0) + "%";

        if (metric === "pressure")
            return root.rounded(value, 0);

        if (metric === "visibility")
            return root.rounded(value, 1) + " km";

        return root.rounded(value, 0);
    }

    function levelColor(value, kind) {
        if (!root.validNumber(value))
            return "transparent";

        if (kind === "sunshine")
            return "#fdbc4c";

        if (kind === "cloud") {
            if (value < 37.5)
                return "#72d572";

            if (value <= 62.5)
                return "#ffca28";

            return "#ffa726";
        }
        let limits = kind === "uv" ? [3, 6, 8, 11] : daily ? [7.75, 32.25, 57.75, 102.25] : [5, 10, 15, 20];
        const colors = ["#72d572", "#ffca28", "#ffa726", "#e52f35", "#99004c"];
        for (let i = 0; i < limits.length; ++i) {
            if (value < limits[i])
                return colors[i];

        }
        return colors[colors.length - 1];
    }

    function metricValues(item) {
        const day = item.day || ({
        });
        const night = item.night || ({
        });
        if (metric === "uv")
            return [root.numberAt(item, daily ? "uvIndexMax" : "uvIndex", NaN), NaN, NaN];

        if (metric === "precipitation")
            return daily ? [root.numberAt(day, "precipitationMm", NaN), root.numberAt(night, "precipitationMm", NaN), NaN] : [root.numberAt(item, "precipitationMm", NaN), NaN, NaN];

        if (metric === "sunshine")
            return [root.numberAt(item, "sunshineDurationS", NaN) / 3600, NaN, NaN];

        if (metric === "feels") {
            if (daily) {
                const probability = Math.max(root.numberAt(day, "precipitationProbability", 0), root.numberAt(night, "precipitationProbability", 0));
                return [root.numberAt(item, "apparentTemperatureMaxC", NaN), root.numberAt(item, "apparentTemperatureMinC", NaN), probability];
            }
            return [root.numberAt(item, "feelsLikeC", NaN), NaN, root.numberAt(item, "precipitationProbability", NaN)];
        }
        if (metric === "humidity")
            return [root.numberAt(item, "dewPointC", NaN), NaN, root.numberAt(item, "relativeHumidity", NaN)];

        if (metric === "pressure")
            return [root.numberAt(item, "pressureHpa", NaN), NaN, NaN];

        if (metric === "cloud")
            return [root.numberAt(item, "cloudCover", NaN), NaN, NaN];

        if (metric === "visibility")
            return [root.numberAt(item, "visibilityM", NaN) / 1000, NaN, NaN];

        return [NaN, NaN, NaN];
    }

    function paddedRange(minimum, maximum, zeroBased) {
        if (!root.validNumber(minimum) || !root.validNumber(maximum))
            return [0, 1];

        if (zeroBased)
            return [0, Math.max(1, maximum * 1.12)];

        if (Math.abs(maximum - minimum) < 0.1)
            return [minimum - 1, maximum + 1];

        const padding = (maximum - minimum) * 0.2;
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
            const dayPart = source.day || ({
            });
            const nightPart = source.night || ({
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
                "dateText": daily && source.time ? Qt.formatDateTime(new Date(source.time * 1000), "MM/dd") : "",
                "primary": values[0],
                "secondary": values[1],
                "histogram": values[2],
                "primaryText": root.formatValue(values[0]),
                "secondaryText": root.formatValue(values[1]),
                "histogramText": root.validNumber(values[2]) ? root.rounded(values[2], 0) + "%" : "--",
                "barColor": root.levelColor(values[0], metric),
                "secondaryBarColor": root.levelColor(values[1], metric),
                "weatherCode": root.numberAt(source, "weatherCode", -1),
                "iconName": source.iconName || "",
                "isDaylight": source.isDaylight === undefined ? true : !!source.isDaylight,
                "dayWeatherCode": root.numberAt(dayPart, "weatherCode", -1),
                "dayIconName": dayPart.iconName || "",
                "nightWeatherCode": root.numberAt(nightPart, "weatherCode", -1),
                "nightIconName": nightPart.iconName || ""
            });
        }
        if (metric === "pressure") {
            pMin = Math.min(pMin, root.keyLineValue);
            pMax = Math.max(pMax, root.keyLineValue);
        }
        if (metric === "uv") {
            pMin = 0;
            pMax = Math.max(8, pMax);
        }
        if (!daily && metric === "precipitation") {
            pMin = 0;
            pMax = Math.max(15, pMax);
        }
        if (daily && metric === "feels") {
            pMin = Math.min(pMin, sMin);
            pMax = Math.max(pMax, sMax);
            sMin = pMin;
            sMax = pMax;
        }
        if (root.doublePrecipitation) {
            pMin = 0;
            sMin = 0;
            pMax = Math.max(57.75, pMax, sMax);
            sMax = pMax;
        }
        items = list;
        const zeroBased = root.pureBarChart;
        const primaryRange = root.paddedRange(pMin, pMax, zeroBased);
        primaryMin = primaryRange[0];
        primaryMax = primaryRange[1];
        const secondaryRange = root.paddedRange(sMin, sMax, root.doublePrecipitation);
        secondaryMin = secondaryRange[0];
        secondaryMax = secondaryRange[1];
        chartCanvas.requestPaint();
    }

    function yFor(value, minimum, maximum) {
        if (!root.validNumber(value) || maximum <= minimum)
            return chartBottom;

        return chartBottom - (value - minimum) / (maximum - minimum) * (chartBottom - chartTop);
    }

    function lineLabelY(value, secondary) {
        const y = root.yFor(value, secondary ? secondaryMin : primaryMin, secondary ? secondaryMax : primaryMax);
        if (metric === "pressure" || metric === "visibility" || metric === "humidity")
            return Math.min(chartBottom - 17, y + 5);

        return Math.max(chartTop - 2, y - 21);
    }

    function applyInitialPosition() {
        if (!root.daily || root.initialPositionApplied || root.items.length < 2)
            return ;

        trendFlick.contentX = Math.min(root.itemWidth, Math.max(0, trendFlick.contentWidth - trendFlick.width));
        root.initialPositionApplied = true;
    }

    clip: true
    onSourceModelChanged: {
        root.initialPositionApplied = false;
        rebuild();
    }
    onMetricChanged: rebuild()
    onDailyChanged: rebuild()
    onWidthChanged: chartCanvas.requestPaint()
    onHeightChanged: chartCanvas.requestPaint()
    onPrimaryColorChanged: chartCanvas.requestPaint()
    onSecondaryColorChanged: chartCanvas.requestPaint()
    onOutlineColorChanged: chartCanvas.requestPaint()
    Component.onCompleted: rebuild()

    Timer {
        id: initialPositionTimer

        interval: 0
        repeat: false
        onTriggered: root.applyInitialPosition()
    }

    Connections {
        function onModelReset() {
            root.initialPositionApplied = false;
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

                function withAlpha(color, alpha) {
                    return Qt.rgba(color.r, color.g, color.b, alpha);
                }

                function drawGrid(ctx) {
                    ctx.strokeStyle = withAlpha(root.outlineColor, 0.22);
                    ctx.lineWidth = 1;
                    for (let i = 0; i < root.items.length; ++i) {
                        const x = pointX(i);
                        ctx.beginPath();
                        ctx.moveTo(x, root.chartTop);
                        ctx.lineTo(x, root.chartBottom);
                        ctx.stroke();
                    }
                }

                function drawAreaLine(ctx, key, minimum, maximum, color, alpha) {
                    const points = [];
                    for (let i = 0; i < root.items.length; ++i) {
                        const value = root.items[i][key];
                        if (root.validNumber(value))
                            points.push({
                            "x": pointX(i),
                            "y": root.yFor(value, minimum, maximum)
                        });

                    }
                    if (points.length === 0)
                        return ;

                    const gradient = ctx.createLinearGradient(0, root.chartTop, 0, root.chartBottom);
                    gradient.addColorStop(0, withAlpha(color, alpha));
                    gradient.addColorStop(1, withAlpha(color, 0.02));
                    ctx.fillStyle = gradient;
                    ctx.beginPath();
                    ctx.moveTo(points[0].x, root.chartBottom);
                    for (let p = 0; p < points.length; ++p) ctx.lineTo(points[p].x, points[p].y)
                    ctx.lineTo(points[points.length - 1].x, root.chartBottom);
                    ctx.closePath();
                    ctx.fill();
                    ctx.strokeStyle = color;
                    ctx.lineWidth = 3;
                    ctx.lineJoin = "round";
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    for (let j = 0; j < points.length; ++j) {
                        if (j === 0)
                            ctx.moveTo(points[j].x, points[j].y);
                        else
                            ctx.lineTo(points[j].x, points[j].y);
                    }
                    ctx.stroke();
                }

                function drawRoundedBar(ctx, x, top, bottom, width, color, alpha) {
                    const y = Math.min(top, bottom);
                    const height = Math.max(3, Math.abs(bottom - top));
                    ctx.save();
                    ctx.globalAlpha = alpha;
                    ctx.fillStyle = color;
                    ctx.beginPath();
                    ctx.roundedRect(x - width / 2, y, width, height, width / 2, width / 2);
                    ctx.fill();
                    ctx.restore();
                }

                anchors.fill: parent
                antialiasing: true
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (root.items.length === 0)
                        return ;

                    drawGrid(ctx);
                    const barWidth = Math.max(8, Math.min(14, root.itemWidth * 0.18));
                    if (root.doublePrecipitation) {
                        const middle = root.precipitationMiddle;
                        const upperBaseline = middle - 2;
                        const lowerBaseline = middle + 2;
                        const upperExtent = upperBaseline - (root.chartTop + 24);
                        const lowerExtent = root.chartBottom - 24 - lowerBaseline;
                        for (let d = 0; d < root.items.length; ++d) {
                            const dayValue = root.items[d].primary;
                            const nightValue = root.items[d].secondary;
                            if (root.validNumber(dayValue) && dayValue > 0) {
                                const dayHeight = dayValue / Math.max(1, root.primaryMax) * upperExtent;
                                drawRoundedBar(ctx, pointX(d), upperBaseline - dayHeight, upperBaseline, barWidth, root.items[d].barColor, 1);
                            }
                            if (root.validNumber(nightValue) && nightValue > 0) {
                                const nightHeight = nightValue / Math.max(1, root.secondaryMax) * lowerExtent;
                                drawRoundedBar(ctx, pointX(d), lowerBaseline, lowerBaseline + nightHeight, barWidth, root.items[d].secondaryBarColor, 0.5);
                            }
                        }
                    } else if (root.pureBarChart) {
                        for (let b = 0; b < root.items.length; ++b) {
                            const barValue = root.items[b].primary;
                            if (root.validNumber(barValue))
                                drawRoundedBar(ctx, pointX(b), root.yFor(barValue, root.primaryMin, root.primaryMax), root.chartBottom, barWidth, root.items[b].barColor, 1);

                        }
                    } else {
                        if (root.hasHistogram) {
                            for (let h = 0; h < root.items.length; ++h) {
                                const histogramValue = root.items[h].histogram;
                                if (!root.validNumber(histogramValue))
                                    continue;

                                const histogramTop = root.chartBottom - Math.max(3, histogramValue / 100 * (root.chartBottom - root.chartTop) * 0.72);
                                drawRoundedBar(ctx, pointX(h), histogramTop, root.chartBottom, barWidth, "#64b5f6", 0.5);
                            }
                        }
                        drawAreaLine(ctx, "primary", root.primaryMin, root.primaryMax, root.primaryColor, 0.23);
                        if (root.items.some(function(item) {
                            return root.validNumber(item.secondary);
                        }))
                            drawAreaLine(ctx, "secondary", root.secondaryMin, root.secondaryMax, root.secondaryColor, 0.12);

                    }
                }
            }

            Repeater {
                model: root.items

                delegate: Item {
                    id: metricColumn

                    required property var modelData
                    required property int index

                    x: index * root.itemWidth
                    width: root.itemWidth
                    height: parent.height
                    opacity: root.daily && index === 0 ? 0.48 : 1

                    Text {
                        width: parent.width
                        y: 4
                        text: metricColumn.modelData.timeText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: root.daily ? Fonts.ui : Fonts.numeric
                        font.pixelSize: 12
                        font.bold: root.daily && metricColumn.index === 1
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: root.daily
                        width: parent.width
                        y: 22
                        text: metricColumn.modelData.dateText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.numeric
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MeteoIcon {
                        visible: root.showHourlyIcon
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 27
                        width: 40
                        height: 40
                        weatherCode: metricColumn.modelData.weatherCode
                        iconName: metricColumn.modelData.iconName
                        night: !metricColumn.modelData.isDaylight
                        style: "fill"
                        animated: false
                    }

                    MeteoIcon {
                        visible: root.showDailyIcons
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 48
                        width: 52
                        height: 52
                        weatherCode: metricColumn.modelData.dayWeatherCode
                        iconName: metricColumn.modelData.dayIconName
                        night: false
                        style: "fill"
                        animated: false
                    }

                    MeteoIcon {
                        visible: root.showDailyIcons
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 55
                        width: 48
                        height: 48
                        weatherCode: metricColumn.modelData.nightWeatherCode
                        iconName: metricColumn.modelData.nightIconName
                        night: true
                        style: "fill"
                        animated: false
                    }

                    Text {
                        visible: !root.pureBarChart && root.validNumber(metricColumn.modelData.primary)
                        width: parent.width
                        y: root.lineLabelY(metricColumn.modelData.primary, false)
                        text: metricColumn.modelData.primaryText
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.numeric
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: !root.pureBarChart && root.validNumber(metricColumn.modelData.secondary)
                        width: parent.width
                        y: Math.min(root.chartBottom - 15, root.yFor(metricColumn.modelData.secondary, root.secondaryMin, root.secondaryMax) + 5)
                        text: metricColumn.modelData.secondaryText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.numeric
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: root.pureBarChart && !root.doublePrecipitation
                        width: parent.width
                        y: root.chartBottom + 7
                        text: metricColumn.modelData.primaryText
                        color: Appearance.colors.colOnSurface
                        font.family: Fonts.numeric
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.doublePrecipitation && root.validNumber(metricColumn.modelData.primary) && metricColumn.modelData.primary > 0
                        width: parent.width
                        y: root.chartTop + 2
                        text: metricColumn.modelData.primaryText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.numeric
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: root.doublePrecipitation && root.validNumber(metricColumn.modelData.secondary) && metricColumn.modelData.secondary > 0
                        width: parent.width
                        y: root.chartBottom - 18
                        text: metricColumn.modelData.secondaryText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: Fonts.numeric
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        visible: root.hasHistogram
                        width: parent.width
                        y: root.chartBottom + 7
                        text: metricColumn.modelData.histogramText
                        color: "#64b5f6"
                        font.family: Fonts.numeric
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                }

            }

        }

    }

    Item {
        visible: root.keyLineVisible
        z: 20
        x: 0
        y: root.yFor(root.keyLineValue, root.primaryMin, root.primaryMax)
        width: parent.width
        height: 1

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(root.outlineColor.r, root.outlineColor.g, root.outlineColor.b, 0.5)
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            text: root.keyLineValueText
            color: root.labelColor
            font.family: Fonts.numeric
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            text: root.keyLineLabel
            color: root.labelColor
            font.family: Fonts.ui
            font.pixelSize: 11
            font.bold: true
        }

    }

}
