import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components
import "../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    property var network: ({
    })
    property var downloadHistory: []
    property var uploadHistory: []
    property color surfaceColor: Appearance.colors.colPrimary
    property color panelColor: Appearance.colors.colPrimaryContainer
    property bool chartActive: visible
    property int updateInterval: 1000
    readonly property color leftColor: root.surfaceColor
    readonly property color leftForeground: Appearance.colors.colOnPrimary
    readonly property color rightColor: root.panelColor
    readonly property color rightForeground: Appearance.colors.colOnPrimaryContainer
    readonly property color downloadIconColor: Appearance.colors.colTertiary
    readonly property color uploadIconColor: Appearance.mix(Appearance.colors.colPrimary, Appearance.colors.colOnPrimary, 0.76)
    readonly property color downloadChartColor: Appearance.mix(root.downloadIconColor, root.leftForeground, 0.64)
    readonly property color uploadChartColor: Appearance.mix(root.uploadIconColor, root.leftForeground, 0.58)
    readonly property real rightPanelX: Math.round(width * 0.53)
    readonly property real chartMaximum: {
        let maximum = 0;
        const series = [root.downloadHistory || [], root.uploadHistory || []];
        for (let seriesIndex = 0; seriesIndex < series.length; seriesIndex += 1) {
            const points = series[seriesIndex];
            for (let index = 0; index < points.length; index += 1) {
                const value = points[index];
                if (typeof value === "number" && isFinite(value))
                    maximum = Math.max(maximum, value);

            }
        }
        return Math.max(1, maximum * 1.2);
    }
    readonly property var expressiveBoldAxes: Fonts.familyAvailable(Fonts.bundledFamilyName) && Fonts.expressive === Fonts.bundledFamilyName ? ({
        "GRAD": 100,
        "ROND": 35,
        "wdth": 85
    }) : ({
    })

    clip: true
    layer.enabled: true
    Accessible.name: qsTr("网络，下载 ") + Format.bytesPerSecond(root.network.downloadBytesPerSecond) + qsTr("，上传 ") + Format.bytesPerSecond(root.network.uploadBytesPerSecond)

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: root.leftColor
    }

    Text {
        text: qsTr("网络")
        color: root.leftForeground
        renderType: Text.NativeRendering
        font.family: Fonts.expressive
        font.pixelSize: 34
        font.weight: Font.Black
        font.variableAxes: root.expressiveBoldAxes

        anchors {
            left: parent.left
            top: parent.top
            leftMargin: Appearance.spacing.medium
            topMargin: 16
        }

    }

    SystemSparkline {
        values: root.uploadHistory
        maximum: root.chartMaximum
        historyLength: 18
        updateInterval: root.updateInterval
        active: root.chartActive
        showGuideLines: false
        fillArea: true
        fillOpacity: 0.3
        lineColor: root.uploadChartColor
        baselineColor: "transparent"
        lineWidth: 0
        Accessible.ignored: true

        anchors {
            left: parent.left
            right: ratePanel.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 0
            rightMargin: -Math.min(ratePanel.radius, 30)
            topMargin: 46
            bottomMargin: Appearance.spacing.small
        }

    }

    SystemSparkline {
        values: root.downloadHistory
        secondaryValues: root.uploadHistory
        maximum: root.chartMaximum
        historyLength: 18
        updateInterval: root.updateInterval
        active: root.chartActive
        showGuideLines: false
        fillArea: true
        fillOpacity: 0.26
        accessibilityName: qsTr("网络近期趋势")
        accessibilityDescription: qsTr("下载 ") + Format.bytesPerSecond(root.network.downloadBytesPerSecond) + qsTr("，上传 ") + Format.bytesPerSecond(root.network.uploadBytesPerSecond)
        lineColor: root.downloadChartColor
        secondaryLineColor: root.uploadChartColor
        baselineColor: "transparent"
        lineWidth: 3

        anchors {
            left: parent.left
            right: ratePanel.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 0
            rightMargin: -Math.min(ratePanel.radius, 30)
            topMargin: 46
            bottomMargin: Appearance.spacing.small
        }

    }

    Rectangle {
        id: ratePanel

        x: root.rightPanelX
        y: 0
        width: root.width - x
        height: root.height
        radius: Appearance.rounding.extraLarge
        color: root.rightColor
        z: 2

        Column {
            spacing: 2

            anchors {
                fill: parent
                leftMargin: Appearance.spacing.medium
                rightMargin: Appearance.spacing.medium
                topMargin: 13
                bottomMargin: 13
            }

            Text {
                width: parent.width
                height: 24
                text: root.network.defaultInterface || qsTr("全部接口")
                color: root.rightForeground
                renderType: Text.NativeRendering
                font.family: Fonts.expressive
                font.pixelSize: 16
                font.weight: Font.Black
                font.variableAxes: root.expressiveBoldAxes
                elide: Text.ElideRight
            }

            NetworkRate {
                width: parent.width
                height: (parent.height - 24 - parent.spacing * 2) / 2
                iconName: "download"
                value: Format.bytesPerSecond(root.network.downloadBytesPerSecond)
                accentColor: root.downloadIconColor
            }

            NetworkRate {
                width: parent.width
                height: (parent.height - 24 - parent.spacing * 2) / 2
                iconName: "upload"
                value: Format.bytesPerSecond(root.network.uploadBytesPerSecond)
                accentColor: root.uploadIconColor
            }

        }

    }

    layer.effect: OpacityMask {

        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: Appearance.rounding.extraLarge
        }

    }

    component NetworkRate: Item {
        id: rate

        required property string iconName
        required property string value
        required property color accentColor

        MaterialSymbol {
            id: rateIcon

            text: rate.iconName
            iconSize: 27
            fill: 1
            color: rate.accentColor

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }

        }

        Text {
            text: rate.value
            color: root.rightForeground
            renderType: Text.NativeRendering
            font.family: Fonts.expressive
            font.pixelSize: 27
            font.weight: Font.Black
            font.variableAxes: root.expressiveBoldAxes
            elide: Text.ElideRight

            anchors {
                left: rateIcon.right
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Appearance.spacing.small
            }

        }

    }

}
