import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Widgets.weather
import "WeatherChartMath.js" as WeatherChartMath

Rectangle {
    id: root

    property var sourceModel
    property var normalsSource
    property real itemWidth: trendFlick.width > 0 ? trendFlick.width / 6 : 122
    property int maxItems: 16
    property int currentTab: 0
    property bool foreground: false
    property var displayTemperatureDomain: [0, 1]
    readonly property int normalMonth: new Date().getMonth() + 1
    readonly property real normalDaytimeC: normalTemperature(true)
    readonly property real normalNighttimeC: normalTemperature(false)

    function modelCount() {
        if (!sourceModel)
            return 0;

        const count = typeof sourceModel.count === "function" ? sourceModel.count() : Number(sourceModel.count || 0);
        return Math.min(maxItems, count);
    }

    function itemAt(index) {
        return sourceModel && sourceModel.get ? sourceModel.get(index) : ({
        });
    }

    function valueAt(map, key, fallback) {
        const v = map ? map[key] : undefined;
        return (v === undefined || v === null || isNaN(v)) ? fallback : Number(v);
    }

    function fmtTemp(value) {
        return value !== undefined && value !== null && !isNaN(value) ? Math.round(UiPreferences.weatherTemperature(value)) + "°" : "--";
    }

    function fmtPercent(value) {
        return value !== undefined && value !== null && !isNaN(value) ? Math.round(value) + "%" : "--";
    }

    function normalTemperature(daytime) {
        const source = root.normalsSource;
        if (!source || !source.normalsAvailable)
            return NaN;

        const value = daytime ? source.normalDaytimeTemperatureC(root.normalMonth) : source.normalNighttimeTemperatureC(root.normalMonth);
        return root.valueAt({
            "value": value
        }, "value", NaN);
    }

    function forecastTemperatures() {
        const values = [];
        const count = root.modelCount();
        for (let i = 0; i < count; ++i) {
            const item = root.itemAt(i);
            const day = item.day || ({
            });
            const night = item.night || ({
            });
            const dayTemp = root.valueAt(day, "temperatureC", root.valueAt(item, "temperatureMaxC", NaN));
            const nightTemp = root.valueAt(night, "temperatureC", root.valueAt(item, "temperatureMinC", NaN));
            if (!isNaN(dayTemp))
                values.push(dayTemp);

            if (!isNaN(nightTemp))
                values.push(nightTemp);

        }
        return values;
    }

    function updateTemperatureDomain() {
        root.displayTemperatureDomain = WeatherChartMath.temperatureDomain(root.forecastTemperatures(), root.normalDaytimeC, root.normalNighttimeC);
        trendCanvas.requestPaint();
    }

    function extraTabLabel() {
        const labels = [qsTr("紫外线指数"), qsTr("降水量"), qsTr("日照"), qsTr("体感温度")];
        return currentTab >= 3 && currentTab < 7 ? labels[currentTab - 3] : "";
    }

    function applyInitialPosition() {
        if (trendFlick.initialPositionApplied)
            return ;

        const count = root.modelCount();
        if (count < 2) {
            trendFlick.contentX = 0;
            trendFlick.initialPositionApplied = true;
            return ;
        }
        const maxX = Math.max(0, trendFlick.contentWidth - trendFlick.width);
        if (maxX <= 0) {
            trendFlick.contentX = 0;
            trendFlick.initialPositionApplied = true;
            return ;
        }
        trendFlick.contentX = Math.min(root.itemWidth, maxX);
        trendFlick.initialPositionApplied = true;
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

    function dateLabel(epoch) {
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "M/d") : "--";
    }

    radius: 26
    color: Appearance.colors.colWeatherCardSurface
    border.width: 1
    border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.42)
    clip: true
    onSourceModelChanged: {
        trendFlick.initialPositionApplied = false;
        initialPositionTimer.restart();
        updateTemperatureDomain();
    }
    onCurrentTabChanged: {
        if (root.currentTab === 0)
            trendCanvas.requestPaint();

    }
    onForegroundChanged: {
        if (root.foreground)
            trendCanvas.requestPaint();

    }
    onWidthChanged: trendCanvas.requestPaint()
    onHeightChanged: trendCanvas.requestPaint()
    Component.onCompleted: updateTemperatureDomain()

    Connections {
        function onWeatherTemperatureUnitChanged() {
            trendCanvas.requestPaint();
        }

        target: UiPreferences
    }

    Connections {
        function onNormalsChanged() {
            root.updateTemperatureDomain();
        }

        target: root.normalsSource
        ignoreUnknownSignals: true
    }

    Timer {
        id: initialPositionTimer

        interval: 0
        repeat: false
        onTriggered: applyInitialPosition()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 16
            Layout.preferredHeight: 82
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "calendar_month"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.materialSymbolsOutlined
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: qsTr("每日预报")
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.bold: true
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledButtonGroup {
                    currentValue: root.currentTab
                    model: [({
                        "value": 0,
                        "label": qsTr("天气情况")
                    }), ({
                        "value": 1,
                        "label": qsTr("空气质量")
                    }), ({
                        "value": 2,
                        "label": qsTr("风况")
                    })]
                    onValueSelected: (value) => {
                        return root.currentTab = value;
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.currentTab >= 3
                    text: root.extraTabLabel()
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.ui
                    font.pixelSize: 13
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    controlSize: 36
                    iconName: "more_horiz"
                    iconSize: 20
                    iconColor: Appearance.colors.colOnSurfaceVariant
                    selected: root.currentTab >= 3
                    selectedIconColor: Appearance.colors.colOnPrimaryContainer
                    accessibleName: qsTr("每日预报更多选项")
                    normalContainerColor: Appearance.colors.colLayer2
                    selectedContainerColor: Appearance.colors.colPrimaryContainer
                    hoverStateLayerColor: Appearance.colors.colLayer4
                    pressedStateLayerColor: Appearance.colors.colLayer4Active
                    onClicked: extraMenu.open()

                    Menu {
                        id: extraMenu

                        MenuItem {
                            text: qsTr("紫外线指数")
                            checkable: true
                            checked: root.currentTab === 3
                            onTriggered: root.currentTab = 3
                        }

                        MenuItem {
                            text: qsTr("降水量")
                            checkable: true
                            checked: root.currentTab === 4
                            onTriggered: root.currentTab = 4
                        }

                        MenuItem {
                            text: qsTr("日照")
                            checkable: true
                            checked: root.currentTab === 5
                            onTriggered: root.currentTab = 5
                        }

                        MenuItem {
                            text: qsTr("体感温度")
                            checkable: true
                            checked: root.currentTab === 6
                            onTriggered: root.currentTab = 6
                        }

                    }

                }

            }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledFlickable {
                id: trendFlick

                property bool initialPositionApplied: false

                anchors.fill: parent
                clip: true
                interactive: root.currentTab === 0
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                showVerticalScrollBar: false
                contentWidth: Math.max(width, root.modelCount() * root.itemWidth)
                contentHeight: height
                visible: root.currentTab === 0
                Component.onCompleted: initialPositionTimer.restart()
                onContentWidthChanged: initialPositionTimer.restart()
                onWidthChanged: initialPositionTimer.restart()
                onVisibleChanged: {
                    if (visible)
                        initialPositionTimer.restart();

                }

                Item {
                    id: trendContent

                    property real columnWidth: root.itemWidth
                    property real topTextY: 8
                    property real topLabelSpacing: 3
                    property real dayIconSize: Math.max(46, Math.min(60, columnWidth * 0.46))
                    property real dayIconY: 56
                    property real chartTopInset: 166
                    property real chartBottomInset: Math.max(chartTopInset + 72, height - 126)
                    property real rainLabelY: chartBottomInset + 18
                    property real nightIconSize: dayIconSize
                    property real nightIconY: height - nightIconSize - 12
                    property real highTempTextY: 102
                    property real lowTempTextY: nightIconY - 30

                    width: trendFlick.contentWidth
                    height: trendFlick.height

                    Canvas {
                        id: trendCanvas

                        property color primaryColor: Appearance.colors.colPrimary
                        property color secondaryColor: Appearance.colors.colSecondary
                        property real chartTop: trendContent.chartTopInset
                        property real chartBottom: trendContent.chartBottomInset

                        function pointX(index) {
                            return root.itemWidth * index + root.itemWidth / 2;
                        }

                        function yAt(value, minValue, maxValue) {
                            return chartBottom - (value - minValue) / (maxValue - minValue) * (chartBottom - chartTop);
                        }

                        function drawSeries(ctx, values, minValue, maxValue, color, lineWidth) {
                            for (let i = 1; i < values.length; ++i) {
                                const prevX = pointX(i - 1);
                                const prevY = yAt(values[i - 1], minValue, maxValue);
                                const x = pointX(i);
                                const y = yAt(values[i], minValue, maxValue);
                                const faded = i - 1 === 0 || i === 0;
                                ctx.save();
                                if (ctx.setLineDash && i === 1)
                                    ctx.setLineDash([4, 3]);

                                ctx.strokeStyle = withAlpha(color, faded ? 0.26 : 1);
                                ctx.lineWidth = lineWidth;
                                ctx.lineJoin = "round";
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                ctx.moveTo(prevX, prevY);
                                ctx.lineTo(x, y);
                                ctx.stroke();
                                ctx.restore();
                            }
                        }

                        function withAlpha(color, factor) {
                            return Qt.rgba(color.r, color.g, color.b, color.a * factor);
                        }

                        function roundedRect(ctx, x, y, w, h, r) {
                            ctx.moveTo(x + r, y);
                            ctx.lineTo(x + w - r, y);
                            ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                            ctx.lineTo(x + w, y + h - r);
                            ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                            ctx.lineTo(x + r, y + h);
                            ctx.quadraticCurveTo(x, y + h, x, y + h - r);
                            ctx.lineTo(x, y + r);
                            ctx.quadraticCurveTo(x, y, x + r, y);
                        }

                        anchors.fill: parent
                        antialiasing: true
                        onPrimaryColorChanged: requestPaint()
                        onSecondaryColorChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const count = root.modelCount();
                            if (count < 2)
                                return ;

                            let dayValues = [];
                            let nightValues = [];
                            let precipitationValues = [];
                            for (let i = 0; i < count; ++i) {
                                const item = root.itemAt(i);
                                const day = item.day || ({
                                });
                                const night = item.night || ({
                                });
                                const dayTemp = root.valueAt(day, "temperatureC", root.valueAt(item, "temperatureMaxC", NaN));
                                const nightTemp = root.valueAt(night, "temperatureC", root.valueAt(item, "temperatureMinC", NaN));
                                const pop = Math.max(root.valueAt(day, "precipitationProbability", 0), root.valueAt(night, "precipitationProbability", 0));
                                dayValues.push(dayTemp);
                                nightValues.push(nightTemp);
                                precipitationValues.push(pop);
                            }
                            if (root.forecastTemperatures().length === 0)
                                return ;

                            const domain = root.displayTemperatureDomain;
                            const minTemp = domain[0];
                            const maxTemp = domain[1];
                            ctx.beginPath();
                            for (let f = 0; f < count; ++f) {
                                const xFill = pointX(f);
                                const yFill = yAt(dayValues[f], minTemp, maxTemp);
                                if (f === 0)
                                    ctx.moveTo(xFill, yFill);
                                else
                                    ctx.lineTo(xFill, yFill);
                            }
                            for (let r = count - 1; r >= 0; --r) {
                                ctx.lineTo(pointX(r), yAt(nightValues[r], minTemp, maxTemp));
                            }
                            ctx.closePath();
                            const fillGradient = ctx.createLinearGradient(0, chartTop, 0, chartBottom);
                            fillGradient.addColorStop(0, "rgba(" + Math.round(primaryColor.r * 255) + "," + Math.round(primaryColor.g * 255) + "," + Math.round(primaryColor.b * 255) + ",0.12)");
                            fillGradient.addColorStop(1, "rgba(" + Math.round(primaryColor.r * 255) + "," + Math.round(primaryColor.g * 255) + "," + Math.round(primaryColor.b * 255) + ",0.02)");
                            ctx.fillStyle = fillGradient;
                            ctx.fill();
                            for (let p = 0; p < count; ++p) {
                                const popValue = precipitationValues[p];
                                if (popValue <= 0)
                                    continue;

                                const x = pointX(p);
                                const fadedBar = p === 0;
                                const barTop = chartBottom - (chartBottom - chartTop) * Math.min(100, popValue) / 100;
                                ctx.fillStyle = fadedBar ? Qt.rgba(secondaryColor.r, secondaryColor.g, secondaryColor.b, 0.1) : Qt.rgba(secondaryColor.r, secondaryColor.g, secondaryColor.b, 0.18);
                                ctx.beginPath();
                                roundedRect(ctx, x - 5, barTop, 10, chartBottom - barTop, 5);
                                ctx.fill();
                                ctx.fillStyle = fadedBar ? Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.42) : primaryColor;
                                ctx.font = "bold 11px " + Fonts.cssFamily(Fonts.numeric);
                                ctx.textAlign = "center";
                                ctx.fillText(root.fmtPercent(popValue), x, trendContent.rainLabelY);
                            }
                            drawSeries(ctx, dayValues, minTemp, maxTemp, primaryColor, 4);
                            drawSeries(ctx, nightValues, minTemp, maxTemp, secondaryColor, 4);
                        }
                    }

                    Repeater {
                        model: root.modelCount()

                        delegate: Item {
                            property var dayItem: root.itemAt(index)
                            property var dayPart: dayItem.day || ({
                            })
                            property var nightPart: dayItem.night || ({
                            })

                            x: root.itemWidth * index
                            width: root.itemWidth
                            height: trendContent.height
                            opacity: index === 0 ? 0.45 : 1

                            Rectangle {
                                anchors.fill: parent
                                radius: 26
                                color: "transparent"
                                border.width: 0
                            }

                            Column {
                                y: trendContent.topTextY
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                spacing: trendContent.topLabelSpacing

                                Text {
                                    width: parent.width
                                    text: root.dayLabel(index, dayItem.time)
                                    color: Appearance.colors.colOnSurface
                                    font.family: Fonts.ui
                                    font.pixelSize: 16
                                    font.bold: index === 1
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: root.dateLabel(dayItem.time)
                                    color: Appearance.colors.colOnSurfaceVariant
                                    font.family: Fonts.numeric
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                }

                            }

                            MeteoIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: trendContent.dayIconY
                                width: trendContent.dayIconSize
                                height: trendContent.dayIconSize
                                weatherCode: root.valueAt(dayPart, "weatherCode", -1)
                                iconName: dayPart.iconName || ""
                                night: false
                                style: "fill"
                                animated: false
                            }

                            Text {
                                width: parent.width
                                y: trendContent.highTempTextY
                                text: root.fmtTemp(root.valueAt(dayPart, "temperatureC", root.valueAt(dayItem, "temperatureMaxC", NaN)))
                                color: Appearance.colors.colOnSurface
                                font.family: Fonts.numeric
                                font.pixelSize: 19
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                width: parent.width
                                y: trendContent.lowTempTextY
                                text: root.fmtTemp(root.valueAt(nightPart, "temperatureC", root.valueAt(dayItem, "temperatureMinC", NaN)))
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Fonts.numeric
                                font.pixelSize: 18
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MeteoIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: trendContent.nightIconY
                                width: trendContent.nightIconSize
                                height: trendContent.nightIconSize
                                weatherCode: root.valueAt(nightPart, "weatherCode", -1)
                                iconName: nightPart.iconName || ""
                                night: true
                                style: "fill"
                                animated: false
                            }

                        }

                    }

                    MouseArea {
                        id: dragArea

                        property real lastMouseX: 0

                        x: trendFlick.contentX
                        y: 0
                        z: 20
                        width: trendFlick.width
                        height: trendFlick.height
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: function(mouse) {
                            lastMouseX = mouse.x;
                        }
                        onPositionChanged: function(mouse) {
                            if (!pressed)
                                return ;

                            const dx = mouse.x - lastMouseX;
                            const maxX = Math.max(0, trendFlick.contentWidth - trendFlick.width);
                            trendFlick.contentX = Math.max(0, Math.min(maxX, trendFlick.contentX - dx));
                            lastMouseX = mouse.x;
                        }
                    }

                }

            }

            WeatherTemperatureNormalLine {
                z: 10
                visible: root.currentTab === 0 && !isNaN(root.normalDaytimeC)
                width: parent.width
                temperatureC: root.normalDaytimeC
                domainMinimumC: root.displayTemperatureDomain[0]
                domainMaximumC: root.displayTemperatureDomain[1]
                chartTop: trendContent.chartTopInset
                chartBottom: trendContent.chartBottomInset
                temperatureText: root.fmtTemp(root.normalDaytimeC)
                numericFontFamily: Fonts.numeric
                uiFontFamily: Fonts.ui
                lineColor: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.58)
                labelColor: Appearance.colors.colOnSurfaceVariant
            }

            WeatherTemperatureNormalLine {
                z: 10
                visible: root.currentTab === 0 && !isNaN(root.normalNighttimeC)
                width: parent.width
                temperatureC: root.normalNighttimeC
                domainMinimumC: root.displayTemperatureDomain[0]
                domainMaximumC: root.displayTemperatureDomain[1]
                chartTop: trendContent.chartTopInset
                chartBottom: trendContent.chartBottomInset
                temperatureText: root.fmtTemp(root.normalNighttimeC)
                numericFontFamily: Fonts.numeric
                uiFontFamily: Fonts.ui
                lineColor: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.58)
                labelColor: Appearance.colors.colOnSurfaceVariant
            }

            Item {
                anchors.fill: parent
                visible: root.currentTab === 1

                DailyAirQualityTrendPane {
                    anchors.fill: parent
                    sourceModel: root.sourceModel
                }

            }

            Item {
                anchors.fill: parent
                visible: root.currentTab === 2

                DailyWindTrendPane {
                    anchors.fill: parent
                    sourceModel: root.sourceModel
                }

            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 3
                sourceModel: root.sourceModel
                daily: true
                metric: "uv"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 4
                sourceModel: root.sourceModel
                daily: true
                metric: "precipitation"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 5
                sourceModel: root.sourceModel
                daily: true
                metric: "sunshine"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 6
                sourceModel: root.sourceModel
                daily: true
                metric: "feels"
            }

        }

    }

    Connections {
        function onModelReset() {
            trendFlick.initialPositionApplied = false;
            initialPositionTimer.restart();
            root.updateTemperatureDomain();
        }

        function onDataChanged() {
            root.updateTemperatureDomain();
        }

        function onRowsInserted() {
            trendFlick.initialPositionApplied = false;
            initialPositionTimer.restart();
            root.updateTemperatureDomain();
        }

        function onRowsRemoved() {
            root.updateTemperatureDomain();
        }

        target: root.sourceModel
        ignoreUnknownSignals: true
    }

    Connections {
        function onNumericChanged() {
            trendCanvas.requestPaint();
        }

        target: Fonts
    }

}
