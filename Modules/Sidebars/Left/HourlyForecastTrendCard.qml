import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

Rectangle {
    id: root

    property var sourceModel
    property real itemWidth: trendFlick.width > 0 ? trendFlick.width / 6 : 122
    property int maxItems: 25
    property int currentTab: 0

    radius: 26
    color: Qt.rgba(0.10, 0.12, 0.13, 0.985)
    border.width: 1
    border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.42)
    clip: true

    function modelCount() {
        return sourceModel && sourceModel.count ? Math.min(maxItems, sourceModel.count()) : 0
    }

    function itemAt(index) {
        return sourceModel && sourceModel.get ? sourceModel.get(index) : ({})
    }

    function valueAt(map, key, fallback) {
        const v = map ? map[key] : undefined
        return (v === undefined || v === null || isNaN(v)) ? fallback : Number(v)
    }

    function fmtTemp(value) {
        return value !== undefined && value !== null && !isNaN(value) ? Math.round(value) + "°" : "--"
    }

    function hourLabel(epoch) {
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "hh:00") : "--"
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
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "逐小时预报"
                    color: Appearance.colors.colOnSurface
                    font.family: "LXGW WenKai GB Screen"
                    font.bold: true
                    font.pixelSize: 22
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    spacing: 0

                    TabBtn { textStr: "天气情况"; tabIdx: 0; isFirst: true }
                    TabBtn { textStr: "空气质量"; tabIdx: 1 }
                    TabBtn { textStr: "风况"; tabIdx: 2; isLast: true }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    radius: 18
                    color: moreMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "more_horiz"
                        color: Appearance.colors.colOnSurfaceVariant
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: moreMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: console.log("Open hourly weather menu")
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
                smoothWheelEnabled: false
                contentWidth: Math.max(width, root.modelCount() * root.itemWidth)
                contentHeight: height
                visible: root.currentTab === 0

                onContentXChanged: trendCanvas.requestPaint()

                Item {
                    id: trendContent
                    width: trendFlick.contentWidth
                    height: trendFlick.height

                    property real topTextY: 6
                    property real iconY: 28
                    property real iconSize: Math.max(46, Math.min(60, root.itemWidth * 0.46))
                    property real chartTopInset: 96
                    property real chartBottomInset: Math.max(chartTopInset + 70, height - 30)

                    Canvas {
                        id: trendCanvas
                        anchors.fill: parent
                        antialiasing: true

                        property real chartTop: trendContent.chartTopInset
                        property real chartBottom: trendContent.chartBottomInset

                        function pointX(index) {
                            return root.itemWidth * index + root.itemWidth / 2
                        }

                        function yAt(value, minValue, maxValue) {
                            return chartBottom - (value - minValue) / (maxValue - minValue) * (chartBottom - chartTop)
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            const count = root.modelCount()
                            if (count < 2) return

                            let values = []
                            let minTemp = 999
                            let maxTemp = -999

                            for (let i = 0; i < count; ++i) {
                                const item = root.itemAt(i)
                                const temp = root.valueAt(item, "temperatureC", NaN)
                                values.push(temp)
                                if (!isNaN(temp)) {
                                    minTemp = Math.min(minTemp, temp)
                                    maxTemp = Math.max(maxTemp, temp)
                                }
                            }

                            if (maxTemp < minTemp) return
                            if (Math.abs(maxTemp - minTemp) < 0.1) {
                                maxTemp += 1
                                minTemp -= 1
                            }

                            ctx.strokeStyle = Appearance.colors.colPrimary
                            ctx.lineWidth = 3
                            ctx.lineJoin = "round"
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            for (let j = 0; j < count; ++j) {
                                const x2 = pointX(j)
                                const y2 = yAt(values[j], minTemp, maxTemp)
                                if (j === 0) ctx.moveTo(x2, y2)
                                else ctx.lineTo(x2, y2)
                            }
                            ctx.stroke()

                            for (let p = 0; p < count; ++p) {
                                const px = pointX(p)
                                const py = yAt(values[p], minTemp, maxTemp)
                                ctx.fillStyle = Appearance.colors.colPrimary
                                ctx.beginPath()
                                ctx.arc(px, py, 4.5, 0, Math.PI * 2)
                                ctx.fill()
                                ctx.fillStyle = Appearance.colors.colLayer4
                                ctx.beginPath()
                                ctx.arc(px, py, 2.4, 0, Math.PI * 2)
                                ctx.fill()
                            }

                            ctx.fillStyle = Appearance.colors.colOnSurface
                            ctx.font = "bold 13px \"JetBrainsMono Nerd Font\""
                            ctx.textAlign = "center"
                            for (let n = 0; n < count; ++n) {
                                ctx.fillText(root.fmtTemp(values[n]), pointX(n), yAt(values[n], minTemp, maxTemp) - 10)
                            }
                        }
                    }

                    Repeater {
                        model: root.modelCount()

                        delegate: Item {
                            x: root.itemWidth * index
                            width: root.itemWidth
                            height: trendContent.height

                            property var hourItem: root.itemAt(index)

                            Text {
                                width: parent.width
                                y: trendContent.topTextY
                                text: root.hourLabel(hourItem.time)
                                color: Appearance.colors.colOnSurfaceVariant
                                font.family: "JetBrainsMono Nerd Font"
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
        }
    }

    component TabBtn: Item {
        property string textStr: ""
        property int tabIdx: 0
        property bool isFirst: false
        property bool isLast: false
        property bool isActive: root.currentTab === tabIdx

        Layout.preferredWidth: textItem.implicitWidth + 30 + (btnMouse.pressed ? 8 : 0)
        Layout.preferredHeight: 36

        property real rLeft: (isActive || isFirst || btnMouse.pressed) ? 16 : 4
        property real rRight: (isActive || isLast || btnMouse.pressed) ? 16 : 4
        property color bgColor: isActive
                                ? Appearance.colors.colPrimaryContainer
                                : (btnMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2)

        Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on bgColor { ColorAnimation { duration: 150 } }

        Rectangle {
            anchors.fill: parent
            radius: parent.rLeft > parent.rRight ? parent.rLeft : parent.rRight
            color: parent.bgColor

            Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
        }

        Rectangle {
            anchors.left: (parent.rLeft < parent.rRight) ? parent.left : undefined
            anchors.right: (parent.rRight < parent.rLeft) ? parent.right : undefined
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width / 2 + 5
            visible: parent.rLeft !== parent.rRight
            radius: parent.rLeft < parent.rRight ? parent.rLeft : parent.rRight
            color: parent.bgColor

            Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
        }

        Text {
            id: textItem
            anchors.centerIn: parent
            text: parent.textStr
            font.family: "LXGW WenKai GB Screen"
            font.pixelSize: 14
            font.bold: parent.isActive
            color: parent.isActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
            z: 2

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.currentTab = parent.tabIdx
            z: 3
        }
    }

    Connections {
        target: root.sourceModel
        ignoreUnknownSignals: true
        function onModelReset() { trendCanvas.requestPaint() }
        function onDataChanged() { trendCanvas.requestPaint() }
        function onRowsInserted() { trendCanvas.requestPaint() }
        function onRowsRemoved() { trendCanvas.requestPaint() }
    }

    onSourceModelChanged: trendCanvas.requestPaint()
    onWidthChanged: trendCanvas.requestPaint()
    onHeightChanged: trendCanvas.requestPaint()
}
