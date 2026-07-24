import QtQuick
import QtQuick.Layouts
import M3Shapes
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string label: ""
    property string iconName: "monitoring"
    property string valueText: "—"
    property string supportingText: ""
    property string detailText: ""
    property string temperatureText: ""
    property real usage: -1
    property int shapeOverride: -999
    property var trendValues: []
    property bool chartActive: visible
    property int updateInterval: 1000
    property real decorationSize: 70
    property real valueSize: Sizes.typeDisplaySmall
    property color containerColor: Appearance.colors.colPrimaryContainer
    property color foregroundColor: Appearance.colors.colOnPrimaryContainer
    property color accentColor: Appearance.colors.colPrimary
    property color accentForegroundColor: Appearance.colors.colOnPrimary

    readonly property real normalizedUsage: Math.max(
        0,
        Math.min(1, root.usage)
    )
    readonly property bool dense:
        root.width < 210 || root.height < 190
    readonly property int resolvedShape: {
        if (root.shapeOverride !== -999)
            return root.shapeOverride;
        if (root.usage < 0)
            return MaterialShape.Cookie4Sided;
        if (root.normalizedUsage >= 0.82)
            return MaterialShape.SoftBurst;
        if (root.normalizedUsage >= 0.48)
            return MaterialShape.Sunny;
        return MaterialShape.Cookie4Sided;
    }

    radius: Appearance.rounding.extraLarge
    color: root.containerColor
    clip: true
    Accessible.name: [
        root.label,
        root.valueText,
        root.detailText,
        root.supportingText,
        root.temperatureText
    ].filter(function(value) {
        return String(value || "").length > 0;
    }).join("，")

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.expressiveEffects.duration
            easing.type: Appearance.animation.expressiveEffects.type
            easing.bezierCurve:
                Appearance.animation.expressiveEffects.bezierCurve
        }
    }

    MaterialShape {
        id: metricShape

        anchors {
            top: parent.top
            right: parent.right
            margins: Appearance.spacing.small
        }
        implicitSize: Math.min(
            root.width * 0.38,
            root.height * 0.42,
            root.decorationSize
                * (0.9 + root.normalizedUsage * 0.14)
        )
        shape: root.resolvedShape
        color: root.accentColor
        animationDuration:
            Appearance.animation.expressiveSlowSpatial.duration
        animationEasing: Easing.OutBack
        z: 4
        Accessible.name: root.label + " 图标"

        Behavior on implicitSize {
            NumberAnimation {
                duration:
                    Appearance.animation.expressiveSlowSpatial.duration
                easing.type:
                    Appearance.animation.expressiveSlowSpatial.type
                easing.bezierCurve:
                    Appearance.animation.expressiveSlowSpatial.bezierCurve
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: root.iconName
            color: root.accentForegroundColor
            iconSize: root.dense ? 21 : 25
            fill: 1
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.dense
                ? Appearance.spacing.small
                : Appearance.spacing.medium
        }
        spacing: root.dense ? 2 : Appearance.spacing.xSmall

        Text {
            Layout.maximumWidth: Math.max(
                48,
                root.width - root.decorationSize
                    - Appearance.spacing.large
            )
            text: root.label
            color: root.foregroundColor
            font.family: Sizes.fontFamily
            font.pixelSize: root.dense
                ? Sizes.typeTitleMedium + 2
                : Sizes.typeTitleLarge
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        Text {
            Layout.maximumWidth: Math.max(
                48,
                root.width - root.decorationSize
                    - Appearance.spacing.large
            )
            visible: !root.dense && text.length > 0
            text: root.detailText
            color: root.foregroundColor
            opacity: 0.72
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeLabelSmall
            elide: Text.ElideRight
        }

        SystemSparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.dense
                ? Appearance.spacing.xSmall
                : 0
            Layout.minimumHeight: visible
                ? (root.dense ? 30 : 34)
                : 0
            visible: root.trendValues.length > 1
                && root.height >= 112
            values: root.trendValues
            historyLength: 60
            updateInterval: root.updateInterval
            maximum: 0
            scaleHeadroom: 1.2
            showGuideLines: false
            active: root.chartActive && visible
            accessibilityName: root.label + " 最近一分钟趋势"
            accessibilityDescription:
                "当前值 " + root.valueText
            lineColor: root.accentColor
            baselineColor: Appearance.applyAlpha(
                root.foregroundColor,
                0.2
            )
            lineWidth: 2.2
            fillOpacity: 0.12
        }

        Item {
            Layout.fillHeight: true
            visible: root.trendValues.length <= 1
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.xSmall

            Text {
                Layout.fillWidth: true
                text: root.valueText
                color: root.foregroundColor
                font.family: Sizes.fontFamilyMono
                font.pixelSize: root.valueSize
                font.weight: Font.Bold
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration:
                            Appearance.animation.expressiveEffects.duration
                    }
                }
            }

            RowLayout {
                visible: root.temperatureText.length > 0
                spacing: 2

                MaterialSymbol {
                    text: "thermostat"
                    color: root.foregroundColor
                    iconSize: Sizes.typeLabelMedium
                    fill: 1
                    opacity: 0.74
                }

                Text {
                    text: root.temperatureText
                    color: root.foregroundColor
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.typeLabelMedium
                    font.weight: Font.DemiBold
                    opacity: 0.78
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !root.dense && text.length > 0
            text: root.supportingText
            color: root.foregroundColor
            opacity: 0.74
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeBodySmall
            elide: Text.ElideRight
        }
    }

}
