import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Components
import "../ControlCenter" as ControlCenter
import "../../Common/functions/SystemFormat.js" as Format

Item {
    id: root

    property var network: ({
    })
    property var aggregateDownloadHistory: []
    property var aggregateUploadHistory: []
    property var downloadHistories: ({
    })
    property var uploadHistories: ({
    })
    property string preferredInterface: ""
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
    readonly property var interfaces: Array.isArray(root.network.interfaces) ? root.network.interfaces : []
    readonly property string defaultInterface: String(root.network.defaultInterface || "")
    readonly property string selectedInterfaceName: root.preferredInterface === "" ? root.defaultInterface : root.preferredInterface
    readonly property var selectedInterface: {
        if (root.preferredInterface === "all")
            return root.network;

        for (let index = 0; index < root.interfaces.length; index += 1) {
            if (String(root.interfaces[index].name || "") === root.selectedInterfaceName)
                return root.interfaces[index];

        }
        return ({
        });
    }
    readonly property var interfaceOptions: {
        const options = [{
            "value": "",
            "label": root.defaultInterface !== "" ? qsTr("默认 · %1").arg(root.defaultInterface) : qsTr("默认")
        }, {
            "value": "all",
            "label": qsTr("总量")
        }];
        const names = [];
        for (let index = 0; index < root.interfaces.length; index += 1) {
            const networkInterface = root.interfaces[index];
            const name = String(networkInterface.name || "");
            if (name !== "" && networkInterface.loopback !== true)
                names.push(name);

        }
        names.sort();
        for (let index = 0; index < names.length; index += 1) {
            options.push({
                "value": names[index],
                "label": names[index]
            });
        }
        return options;
    }
    readonly property var downloadHistory: root.preferredInterface === "all" ? root.aggregateDownloadHistory : root.downloadHistories[root.selectedInterfaceName] || []
    readonly property var uploadHistory: root.preferredInterface === "all" ? root.aggregateUploadHistory : root.uploadHistories[root.selectedInterfaceName] || []
    readonly property real rightPanelX: Math.round(width * 0.53)
    readonly property int chartHistoryLength: 18
    readonly property real chartMaximum: {
        let maximum = 0;
        const series = [root.downloadHistory || [], root.uploadHistory || []];
        for (let seriesIndex = 0; seriesIndex < series.length; seriesIndex += 1) {
            const points = series[seriesIndex];
            const firstVisibleIndex = Math.max(0, points.length - root.chartHistoryLength);
            for (let index = firstVisibleIndex; index < points.length; index += 1) {
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

    signal interfaceSelected(string networkInterface)

    clip: true
    layer.enabled: true
    Accessible.name: qsTr("网络，下载 ") + Format.bytesPerSecond(root.selectedInterface.downloadBytesPerSecond) + qsTr("，上传 ") + Format.bytesPerSecond(root.selectedInterface.uploadBytesPerSecond)

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
        historyLength: root.chartHistoryLength
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
            rightMargin: 0
            topMargin: 46
            bottomMargin: Appearance.spacing.small
        }

    }

    SystemSparkline {
        values: root.downloadHistory
        secondaryValues: root.uploadHistory
        maximum: root.chartMaximum
        historyLength: root.chartHistoryLength
        updateInterval: root.updateInterval
        active: root.chartActive
        showGuideLines: false
        fillArea: true
        fillOpacity: 0.26
        accessibilityName: qsTr("网络近期趋势")
        accessibilityDescription: qsTr("下载 ") + Format.bytesPerSecond(root.selectedInterface.downloadBytesPerSecond) + qsTr("，上传 ") + Format.bytesPerSecond(root.selectedInterface.uploadBytesPerSecond)
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
            rightMargin: 0
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
                model: root.interfaceOptions
                currentValue: root.preferredInterface
                leadingIcon: "lan"
                buttonColor: root.leftColor
                buttonHoverColor: Appearance.mix(root.leftColor, root.leftForeground, 0.88)
                buttonPressedColor: Appearance.mix(root.leftColor, root.leftForeground, 0.76)
                buttonTextColor: root.leftForeground
                Accessible.name: qsTr("选择网络接口")
                onValueSelected: (value) => {
                    return root.interfaceSelected(value);
                }
            }

            NetworkRate {
                width: parent.width
                height: (parent.height - 36 - parent.spacing * 2) / 2
                iconName: "download"
                value: Format.bytesPerSecond(root.selectedInterface.downloadBytesPerSecond)
                accentColor: root.downloadIconColor
            }

            NetworkRate {
                width: parent.width
                height: (parent.height - 36 - parent.spacing * 2) / 2
                iconName: "upload"
                value: Format.bytesPerSecond(root.selectedInterface.uploadBytesPerSecond)
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
