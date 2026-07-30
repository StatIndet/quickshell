import QtQuick
import QtQuick.Controls
import qs.Common

Item {
    id: root

    property var sourceModel
    property int maxDays: 6
    property var items: []
    property var keyLines: []
    property real chartMax: 150
    property bool hasData: false

    readonly property real sidePadding: 18
    readonly property real topPadding: 16
    readonly property real chartTop: 90
    readonly property real chartBottom: height - 56
    readonly property real chartWidth: Math.max(0, width - sidePadding * 2)
    readonly property real columnWidth: items.length > 0 ? chartWidth / items.length : chartWidth

    clip: true

    function aqiThresholds() {
        return [0, 20, 50, 100, 150, 250]
    }

    function aqiLevelIndex(aqi) {
        if (aqi === undefined || aqi === null || isNaN(aqi)) return -1
        const thresholds = root.aqiThresholds()
        for (let i = thresholds.length - 1; i >= 0; --i) {
            if (aqi >= thresholds[i]) return i
        }
        return -1
    }

    function aqiLevelName(level) {
        const names = [qsTr("优"), qsTr("良"), qsTr("差"), qsTr("不健康"), qsTr("很不健康"), qsTr("危险")]
        return level >= 0 && level < names.length ? names[level] : "--"
    }

    function aqiPalette(level) {
        const colors = ["#00e59b", "#ffc302", "#ff712b", "#f62a55", "#c72eaa", "#9930ff"]
        return colors[Math.max(0, Math.min(colors.length - 1, level >= 0 ? level : 0))]
    }

    function pollutantIndex(value, thresholds) {
        if (value === undefined || value === null || isNaN(value)) return NaN
        const aqi = root.aqiThresholds()
        for (let level = thresholds.length - 1; level >= 0; --level) {
            if (value >= thresholds[level]) {
                if (level < thresholds.length - 1) {
                    const bpLo = thresholds[level]
                    const bpHi = thresholds[level + 1]
                    const inLo = aqi[level]
                    const inHi = aqi[level + 1]
                    return Math.round((inHi - inLo) / (bpHi - bpLo) * (value - bpLo) + inLo)
                }
                return Math.round(value * aqi[aqi.length - 1] / thresholds[thresholds.length - 1])
            }
        }
        return NaN
    }

    function dailyAqiValue(air) {
        if (!air) return NaN
        const values = [
            root.pollutantIndex(air.ozone, [0, 50, 100, 160, 240, 480]),
            root.pollutantIndex(air.nitrogenDioxide, [0, 10, 25, 200, 400, 1000]),
            root.pollutantIndex(air.pm10, [0, 15, 45, 80, 160, 400]),
            root.pollutantIndex(air.pm25, [0, 5, 15, 30, 60, 150])
        ].filter(function(v) { return !isNaN(v) })
        if (values.length === 0) return NaN
        return Math.max.apply(Math, values)
    }

    function dayLabel(index, epoch) {
        if (index === 0) return qsTr("昨天")
        if (index === 1) return qsTr("今天")
        if (index === 2) return qsTr("明天")
        if (!epoch) return "--"
        const week = [qsTr("周日"), qsTr("周一"), qsTr("周二"), qsTr("周三"), qsTr("周四"), qsTr("周五"), qsTr("周六")]
        return week[new Date(epoch * 1000).getDay()]
    }

    function dateLabel(epoch) {
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "M/d") : "--"
    }

    function yForValue(value) {
        if (value === undefined || value === null || isNaN(value)) return chartBottom
        if (chartMax <= 0) return chartBottom
        const clamped = Math.max(0, Math.min(chartMax, value))
        return chartBottom - clamped / chartMax * (chartBottom - chartTop)
    }

    function chartUpperBound(highest) {
        if (highest === undefined || highest === null || isNaN(highest) || highest <= 0) return 100
        if (highest <= 100) return 100
        if (highest <= 150) return 150
        if (highest <= 250) return 250
        return Math.ceil(highest / 50) * 50
    }

    function rebuild() {
        const list = []
        let highest = 0
        let validCount = 0
        const count = root.sourceModel && root.sourceModel.count ? Math.min(root.maxDays, root.sourceModel.count()) : 0
        for (let i = 0; i < count; ++i) {
            const day = root.sourceModel.get(i) || ({})
            const aqi = root.dailyAqiValue(day.airQuality || ({}))
            const level = root.aqiLevelIndex(aqi)
            if (!isNaN(aqi)) {
                highest = Math.max(highest, aqi)
                validCount += 1
            }
            list.push({
                time: day.time || 0,
                dayText: root.dayLabel(i, day.time || 0),
                dateText: root.dateLabel(day.time || 0),
                aqi: aqi,
                aqiText: !isNaN(aqi) ? Math.round(aqi).toString() : "--",
                levelText: root.aqiLevelName(level),
                color: root.aqiPalette(level),
                emphasized: i !== 0
            })
        }
        items = list
        chartMax = root.chartUpperBound(highest)
        hasData = validCount > 0

        const lines = [
            { value: 20, label: root.aqiLevelName(1) },
            { value: 100, label: root.aqiLevelName(3) }
        ]
        if (chartMax >= 250) {
            lines.push({ value: 250, label: root.aqiLevelName(5) })
        }
        keyLines = lines
    }

    Timer {
        id: rebuildTimer
        interval: 0
        repeat: false
        onTriggered: rebuild()
    }

    onSourceModelChanged: rebuild()
    onWidthChanged: rebuildTimer.restart()
    onHeightChanged: rebuildTimer.restart()
    Component.onCompleted: rebuild()

    Connections {
        target: root.sourceModel
        ignoreUnknownSignals: true

        function onModelReset() {
            root.rebuild()
        }

        function onRowsInserted() {
            root.rebuild()
        }

        function onRowsRemoved() {
            root.rebuild()
        }

        function onDataChanged() {
            root.rebuild()
        }
    }

    Repeater {
        model: root.keyLines

        Item {
            required property var modelData

            x: root.sidePadding
            y: root.yForValue(modelData.value)
            width: root.chartWidth
            height: 20

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.44)
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.verticalCenter
                anchors.leftMargin: 2
                anchors.bottomMargin: 5
                text: modelData.value
                color: Qt.rgba(Appearance.colors.colOnSurfaceVariant.r, Appearance.colors.colOnSurfaceVariant.g, Appearance.colors.colOnSurfaceVariant.b, 0.72)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.verticalCenter
                anchors.rightMargin: 2
                anchors.bottomMargin: 5
                text: modelData.label
                color: Qt.rgba(Appearance.colors.colOnSurfaceVariant.r, Appearance.colors.colOnSurfaceVariant.g, Appearance.colors.colOnSurfaceVariant.b, 0.72)
                font.family: "LXGW WenKai GB Screen"
                font.pixelSize: 12
            }
        }
    }

    Repeater {
        model: root.items

        Item {
            required property var modelData
            required property int index

            x: root.sidePadding + index * root.columnWidth
            y: 0
            width: root.columnWidth
            height: root.height

            readonly property real barWidth: Math.max(14, Math.min(22, width * 0.26))
            readonly property real barHeight: !isNaN(modelData.aqi) ? Math.max(10, root.chartBottom - root.yForValue(modelData.aqi)) : 0
            readonly property color weekColor: modelData.emphasized
                                               ? Appearance.colors.colOnSurface
                                               : Qt.rgba(Appearance.colors.colOnSurfaceVariant.r, Appearance.colors.colOnSurfaceVariant.g, Appearance.colors.colOnSurfaceVariant.b, 0.78)
            readonly property color dateColor: modelData.emphasized
                                               ? Appearance.colors.colOnSurfaceVariant
                                               : Qt.rgba(Appearance.colors.colOnSurfaceVariant.r, Appearance.colors.colOnSurfaceVariant.g, Appearance.colors.colOnSurfaceVariant.b, 0.62)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.topPadding
                text: modelData.dayText
                color: parent.weekColor
                font.family: "LXGW WenKai GB Screen"
                font.pixelSize: 14
                font.bold: modelData.dayText === qsTr("今天")
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.topPadding + 22
                text: modelData.dateText
                color: parent.dateColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

            Rectangle {
                visible: !isNaN(modelData.aqi)
                width: parent.barWidth
                height: parent.barHeight
                x: (parent.width - width) / 2
                y: root.chartBottom - height
                radius: width / 2
                color: Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.58)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.chartBottom + 10
                text: modelData.aqiText
                color: Appearance.colors.colOnSurface
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.bold: modelData.dayText === qsTr("今天")
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.hasData
        text: qsTr("空气质量数据暂不可用")
        color: Appearance.colors.colOnSurfaceVariant
        font.family: "LXGW WenKai GB Screen"
        font.pixelSize: 16
    }
}
