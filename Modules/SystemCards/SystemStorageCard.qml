import "../../Common/functions/SystemFormat.js" as Format
import "../ControlCenter" as ControlCenter
import Qt5Compat.GraphicalEffects
import QtQuick
import qs.Common
import qs.Components

Item {
    id: root

    property var disks: []
    property var readHistories: ({
    })
    property var writeHistories: ({
    })
    property color surfaceColor: Appearance.colors.colTertiary
    property color panelColor: Appearance.colors.colTertiaryContainer
    property bool chartActive: visible
    property int updateInterval: 1000
    property string preferredDiskDevice: ""
    readonly property var disk: {
        for (let index = 0; index < root.disks.length; index += 1) {
            if (String(root.disks[index].device || "") === root.preferredDiskDevice)
                return root.disks[index];

        }
        return root.disks.length > 0 ? root.disks[0] : ({
        });
    }
    readonly property var diskOptions: {
        const options = [];
        for (let index = 0; index < root.disks.length; index += 1) {
            const device = String(root.disks[index].device || "");
            if (device !== "")
                options.push({
                "value": device,
                "label": device
            });

        }
        return options;
    }
    readonly property string selectedDevice: String(root.disk.device || "")
    readonly property var readHistory: root.readHistories[root.selectedDevice] || []
    readonly property var writeHistory: root.writeHistories[root.selectedDevice] || []
    readonly property color leftColor: root.surfaceColor
    readonly property color leftForeground: Appearance.colors.colOnTertiary
    readonly property color rightColor: root.panelColor
    readonly property color rightForeground: Appearance.colors.colOnPrimaryContainer
    readonly property color readDataColor: Appearance.mix(Appearance.colors.colPrimary, root.leftForeground, 0.62)
    readonly property color writeDataColor: Appearance.mix(Appearance.colors.colSecondary, root.leftForeground, 0.58)
    readonly property real rightPanelX: Math.round(width * 0.53)
    readonly property int chartHistoryLength: 18
    readonly property real chartMaximum: {
        let maximum = 0;
        const series = [root.readHistory, root.writeHistory];
        for (let seriesIndex = 0; seriesIndex < series.length; seriesIndex += 1) {
            const points = series[seriesIndex];
            const firstVisibleIndex = Math.max(0, points.length - root.chartHistoryLength);
            for (let index = firstVisibleIndex; index < points.length; index += 1) {
                const value = points[index];
                if (Format.isNumber(value))
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

    signal diskSelected(string device)

    clip: true
    layer.enabled: true
    Accessible.name: root.disks.length > 0 ? qsTr("磁盘 %1，读取 %2，写入 %3").arg(root.selectedDevice, Format.bytesPerSecond(root.disk.readBytesPerSecond), Format.bytesPerSecond(root.disk.writeBytesPerSecond)) : qsTr("未检测到磁盘")

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: root.leftColor
    }

    Text {
        text: qsTr("磁盘 I/O")
        color: root.leftForeground
        renderType: Text.NativeRendering
        font.family: Fonts.expressive
        font.pixelSize: 32
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
        values: root.writeHistory
        maximum: root.chartMaximum
        historyLength: root.chartHistoryLength
        updateInterval: root.updateInterval
        active: root.chartActive
        showGuideLines: false
        fillArea: true
        fillOpacity: 0.3
        lineColor: root.writeDataColor
        baselineColor: "transparent"
        lineWidth: 0
        Accessible.ignored: true

        anchors {
            left: parent.left
            right: ratePanel.left
            top: parent.top
            bottom: parent.bottom
            topMargin: 46
            bottomMargin: Appearance.spacing.small
        }

    }

    SystemSparkline {
        values: root.readHistory
        secondaryValues: root.writeHistory
        maximum: root.chartMaximum
        historyLength: root.chartHistoryLength
        updateInterval: root.updateInterval
        active: root.chartActive
        showGuideLines: false
        fillArea: true
        fillOpacity: 0.26
        accessibilityName: qsTr("磁盘近期吞吐趋势")
        accessibilityDescription: qsTr("读取 %1，写入 %2").arg(Format.bytesPerSecond(root.disk.readBytesPerSecond), Format.bytesPerSecond(root.disk.writeBytesPerSecond))
        lineColor: root.readDataColor
        secondaryLineColor: root.writeDataColor
        baselineColor: "transparent"
        lineWidth: 3

        anchors {
            left: parent.left
            right: ratePanel.left
            top: parent.top
            bottom: parent.bottom
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
        clip: true
        z: 2

        Column {
            id: rateColumn

            spacing: 2
            z: 2

            anchors {
                fill: parent
                leftMargin: Appearance.spacing.medium
                rightMargin: Appearance.spacing.medium
                topMargin: 10
                bottomMargin: 10
            }

            ControlCenter.SplitMenuButton {
                width: parent.width
                height: 36
                buttonHeight: 36
                minimumWidth: parent.width
                maximumWidth: parent.width
                menuMinimumWidth: Math.max(190, width)
                menuMaximumWidth: Math.max(260, width)
                model: root.diskOptions
                currentValue: root.selectedDevice
                leadingIcon: "hard_drive"
                enabled: root.diskOptions.length > 0
                visible: enabled
                buttonColor: root.leftColor
                buttonHoverColor: Appearance.mix(root.leftColor, root.leftForeground, 0.88)
                buttonPressedColor: Appearance.mix(root.leftColor, root.leftForeground, 0.76)
                buttonTextColor: root.leftForeground
                Accessible.name: qsTr("选择磁盘")
                onValueSelected: (value) => {
                    return root.diskSelected(value);
                }
            }

            Text {
                width: parent.width
                height: 36
                visible: root.diskOptions.length === 0
                text: qsTr("未检测到磁盘")
                color: root.rightForeground
                verticalAlignment: Text.AlignVCenter
                font.family: Fonts.expressive
                font.pixelSize: Typography.titleSmall.pixelSize
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            DiskMetric {
                width: parent.width
                height: (parent.height - 36 - parent.spacing * 2) / 2
                iconName: "input"
                accessibilityLabel: qsTr("读取")
                value: Format.bytesPerSecond(root.disk.readBytesPerSecond)
                accentColor: root.readDataColor
            }

            DiskMetric {
                width: parent.width
                height: (parent.height - 36 - parent.spacing * 2) / 2
                iconName: "output"
                accessibilityLabel: qsTr("写入")
                value: Format.bytesPerSecond(root.disk.writeBytesPerSecond)
                accentColor: root.writeDataColor
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

    component DiskMetric: Item {
        id: metric

        required property string iconName
        required property string accessibilityLabel
        required property string value
        required property color accentColor

        Accessible.name: metric.accessibilityLabel + " " + metric.value

        MaterialSymbol {
            id: metricIcon

            text: metric.iconName
            iconSize: 27
            fill: 1
            color: metric.accentColor
            Accessible.ignored: true

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }

        }

        Text {
            text: metric.value
            color: root.rightForeground
            renderType: Text.NativeRendering
            font.family: Fonts.expressive
            font.pixelSize: 27
            font.weight: Font.Black
            font.variableAxes: root.expressiveBoldAxes
            elide: Text.ElideRight

            anchors {
                left: metricIcon.right
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Appearance.spacing.small
            }

        }

    }

}
