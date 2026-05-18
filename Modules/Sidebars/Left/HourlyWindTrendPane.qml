import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets.common

Item {
    id: root

    property var sourceModel
    property int maxHours: 25
    property var items: []
    property bool hasData: false
    property real itemWidth: width > 0 ? width / 6 : 122
    property real chartMax: 15

    readonly property real topPadding: 12
    readonly property real arrowY: 34
    readonly property real chartTop: 118
    readonly property real chartBottom: height - 18
    readonly property real contentWidth: Math.max(width, items.length * itemWidth)

    clip: true

    function validNumber(value) {
        return value !== undefined && value !== null && !isNaN(value)
    }

    function hourLabel(epoch) {
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "hh:00") : "--"
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

    function yForValue(value) {
        if (!root.validNumber(value) || chartMax <= 0) return chartBottom
        const clamped = Math.max(0, Math.min(chartMax, value))
        return chartBottom - clamped / chartMax * (chartBottom - chartTop)
    }

    function rebuild() {
        const list = []
        let highest = 0
        let validCount = 0
        const count = root.sourceModel && root.sourceModel.count ? Math.min(root.maxHours, root.sourceModel.count()) : 0
        for (let i = 0; i < count; ++i) {
            const item = root.sourceModel.get(i) || ({})
            const speed = Number(item.windSpeedMs)
            const direction = Number(item.windDirection)
            if (root.validNumber(speed)) {
                highest = Math.max(highest, speed)
                validCount += 1
            }
            list.push({
                time: item.time || 0,
                hourText: root.hourLabel(item.time || 0),
                speed: speed,
                speedText: root.formatSpeedValue(speed),
                direction: direction,
                color: root.windColor(speed),
                emphasized: i !== 0
            })
        }
        items = list
        chartMax = root.chartUpperBound(highest)
        hasData = validCount > 0
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

                    readonly property color hourColor: modelData.emphasized
                                                       ? Appearance.colors.colOnSurfaceVariant
                                                       : Qt.rgba(Appearance.colors.colOnSurfaceVariant.r, Appearance.colors.colOnSurfaceVariant.g, Appearance.colors.colOnSurfaceVariant.b, 0.64)
                    readonly property real barTop: root.yForValue(modelData.speed)
                    readonly property real barWidth: Math.max(8, Math.min(12, width * 0.36))

                    Text {
                        width: parent.width
                        y: root.topPadding
                        text: modelData.hourText
                        color: parent.hourColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }

                    WindDirectionGlyph {
                        visible: root.validNumber(modelData.direction)
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.arrowY
                        width: 40
                        height: 40
                        glyphColor: modelData.color
                        directionDegrees: modelData.direction
                    }

                    Rectangle {
                        visible: root.validNumber(modelData.speed) && modelData.speed > 0
                        width: parent.barWidth
                        height: Math.max(10, root.chartBottom - parent.barTop)
                        x: (parent.width - width) / 2
                        y: parent.barTop
                        radius: width / 2
                        color: Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.96)
                    }

                    Text {
                        visible: root.validNumber(modelData.speed) && modelData.speed > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.barTop - 22
                        text: modelData.speedText
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
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
