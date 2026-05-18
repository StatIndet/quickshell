import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var sourceModel
    property int maxItems: 16
    property var items: []
    property bool hasData: false
    property real itemWidth: width > 0 ? width / 6 : 122
    property real chartMax: 15

    readonly property real topPadding: 16
    readonly property real contentWidth: Math.max(width, items.length * itemWidth)
    readonly property real dayArrowY: 60
    readonly property real topBarBaseY: height * 0.56 - 6
    readonly property real bottomBarBaseY: height * 0.56 + 6
    readonly property real barHalfRange: Math.max(36, Math.min(64, height * 0.16))
    readonly property real nightArrowY: height - 70

    clip: true

    function dayLabel(index, epoch) {
        if (index === 0) return "昨天"
        if (index === 1) return "今天"
        if (index === 2) return "明天"
        if (!epoch) return "--"
        const week = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return week[new Date(epoch * 1000).getDay()]
    }

    function dateLabel(epoch) {
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "M/d") : "--"
    }

    function validNumber(value) {
        return value !== undefined && value !== null && !isNaN(value)
    }

    function formatSpeedValue(value) {
        if (!root.validNumber(value)) return "--"
        const rounded = Math.round(value * 10) / 10
        if (Math.abs(rounded - Math.round(rounded)) < 0.05) return Math.round(rounded).toString()
        return rounded.toFixed(1)
    }

    function beaufortLevel(speedMs) {
        if (!root.validNumber(speedMs) || speedMs < 0.3) return 0
        if (speedMs < 1.6) return 1
        if (speedMs < 3.4) return 2
        if (speedMs < 5.5) return 3
        if (speedMs < 8.0) return 4
        if (speedMs < 10.8) return 5
        if (speedMs < 13.9) return 6
        if (speedMs < 17.2) return 7
        if (speedMs < 20.8) return 8
        if (speedMs < 24.5) return 9
        if (speedMs < 28.5) return 10
        if (speedMs < 32.7) return 11
        return 12
    }

    function windColor(speedMs) {
        const bf = root.beaufortLevel(speedMs)
        if (bf < 4) return "#72d572"
        if (bf < 6) return "#ffca28"
        if (bf < 8) return "#ffa726"
        if (bf < 10) return "#e52f35"
        if (bf < 12) return "#99004c"
        return "#7e0023"
    }

    function chartUpperBound(highest) {
        if (!root.validNumber(highest) || highest <= 0) return 5
        if (highest <= 5) return 5
        if (highest <= 8) return 8
        if (highest <= 12) return 12
        if (highest <= 15) return 15
        return Math.ceil(highest / 5) * 5
    }

    function rebuild() {
        const list = []
        let highest = 0
        let validCount = 0
        const count = root.sourceModel && root.sourceModel.count ? Math.min(root.maxItems, root.sourceModel.count()) : 0
        for (let i = 0; i < count; ++i) {
            const dayItem = root.sourceModel.get(i) || ({})
            const dayPart = dayItem.day || ({})
            const nightPart = dayItem.night || ({})
            const daySpeed = Number(dayPart.windSpeedMs)
            const nightSpeed = Number(nightPart.windSpeedMs)
            if (root.validNumber(daySpeed)) {
                highest = Math.max(highest, daySpeed)
                validCount += 1
            }
            if (root.validNumber(nightSpeed)) {
                highest = Math.max(highest, nightSpeed)
                validCount += 1
            }
            list.push({
                time: dayItem.time || 0,
                dayText: root.dayLabel(i, dayItem.time || 0),
                dateText: root.dateLabel(dayItem.time || 0),
                daySpeed: daySpeed,
                nightSpeed: nightSpeed,
                dayTextValue: root.formatSpeedValue(daySpeed),
                nightTextValue: root.formatSpeedValue(nightSpeed),
                dayDirection: Number(dayPart.windDirection),
                nightDirection: Number(nightPart.windDirection),
                dayColor: root.windColor(daySpeed),
                nightColor: root.windColor(nightSpeed),
                emphasized: i !== 0
            })
        }
        items = list
        chartMax = root.chartUpperBound(highest)
        hasData = validCount > 0
    }

    function barHeight(speed) {
        if (!root.validNumber(speed) || speed <= 0 || chartMax <= 0) return 0
        return Math.max(10, Math.min(barHalfRange, barHalfRange * speed / chartMax))
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

        function onModelReset() { root.rebuild() }
        function onRowsInserted() { root.rebuild() }
        function onRowsRemoved() { root.rebuild() }
        function onDataChanged() { root.rebuild() }
    }

    StyledFlickable {
        id: trendFlick

        anchors.fill: parent
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        showVerticalScrollBar: false
        smoothWheelEnabled: false
        contentWidth: root.contentWidth
        contentHeight: height

        Item {
            id: trendContent
            width: trendFlick.contentWidth
            height: trendFlick.height

            Repeater {
                model: root.items

                Item {
                    required property var modelData
                    required property int index

                    x: index * root.itemWidth
                    width: root.itemWidth
                    height: root.height

                    readonly property color weekColor: modelData.emphasized
                                                       ? Appearance.colors.colOnSurface
                                                       : Qt.rgba(Appearance.colors.colOnSurfaceVariant.r, Appearance.colors.colOnSurfaceVariant.g, Appearance.colors.colOnSurfaceVariant.b, 0.78)
                    readonly property color dateColor: modelData.emphasized
                                                       ? Appearance.colors.colOnSurfaceVariant
                                                       : Qt.rgba(Appearance.colors.colOnSurfaceVariant.r, Appearance.colors.colOnSurfaceVariant.g, Appearance.colors.colOnSurfaceVariant.b, 0.62)
                    readonly property real dayBarHeight: root.barHeight(modelData.daySpeed)
                    readonly property real nightBarHeight: root.barHeight(modelData.nightSpeed)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.topPadding
                        text: modelData.dayText
                        color: parent.weekColor
                        font.family: "LXGW WenKai GB Screen"
                        font.pixelSize: 14
                        font.bold: modelData.dayText === "今天"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.topPadding + 22
                        text: modelData.dateText
                        color: parent.dateColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    WindDirectionGlyph {
                        visible: root.validNumber(modelData.dayDirection)
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.dayArrowY
                        width: 44
                        height: 44
                        glyphColor: modelData.dayColor
                        directionDegrees: modelData.dayDirection
                    }

                    Text {
                        visible: root.validNumber(modelData.daySpeed) && modelData.daySpeed > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.topBarBaseY - parent.dayBarHeight - 28
                        text: modelData.dayTextValue
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    Rectangle {
                        visible: parent.dayBarHeight > 0
                        width: 10
                        height: parent.dayBarHeight
                        x: (parent.width - width) / 2
                        y: root.topBarBaseY - height
                        radius: width / 2
                        color: Qt.rgba(Qt.color(modelData.dayColor).r, Qt.color(modelData.dayColor).g, Qt.color(modelData.dayColor).b, 0.96)
                    }

                    Rectangle {
                        visible: parent.nightBarHeight > 0
                        width: 10
                        height: parent.nightBarHeight
                        x: (parent.width - width) / 2
                        y: root.bottomBarBaseY
                        radius: width / 2
                        color: Qt.rgba(Qt.color(modelData.nightColor).r, Qt.color(modelData.nightColor).g, Qt.color(modelData.nightColor).b, 0.58)
                    }

                    Text {
                        visible: root.validNumber(modelData.nightSpeed) && modelData.nightSpeed > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.bottomBarBaseY + parent.nightBarHeight + 8
                        text: modelData.nightTextValue
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    WindDirectionGlyph {
                        visible: root.validNumber(modelData.nightDirection)
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.nightArrowY
                        width: 44
                        height: 44
                        glyphColor: modelData.nightColor
                        directionDegrees: modelData.nightDirection
                    }
                }
            }

            MouseArea {
                id: dragArea
                x: trendFlick.contentX
                y: 0
                z: 20
                width: trendFlick.width
                height: trendFlick.height
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real lastMouseX: 0

                onPressed: function(mouse) {
                    lastMouseX = mouse.x
                }

                onPositionChanged: function(mouse) {
                    if (!pressed) return
                    const dx = mouse.x - lastMouseX
                    const maxX = Math.max(0, trendFlick.contentWidth - trendFlick.width)
                    trendFlick.contentX = Math.max(0, Math.min(maxX, trendFlick.contentX - dx))
                    lastMouseX = mouse.x
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.hasData
        text: "风况数据暂不可用"
        color: Appearance.colors.colOnSurfaceVariant
        font.family: "LXGW WenKai GB Screen"
        font.pixelSize: 16
    }
}
