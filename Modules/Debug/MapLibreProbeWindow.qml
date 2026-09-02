import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Components
import qs.Widgets.common

FloatingWindow {
    id: root

    readonly property string styleUrl: "https://tiles.openfreemap.org/styles/liberty"
    property string loadState: "loading"
    property string failureReason: ""
    property string clickedCoordinate: ""
    property string rendererName: "unknown"
    property bool wasShown: false
    property bool reloadPending: false
    property var styleRequest: null

    signal probeClosed()

    function rendererNameFor(api) {
        switch (api) {
        case GraphicsInfo.Software:
            return "software";
        case GraphicsInfo.OpenGL:
            return "OpenGL";
        case GraphicsInfo.OpenGLRhi:
            return "OpenGL RHI";
        case GraphicsInfo.Vulkan:
        case GraphicsInfo.VulkanRhi:
            return "Vulkan";
        case GraphicsInfo.Metal:
        case GraphicsInfo.MetalRhi:
            return "Metal";
        case GraphicsInfo.Direct3D11:
        case GraphicsInfo.Direct3D11Rhi:
            return "Direct3D 11";
        case GraphicsInfo.Direct3D12:
            return "Direct3D 12";
        case GraphicsInfo.Null:
        case GraphicsInfo.NullRhi:
            return "null";
        default:
            return "unknown (" + api + ")";
        }
    }

    function showWindow() {
        root.wasShown = true;
        root.visible = true;
        if (!mapLoader.active && !root.reloadPending)
            root.reloadMap();

    }

    function dismiss() {
        root.visible = false;
    }

    function reloadMap() {
        if (root.reloadPending)
            return ;

        readyTimeout.stop();
        root.loadState = "loading";
        root.failureReason = "";
        root.clickedCoordinate = "";
        mapLoader.active = false;
        root.reloadPending = true;
        readyTimeout.restart();
        const request = new XMLHttpRequest();
        root.styleRequest = request;
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || root.styleRequest !== request)
                return ;

            root.styleRequest = null;
            root.reloadPending = false;
            if (request.status < 200 || request.status >= 300) {
                root.reportFailure(qsTr("无法加载地图样式"));
                return ;
            }
            try {
                JSON.parse(request.responseText);
            } catch (error) {
                root.reportFailure(qsTr("地图样式无效"));
                return ;
            }
            mapLoader.setSource(Qt.resolvedUrl("MapLibreProbeMap.qml"), {
                "styleUrl": root.styleUrl
            });
            mapLoader.active = true;
        };
        request.open("GET", root.styleUrl);
        request.send();
    }

    function reportReady() {
        readyTimeout.stop();
        root.loadState = "ready";
        console.info("MapLibre probe ready; renderer=" + root.rendererName + "; style=" + root.styleUrl);
    }

    function reportFailure(message) {
        readyTimeout.stop();
        root.loadState = "failed";
        root.failureReason = message || qsTr("地图加载失败");
        console.warn("MapLibre probe failed; renderer=" + root.rendererName + "; reason=" + root.failureReason);
    }

    function probeStatus() {
        return root.loadState.toUpperCase() + "; renderer=" + root.rendererName + (root.failureReason.length > 0 ? "; error=" + root.failureReason : "");
    }

    visible: false
    title: "clavis-maplibre-probe"
    implicitWidth: 920
    implicitHeight: 640
    minimumSize: Qt.size(560, 420)
    color: "transparent"
    Material.theme: Appearance.m3colors.darkmode ? Material.Dark : Material.Light
    Material.accent: Appearance.colors.colPrimary
    onClosed: root.dismiss()
    onVisibleChanged: {
        if (!visible && wasShown) {
            wasShown = false;
            probeClosed();
        }
    }
    Component.onCompleted: {
        root.rendererName = root.rendererNameFor(mapFrame.graphicsApi);
        console.info("MapLibre probe created; renderer=" + root.rendererName);
    }

    Timer {
        id: readyTimeout

        interval: 15000
        repeat: false
        onTriggered: root.reportFailure(qsTr("地图加载超时"))
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.extraLarge
        color: Appearance.colors.colLayer0Base
        border.width: Metrics.dividerWidth
        border.color: Appearance.colors.colOutlineVariant
    }

    FocusScope {
        anchors.fill: parent
        anchors.margins: Metrics.spacingM
        focus: root.visible
        Keys.onEscapePressed: (event) => {
            root.dismiss();
            event.accepted = true;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Metrics.spacingM

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingM

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("OpenFreeMap Liberty")
                        color: Appearance.colors.colOnLayer0
                        font.family: Typography.titleLarge.family
                        font.pixelSize: Typography.titleLarge.pixelSize
                        font.weight: Typography.titleLarge.weight
                    }

                    Text {
                        text: qsTr("MapLibre Probe · %1").arg(root.rendererName)
                        color: Appearance.colors.colSubtext
                        font.family: Typography.bodySmall.family
                        font.pixelSize: Typography.bodySmall.pixelSize
                    }

                }

                IconButton {
                    iconName: "refresh"
                    accessibleName: qsTr("重新加载地图")
                    onClicked: root.reloadMap()
                }

                IconButton {
                    iconName: "close"
                    accessibleName: qsTr("关闭")
                    onClicked: root.dismiss()
                }

            }

            Rectangle {
                id: mapFrame

                readonly property int graphicsApi: GraphicsInfo.api

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.large
                color: Appearance.colors.colSurfaceContainerHigh
                clip: true
                onGraphicsApiChanged: root.rendererName = root.rendererNameFor(graphicsApi)

                Loader {
                    id: mapLoader

                    anchors.fill: parent
                    active: false
                    onStatusChanged: {
                        if (status === Loader.Error) {
                            root.reportFailure(qsTr("无法创建 MapLibre 地图"));
                        } else if (status === Loader.Ready && item) {
                            item.mapReady.connect(root.reportReady);
                            item.mapFailed.connect(root.reportFailure);
                            item.coordinateClicked.connect((coordinate) => {
                                root.clickedCoordinate = coordinate;
                            });
                            if (item.ready)
                                root.reportReady();
                            else if (item.errorString.length > 0)
                                root.reportFailure(item.errorString);
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.loadState !== "ready"
                    color: Appearance.colors.colSurfaceContainerHigh

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Metrics.spacingM

                        MaterialLoadingIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.loadState === "loading"
                            running: visible
                        }

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.loadState === "failed"
                            text: "map"
                            iconSize: 48
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.loadState === "failed"
                            text: root.failureReason.length > 0 ? root.failureReason : qsTr("地图加载失败")
                            color: Appearance.colors.colOnSurface
                            font.family: Typography.bodyLarge.family
                            font.pixelSize: Typography.bodyLarge.pixelSize
                        }

                        ActionButton {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.loadState === "failed"
                            text: qsTr("重试")
                            iconName: "refresh"
                            filled: true
                            onClicked: root.reloadMap()
                        }

                    }

                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Metrics.spacingM
                    visible: root.clickedCoordinate.length > 0
                    width: clickedText.implicitWidth + Metrics.spacingM * 2
                    height: clickedText.implicitHeight + Metrics.spacingS * 2
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSurfaceContainerHighest

                    Text {
                        id: clickedText

                        anchors.centerIn: parent
                        text: qsTr("Clicked: %1").arg(root.clickedCoordinate)
                        color: Appearance.colors.colOnSurface
                        font.family: Typography.labelMedium.family
                        font.pixelSize: Typography.labelMedium.pixelSize
                    }

                }

            }

        }

    }

}
