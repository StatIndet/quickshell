import QtQuick
import QtQuick.Shapes
import M3Shapes
import qs.Common

WeatherInsightCard {
    id: root

    property real directionDegrees: 0
    property string valueText: "--"
    property string detailText: ""
    property color accent: "#4d8d7b"
    property bool animationEnabled: false
    property bool animationActive: true

    readonly property var parsedSpeed: parseSpeedText(valueText)
    readonly property string displaySpeed: parsedSpeed.number
    readonly property string displayUnit: parsedSpeed.unit
    readonly property string displayDetail: normalizedDetail(detailText)
    readonly property var parsedDetail: parseAnimatedDetail(displayDetail)
    readonly property real speedValue: displaySpeed === "--" ? NaN : Number(displaySpeed)
    readonly property real gustValue: parsedDetail.valid ? parsedDetail.value : NaN
    readonly property bool hasDirection: directionDegrees >= 0 && directionDegrees <= 360
    readonly property color ink: Appearance.colors.colOnWeatherCardSurface
    readonly property color mutedInk: Appearance.colors.colOnWeatherCardSurfaceVariant
    readonly property color arrowTint: Appearance.applyAlpha(Appearance.colors.colOnWeatherCardSurfaceVariant,
                                                             0.18)
    readonly property real speedNumberSize: Math.round(width * 0.27)
    readonly property real speedUnitSize: Math.round(width * 0.115)

    icon: ""
    title: ""
    shapeId: MaterialShape.Circle
    radius: Math.round(Math.min(width, height) / 2)
    shapeColor: Appearance.colors.colWeatherCardSurface

    function compactNumber(value) {
        if (value.indexOf(".") < 0)
            return value;
        return value.replace(/\.0+$/, "").replace(/(\.\d*[1-9])0+$/, "$1");
    }

    function parseSpeedText(text) {
        const source = (text || "").trim();
        if (source.length === 0 || source === "--")
            return {
                number: "--",
                unit: ""
            };

        const match = source.match(/^([-+]?\d+(?:\.\d+)?)\s*([A-Za-z/%°]+)?$/);
        if (!match)
            return {
                number: source,
                unit: ""
            };

        return {
            number: compactNumber(match[1]),
            unit: match[2] || ""
        };
    }

    function normalizedDetail(text) {
        let label = (text || "").trim();
        if (label.length === 0)
            return "";

        if (label.indexOf("·") >= 0)
            label = label.split("·")[0].trim();

        if (label.startsWith(qsTr("Gusts "))) {
            label = qsTr("Gusts:") + label.slice(2).trim();
        } else if (label.startsWith(qsTr("Gusts:"))) {
            label = qsTr("Gusts:") + label.slice(3).trim();
        }

        label = label.replace(/(\d)\.0(\s|$)/g, "$1$2");
        return label;
    }

    function parseAnimatedDetail(text) {
        const match = (text || "").match(/^([^-\d]*)([-+]?\d+(?:\.\d+)?)(.*)$/);
        if (!match)
            return {
                valid: false,
                prefix: "",
                value: NaN,
                decimals: 0,
                suffix: text || ""
            };

        const decimalIndex = match[2].indexOf(".");
        return {
            valid: true,
            prefix: match[1],
            value: Number(match[2]),
            decimals: decimalIndex >= 0 ? match[2].length - decimalIndex - 1 : 0,
            suffix: match[3]
        };
    }

    function animatedSpeedText() {
        if (isNaN(speedAnimation.currentValue))
            return "--";

        const decimalIndex = root.displaySpeed.indexOf(".");
        const decimals = decimalIndex >= 0 ? root.displaySpeed.length - decimalIndex - 1 : 0;
        return compactNumber(Number(speedAnimation.currentValue).toFixed(decimals));
    }

    function animatedDetailText() {
        if (!root.parsedDetail.valid || isNaN(gustAnimation.currentValue))
            return root.displayDetail;

        const number = compactNumber(Number(gustAnimation.currentValue).toFixed(root.parsedDetail.decimals));
        return root.parsedDetail.prefix + number + root.parsedDetail.suffix;
    }

    WeatherAnimatedValue {
        id: speedAnimation
        targetValue: root.speedValue
        enabled: root.animationEnabled
        active: root.animationActive
    }

    WeatherAnimatedValue {
        id: gustAnimation
        targetValue: root.gustValue
        enabled: root.animationEnabled
        active: root.animationActive
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 28
        spacing: 8
        z: 2

        Item {
            width: 28
            height: 28

            Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: root.mutedInk

                    PathSvg {
                        path: "M12,23H11V16.43C9.93,17.4 8.5,18 7,18C3.75,18 1,15.25 1,12V11H7.57C6.6,9.93 6,8.5 6,7C6,3.75 8.75,1 12,1H13V7.57C14.07,6.6 15.5,6 17,6C20.25,6 23,8.75 23,12V13H16.43C17.4,14.07 18,15.5 18,17C18,20.25 15.25,23 12,23M13,13.13V20.87C14.7,20.41 16,18.83 16,17C16,15.17 14.7,13.59 13,13.13M3.13,13C3.59,14.7 5.17,16 7,16C8.83,16 10.41,14.7 10.87,13H3.13M13.13,11H20.87C20.41,9.3 18.82,8 17,8C15.18,8 13.59,9.3 13.13,11M11,3.13C9.3,3.59 8,5.18 8,7C8,8.82 9.3,10.41 11,10.87V3.13Z"
                    }
                }
            }
        }

        Text {
            text: qsTr("Wind")
            color: root.mutedInk
            font.family: Fonts.expressive
            font.pixelSize: 18
            font.bold: true
        }
    }

    Item {
        id: arrowLayer
        width: 176
        height: 176
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 4
        scale: Math.min((parent.width * 0.90) / width, (parent.height * 0.90) / height)
        rotation: root.hasDirection ? root.directionDegrees : 0
        opacity: 0.96
        z: 0

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: root.arrowTint

                PathSvg {
                    path: root.hasDirection
                          ? "M108.04,151.24C99.97,168.05 76.03,168.05 67.96,151.24L27.21,66.3C18.79,48.75 35.4,29.63 53.96,35.5L81.29,44.15C85.66,45.54 90.34,45.54 94.71,44.15L122.04,35.5C140.6,29.63 157.21,48.75 148.79,66.3L108.04,151.24Z" :
                            "m88,164.15q-14.17,0 -26.65,-5.31 -12.48,-5.31 -21.78,-14.61 -9.3,-9.3 -14.61,-21.69 -5.31,-12.4 -5.31,-26.74 0,-3.54 2.39,-5.93 2.39,-2.39 5.93,-2.39 3.54,0 5.93,2.39 2.39,2.39 2.39,5.93 0,21.6 15.14,36.57 15.14,14.96 36.57,14.96 21.43,0 36.57,-15.05 15.14,-15.05 15.14,-36.48 0,-21.6 -14.7,-36.57Q110.31,44.26 88.71,44.26h-3.9l7.44,7.44q1.95,1.95 1.95,4.43 0,2.48 -1.95,4.43Q90.3,62.5 87.73,62.41 85.17,62.32 83.22,60.38L64.27,41.43q-2.66,-2.48 -2.66,-5.93 0,-3.45 2.66,-5.93L83.4,10.26q1.77,-1.59 4.43,-1.68 2.66,-0.09 4.43,1.68 1.77,1.77 1.68,4.52 -0.09,2.74 -1.86,4.34l-8.32,8.32h4.07q14.34,0 26.83,5.31 12.48,5.31 21.78,14.61 9.3,9.3 14.61,21.69 5.31,12.4 5.31,26.74 0,14.17 -5.31,26.65 -5.31,12.48 -14.61,21.78 -9.3,9.3 -21.78,14.61 -12.48,5.31 -26.65,5.31z"
                }
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 58
        anchors.bottomMargin: 34
        z: 2

        Item {
            id: speedGroup
            width: speedNumber.implicitWidth + (speedUnit.visible ? 6 + speedUnit.implicitWidth : 0)
            height: Math.max(speedNumber.implicitHeight, speedUnit.visible ? speedUnit.implicitHeight + 8 : 0)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -8

            Text {
                id: speedNumber
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: root.animatedSpeedText()
                color: root.ink
                font.family: Fonts.expressive
                font.pixelSize: root.speedNumberSize
                font.weight: Font.Light
            }

            Text {
                id: speedUnit
                anchors.left: speedNumber.right
                anchors.leftMargin: 6
                anchors.bottom: speedNumber.bottom
                anchors.bottomMargin: 5
                visible: root.displayUnit.length > 0
                text: root.displayUnit
                color: root.ink
                font.family: Fonts.expressive
                font.pixelSize: root.speedUnitSize
                font.weight: Font.Normal
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        width: parent.width * 0.74
        horizontalAlignment: Text.AlignHCenter
        text: root.animatedDetailText()
        color: root.ink
        font.family: Fonts.expressive
        font.pixelSize: 14
        font.bold: true
        elide: Text.ElideRight
        z: 2
    }
}
