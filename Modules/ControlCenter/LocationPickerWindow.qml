import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Modules.Map
import qs.Widgets.common

FloatingWindow {
    id: root

    property var parentModal: null
    property real centerLatitude: 0
    property real centerLongitude: 0
    property real markerLatitude: 0
    property real markerLongitude: 0
    property real zoomLevel: 12
    property real bearing: 0
    property string viewMode: "2d"

    signal cameraChanged(real latitude, real longitude, real zoom, real bearing)
    signal saveRequested()
    signal dismissed()

    function showWindow() {
        if (!root.parentModal)
            return ;

        root.visible = true;
    }

    function dismiss() {
        root.visible = false;
        root.dismissed();
    }

    visible: false
    parentWindow: root.parentModal
    title: qsTr("选择天气位置")
    implicitWidth: 920
    implicitHeight: 680
    minimumSize: Qt.size(600, 440)
    color: "transparent"
    Material.theme: Appearance.m3colors.darkmode ? Material.Dark : Material.Light
    Material.accent: Appearance.colors.colPrimary
    onClosed: root.dismiss()

    Rectangle {
        id: mapFrame

        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: Appearance.colors.colLayer0Base
        clip: true
        layer.enabled: true
        layer.samples: 4

        MapLibreView {
            id: map

            anchors.fill: parent
            active: root.visible
            styleUrl: "https://tiles.openfreemap.org/styles/liberty"
            centerLatitude: root.centerLatitude
            centerLongitude: root.centerLongitude
            markerVisible: false
            zoomLevel: root.zoomLevel
            bearing: root.viewMode === "3d" ? root.bearing : 0
            tilt: root.viewMode === "3d" ? 50 : 0
            onCameraMoved: (latitudeValue, longitudeValue, zoom, bearingValue, tiltValue) => {
                root.zoomLevel = zoom;
                root.centerLatitude = latitudeValue;
                root.centerLongitude = longitudeValue;
                if (root.viewMode === "3d")
                    root.bearing = bearingValue;

                root.cameraChanged(latitudeValue, longitudeValue, zoom, bearingValue);
            }
        }

        MapCenterPin {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - height + 3
            z: 3
        }

        StyledButtonGroup {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Metrics.spacingL
            model: [{
                "value": "2d",
                "label": "2D"
            }, {
                "value": "3d",
                "label": "3D"
            }]
            currentValue: root.viewMode
            buttonMinWidth: 58
            onValueSelected: (value) => {
                return root.viewMode = value;
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Metrics.spacingL

            IconButton {
                iconName: "my_location"
                accessibleName: qsTr("回到已选位置")
                variant: "filled"
                normalContainerColor: "#D9111111"
                iconColor: "white"
                onClicked: map.recenter(root.markerLatitude, root.markerLongitude, root.zoomLevel)
            }

            IconButton {
                iconName: "close"
                accessibleName: qsTr("关闭")
                variant: "filled"
                normalContainerColor: "#D9111111"
                iconColor: "white"
                onClicked: root.dismiss()
            }

        }

        ActionButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Metrics.spacingL
            text: qsTr("保存位置")
            iconName: "save"
            onClicked: root.saveRequested()
        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Metrics.spacingL
            implicitWidth: coordinateLabel.implicitWidth + Metrics.spacingL * 2
            implicitHeight: Metrics.controlHeightM
            radius: Appearance.rounding.full
            color: "#D9111111"

            Text {
                id: coordinateLabel

                anchors.centerIn: parent
                text: Number(root.centerLatitude).toFixed(6) + ", " + Number(root.centerLongitude).toFixed(6)
                color: "white"
                font.family: Typography.labelMedium.family
                font.pixelSize: Typography.labelMedium.pixelSize
            }

        }

        FocusScope {
            anchors.fill: parent
            focus: root.visible
            Keys.onEscapePressed: (event) => {
                root.dismiss();
                event.accepted = true;
            }
        }

        layer.effect: OpacityMask {

            maskSource: Rectangle {
                width: mapFrame.width
                height: mapFrame.height
                radius: mapFrame.radius
            }

        }

    }

}
