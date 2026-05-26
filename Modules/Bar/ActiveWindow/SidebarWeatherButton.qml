import QtQuick
import QtQuick.Layouts
import Clavis.Weather 1.0
import qs.Common
import qs.Widgets.common

Item {
    id: root

    readonly property string temperatureText: WeatherPlugin.hasValidData ? Math.round(WeatherPlugin.currentTemperatureC) + "°" : "--°"
    readonly property int iconSize: 20
    readonly property int temperatureSize: 12
    readonly property int contentSpacing: 6
    readonly property int iconSlotWidth: 24
    readonly property real temperatureSlotWidth: Math.ceil(temperatureMetrics.width)
    readonly property real contentWidth: iconSlotWidth + contentSpacing + temperatureSlotWidth
    readonly property real buttonWidth: contentWidth + 20
    readonly property int buttonHeight: 28

    implicitHeight: buttonHeight
    implicitWidth: buttonWidth
    clip: true

    TextMetrics {
        id: temperatureMetrics
        text: root.temperatureText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.temperatureSize
        font.bold: true
    }

    Rectangle {
        id: background
        anchors.centerIn: parent
        width: root.buttonWidth
        height: root.buttonHeight
        radius: height / 2
        color: Appearance.colors.colTertiaryContainer
        clip: true

        function startRipple(x, y) {
            ripple.centerX = x;
            ripple.centerY = y;
            rippleAnimation.diameter = Math.sqrt(width * width + height * height) * 2.2;
            rippleAnimation.restart();
        }

        Rectangle {
            id: ripple

            property real centerX: background.width / 2
            property real centerY: background.height / 2
            property real diameter: 0

            x: centerX - width / 2
            y: centerY - height / 2
            width: diameter
            height: diameter
            radius: width / 2
            color: Appearance.colors.colOnTertiaryContainer
            opacity: 0
            visible: opacity > 0
        }

        ParallelAnimation {
            id: rippleAnimation

            property real diameter: 0

            NumberAnimation {
                target: ripple
                property: "diameter"
                from: 0
                to: rippleAnimation.diameter
                duration: 700
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: ripple
                property: "opacity"
                from: 0.22
                to: 0
                duration: 700
                easing.type: Easing.OutCubic
            }
        }
    }

    function toggleView() {
        if (WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "weather") {
            WidgetState.leftSidebarOpen = false;
            return;
        }

        WidgetState.leftSidebarView = "weather";
        WidgetState.leftSidebarOpen = true;
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        width: root.contentWidth
        height: root.buttonHeight
        spacing: root.contentSpacing

        Item {
            Layout.preferredWidth: root.iconSlotWidth
            Layout.preferredHeight: root.buttonHeight
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: WeatherPlugin.currentIconName || "cloud"
                font.family: "Material Symbols Rounded"
                font.variableAxes: { "FILL": 0 }
                font.pixelSize: root.iconSize
                color: Appearance.colors.colOnTertiaryContainer

                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        Item {
            Layout.preferredWidth: root.temperatureSlotWidth
            Layout.preferredHeight: root.buttonHeight
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.temperatureText
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: root.temperatureSize
                font.bold: true
                color: Appearance.colors.colOnTertiaryContainer

                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => background.startRipple(mouse.x, mouse.y)
        onClicked: root.toggleView()
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: "天气"
    }
}
