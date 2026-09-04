import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Widgets.weather

Rectangle {
    id: root

    property var sourceModel
    property real itemWidth: trendFlick.width > 0 ? trendFlick.width / 6 : 122
    property int maxItems: 25
    property int currentTab: 0
    property bool foreground: false

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

    function hourLabel(epoch) {
        return epoch ? UiPreferences.hourTime(new Date(epoch * 1000)) : "--";
    }

    function extraTabLabel() {
        const labels = [qsTr("紫外线指数"), qsTr("降水量"), qsTr("体感温度"), qsTr("相对湿度 / 露点"), qsTr("气压"), qsTr("云量"), qsTr("能见度")];
        return currentTab >= 3 && currentTab < 10 ? labels[currentTab - 3] : "";
    }

    radius: 26
    color: Appearance.colors.colWeatherCardSurface
    border.width: 1
    border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.42)
    clip: true
    onSourceModelChanged: trendCanvas.requestPaint()
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

    Connections {
        function onWeatherTemperatureUnitChanged() {
            trendCanvas.requestPaint();
        }

        target: UiPreferences
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
                    text: "schedule"
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.materialSymbolsOutlined
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: qsTr("逐小时预报")
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
                    accessibleName: qsTr("逐小时预报更多选项")
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
                            text: qsTr("体感温度")
                            checkable: true
                            checked: root.currentTab === 5
                            onTriggered: root.currentTab = 5
                        }

                        MenuItem {
                            text: qsTr("相对湿度 / 露点")
                            checkable: true
                            checked: root.currentTab === 6
                            onTriggered: root.currentTab = 6
                        }

                        MenuItem {
                            text: qsTr("气压")
                            checkable: true
                            checked: root.currentTab === 7
                            onTriggered: root.currentTab = 7
                        }

                        MenuItem {
                            text: qsTr("云量")
                            checkable: true
                            checked: root.currentTab === 8
                            onTriggered: root.currentTab = 8
                        }

                        MenuItem {
                            text: qsTr("能见度")
                            checkable: true
                            checked: root.currentTab === 9
                            onTriggered: root.currentTab = 9
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

                anchors.fill: parent
                clip: true
                interactive: root.currentTab === 0
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                showVerticalScrollBar: false
                contentWidth: Math.max(width, root.modelCount() * root.itemWidth)
                contentHeight: height
                visible: root.currentTab === 0

                Item {
                    id: trendContent

                    property real topTextY: 6
                    property real iconY: 28
                    property real iconSize: Math.max(46, Math.min(60, root.itemWidth * 0.46))
                    property real chartTopInset: 96
                    property real chartBottomInset: Math.max(chartTopInset + 70, height - 30)

                    width: trendFlick.contentWidth
                    height: trendFlick.height

                    Canvas {
                        id: trendCanvas

                        property color primaryColor: Appearance.colors.colPrimary
                        property color pointInnerColor: Appearance.colors.colLayer4
                        property color textColor: Appearance.colors.colOnSurface
                        property real chartTop: trendContent.chartTopInset
                        property real chartBottom: trendContent.chartBottomInset

                        function pointX(index) {
                            return root.itemWidth * index + root.itemWidth / 2;
                        }

                        function yAt(value, minValue, maxValue) {
                            return chartBottom - (value - minValue) / (maxValue - minValue) * (chartBottom - chartTop);
                        }

                        anchors.fill: parent
                        antialiasing: true
                        onPrimaryColorChanged: requestPaint()
                        onPointInnerColorChanged: requestPaint()
                        onTextColorChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const count = root.modelCount();
                            if (count < 2)
                                return ;

                            let values = [];
                            let minTemp = 999;
                            let maxTemp = -999;
                            for (let i = 0; i < count; ++i) {
                                const item = root.itemAt(i);
                                const temp = root.valueAt(item, "temperatureC", NaN);
                                values.push(temp);
                                if (!isNaN(temp)) {
                                    minTemp = Math.min(minTemp, temp);
                                    maxTemp = Math.max(maxTemp, temp);
                                }
                            }
                            if (maxTemp < minTemp)
                                return ;

                            if (Math.abs(maxTemp - minTemp) < 0.1) {
                                maxTemp += 1;
                                minTemp -= 1;
                            }
                            ctx.strokeStyle = primaryColor;
                            ctx.lineWidth = 3;
                            ctx.lineJoin = "round";
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            for (let j = 0; j < count; ++j) {
                                const x2 = pointX(j);
                                const y2 = yAt(values[j], minTemp, maxTemp);
                                if (j === 0)
                                    ctx.moveTo(x2, y2);
                                else
                                    ctx.lineTo(x2, y2);
                            }
                            ctx.stroke();
                            for (let p = 0; p < count; ++p) {
                                const px = pointX(p);
                                const py = yAt(values[p], minTemp, maxTemp);
                                ctx.fillStyle = primaryColor;
                                ctx.beginPath();
                                ctx.arc(px, py, 4.5, 0, Math.PI * 2);
                                ctx.fill();
                                ctx.fillStyle = pointInnerColor;
                                ctx.beginPath();
                                ctx.arc(px, py, 2.4, 0, Math.PI * 2);
                                ctx.fill();
                            }
                            ctx.fillStyle = textColor;
                            ctx.font = "bold 13px " + Fonts.cssFamily(Fonts.numeric);
                            ctx.textAlign = "center";
                            for (let n = 0; n < count; ++n) {
                                ctx.fillText(root.fmtTemp(values[n]), pointX(n), yAt(values[n], minTemp, maxTemp) - 10);
                            }
                        }
                    }

                    Repeater {
                        model: root.modelCount()

                        delegate: Item {
                            property var hourItem: root.itemAt(index)

                            x: root.itemWidth * index
                            width: root.itemWidth
                            height: trendContent.height

                            Text {
                                width: parent.width
                                y: trendContent.topTextY
                                text: root.hourLabel(hourItem.time)
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: Fonts.numeric
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MeteoIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: trendContent.iconY
                                width: trendContent.iconSize
                                height: trendContent.iconSize
                                weatherCode: root.valueAt(hourItem, "weatherCode", -1)
                                iconName: hourItem.iconName || ""
                                night: hourItem.isDaylight === undefined ? false : !hourItem.isDaylight
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

            Item {
                anchors.fill: parent
                visible: root.currentTab === 1

                HourlyAirQualityTrendPane {
                    anchors.fill: parent
                    sourceModel: root.sourceModel
                }

            }

            Item {
                anchors.fill: parent
                visible: root.currentTab === 2

                HourlyWindTrendPane {
                    anchors.fill: parent
                    sourceModel: root.sourceModel
                }

            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 3
                sourceModel: root.sourceModel
                metric: "uv"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 4
                sourceModel: root.sourceModel
                metric: "precipitation"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 5
                sourceModel: root.sourceModel
                metric: "feels"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 6
                sourceModel: root.sourceModel
                metric: "humidity"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 7
                sourceModel: root.sourceModel
                metric: "pressure"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 8
                sourceModel: root.sourceModel
                metric: "cloud"
            }

            WeatherMetricTrendPane {
                anchors.fill: parent
                visible: root.currentTab === 9
                sourceModel: root.sourceModel
                metric: "visibility"
            }

        }

    }

    Connections {
        function onModelReset() {
            trendCanvas.requestPaint();
        }

        function onDataChanged() {
            trendCanvas.requestPaint();
        }

        function onRowsInserted() {
            trendCanvas.requestPaint();
        }

        function onRowsRemoved() {
            trendCanvas.requestPaint();
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
