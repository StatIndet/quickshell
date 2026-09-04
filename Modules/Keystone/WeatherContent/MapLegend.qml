import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services

Rectangle {
    id: root

    property string providerId: "rainviewer"
    property string mode: "radar"
    property date updatedAt
    property bool stale: false
    property Item backdropSource: null
    readonly property point backdropOrigin: {
        root.x;
        root.y;
        if (!root.backdropSource)
            return Qt.point(0, 0);

        return root.backdropSource.mapFromItem(root, 0, 0);
    }
    readonly property rect backdropRect: Qt.rect(backdropOrigin.x, backdropOrigin.y, width, height)
    property bool backdropLive: true

    function colorsForMode() {
        if (mode === "radar")
            return ["#8ec7ff", "#3f83f8", "#22c55e", "#facc15", "#ef4444"];

        if (mode === "temperature")
            return ["#6e40aa", "#3b82f6", "#55c667", "#fde725", "#ef4444"];

        if (mode === "precipitation")
            return ["#dbeafe", "#93c5fd", "#60a5fa", "#2563eb", "#7c3aed"];

        if (mode === "clouds")
            return ["#eef2f6", "#d9e0e8", "#b9c3cf", "#8e99a6", "#66717f"];

        if (mode === "wind")
            return ["#dbeafe", "#5eead4", "#facc15", "#f97316", "#dc2626"];

        if (mode === "pressure")
            return ["#7c3aed", "#3b82f6", "#22c55e", "#facc15", "#ef4444"];

        return ["#6e40aa", "#3b82f6", "#55c667", "#fde725", "#ef4444"];
    }

    function titleText() {
        if (mode === "radar")
            return qsTr("雷达");

        if (mode === "temperature")
            return qsTr("温度");

        if (mode === "precipitation")
            return qsTr("降水");

        if (mode === "clouds")
            return qsTr("云量");

        if (mode === "wind")
            return qsTr("风速");

        if (mode === "pressure")
            return qsTr("气压");

        return qsTr("天气");
    }

    function minimumLabel() {
        if (mode === "radar")
            return qsTr("小雨");

        if (mode === "temperature")
            return qsTr("低温");

        if (mode === "precipitation")
            return qsTr("少量");

        if (mode === "clouds")
            return qsTr("晴朗");

        if (mode === "wind")
            return qsTr("平静");

        if (mode === "pressure")
            return qsTr("低");

        return "";
    }

    function maximumLabel() {
        if (mode === "radar")
            return qsTr("强降水");

        if (mode === "temperature")
            return qsTr("高温");

        if (mode === "precipitation")
            return qsTr("大量");

        if (mode === "clouds")
            return qsTr("阴天");

        if (mode === "wind")
            return qsTr("强劲");

        if (mode === "pressure")
            return qsTr("高");

        return "";
    }

    function updateText() {
        let value = "";
        if (updatedAt && !isNaN(updatedAt.getTime()))
            value = UiPreferences.shortTime(updatedAt);

        if (stale)
            value = value === "" ? qsTr("缓存") : value + qsTr(" · 缓存");

        return value;
    }

    implicitWidth: 184
    implicitHeight: 70
    radius: Appearance.rounding.normal
    color: "transparent"

    FrostedMapSurface {
        anchors.fill: parent
        z: 0
        sourceItem: root.backdropSource
        sourceRect: root.backdropRect
        backdropLive: root.backdropLive
        radius: root.radius
        blurAmount: 0.64
        tint: Appearance.applyAlpha(Appearance.colors.colScrim, 0.52)
    }

    ColumnLayout {
        anchors.fill: parent
        z: 1
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.titleText()
                color: Appearance.colors.colOnImage
                font.family: Fonts.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                text: root.updateText()
                visible: text !== ""
                color: Appearance.applyAlpha(Appearance.colors.colOnImage, 0.82)
                font.family: Fonts.numeric
                font.pixelSize: 10
                textFormat: Text.PlainText
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            radius: height / 2

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: root.colorsForMode()[0]
                }

                GradientStop {
                    position: 0.25
                    color: root.colorsForMode()[1]
                }

                GradientStop {
                    position: 0.5
                    color: root.colorsForMode()[2]
                }

                GradientStop {
                    position: 0.75
                    color: root.colorsForMode()[3]
                }

                GradientStop {
                    position: 1
                    color: root.colorsForMode()[4]
                }

            }

        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.minimumLabel()
                color: Appearance.colors.colOnImage
                font.family: Fonts.ui
                font.pixelSize: 10
                font.weight: Font.Medium
                textFormat: Text.PlainText
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.maximumLabel()
                color: Appearance.colors.colOnImage
                font.family: Fonts.ui
                font.pixelSize: 10
                font.weight: Font.Medium
                textFormat: Text.PlainText
            }

        }

    }

}
