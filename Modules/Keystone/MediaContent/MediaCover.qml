import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common

Item {
    id: root

    required property string artUrl
    required property bool playing
    required property bool caelestia
    required property color accentColor
    property bool active: visible

    Loader {
        anchors.fill: parent
        sourceComponent: root.caelestia ? caelestiaCover : roundedCover
    }

    Component {
        id: caelestiaCover
        CaelestiaCover {
            artUrl: root.artUrl
            playing: root.playing
            active: root.active
            accentColor: root.accentColor
        }
    }

    Component {
        id: roundedCover
        Item {
            id: roundedWrapper
            anchors.centerIn: parent
            width: root.width
            height: width
            Item {
                id: coverContainer
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Appearance.colors.colLayer3
                    visible: rawImg.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: "music_note"
                        color: Appearance.colors.colOnLayer3
                        font.family: Fonts.materialSymbolsOutlined
                        font.pixelSize: parent.width * 0.47
                    }
                }

                Image {
                    id: rawImg
                    anchors.fill: parent
                    source: root.artUrl
                    sourceSize: Qt.size(240, 240)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: 12
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: rawImg
                    maskSource: maskRect
                    visible: rawImg.status === Image.Ready
                }
            }
        }
    }
}
