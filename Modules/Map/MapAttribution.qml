import QtQuick
import qs.Common

Rectangle {
    id: root

    property string baseProvider: "openfreemap"
    property string overlayProvider: ""
    readonly property real logoSpace: baseProvider === "maptiler" ? 96 : 0

    function credit(url, label) {
        return '<a href="' + url + '" style="color:#111111;text-decoration:none">' + label + '</a>';
    }

    implicitWidth: attribution.implicitWidth + logoSpace + 2 * Metrics.spacingS
    implicitHeight: Math.max(attribution.height, logo.visible ? logo.height : 0) + 2 * Metrics.spacingXS
    radius: Metrics.spacingS
    color: "#DDEEEEEE"

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    Image {
        id: logo

        x: Metrics.spacingS
        anchors.verticalCenter: parent.verticalCenter
        width: 88
        height: 24
        visible: root.baseProvider === "maptiler"
        source: visible ? Qt.resolvedUrl("../../assets/map-attribution/maptiler.svg") : ""
        fillMode: Image.PreserveAspectFit
        Accessible.role: Accessible.Link
        Accessible.name: "MapTiler"
        Accessible.onPressAction: Qt.openUrlExternally("https://www.maptiler.com/")

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("https://www.maptiler.com/")
        }
    }

    Text {
        id: attribution

        x: Metrics.spacingS + root.logoSpace
        y: Metrics.spacingXS
        width: root.width - root.logoSpace - 2 * Metrics.spacingS
        text: (root.baseProvider === "maptiler" ? root.credit("https://www.maptiler.com/copyright/",
                                                              "© MapTiler") : root.credit(
                                                      "https://openfreemap.org/", "OpenFreeMap") + " · "
                                                  + root.credit("https://openmaptiles.org/",
                                                                "© OpenMapTiles")) + " · " + root.credit(
                  "https://www.openstreetmap.org/copyright", "© OpenStreetMap") + (root.overlayProvider
                                                                                   === "rainviewer" ? " · "
                                                                                                      + root.credit(
                                                                                                          "https://www.rainviewer.com/",
                                                                                                          "© RainViewer") :
                                                                                                      root.overlayProvider
                                                                                                      === "openweather"
                                                                                                      ? " · " + root.credit(
                                                                                                            "https://openweathermap.org/",
                                                                                                            "© OpenWeather") :
                                                                                                        "")
        textFormat: Text.RichText
        color: "#FF111111"
        font.family: Typography.labelSmall.family
        font.pixelSize: Typography.labelSmall.pixelSize
        wrapMode: Text.Wrap
        onLinkActivated: link => Qt.openUrlExternally(link)

        HoverHandler {
            cursorShape: attribution.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }
}
