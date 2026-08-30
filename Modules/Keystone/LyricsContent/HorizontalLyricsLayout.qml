import QtQuick
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var lyricsModel
    required property int currentLineIndex
    required property string artUrl
    required property bool active
    required property string status
    required property string errorText
    property int defaultTextWidth: 350
    property int currentTextWidth: defaultTextWidth

    implicitWidth: 102 + currentTextWidth
    implicitHeight: 42

    LyricsAlbumArt {
        id: albumArt

        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        sourceUrl: root.artUrl
    }

    StyledListView {
        id: lyricsView

        anchors.left: albumArt.right
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.currentTextWidth
        interactive: false
        animateAppearance: false
        animateMovement: false
        showVerticalScrollBar: false
        model: root.lyricsModel
        currentIndex: root.currentLineIndex
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: 0
        highlightMoveDuration: 400

        delegate: Item {
            required property var modelData
            required property int index
            readonly property bool isCurrent: index === root.currentLineIndex

            width: ListView.view.width
            height: modelData.translation ? 52 : 42
            onIsCurrentChanged: {
                if (isCurrent)
                    root.currentTextWidth = Math.max(root.defaultTextWidth, Math.min(lyricText.implicitWidth, 800));

            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: modelData.translation ? -4 : 0
                width: parent.width
                spacing: 1

                Text {
                    id: lyricText

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: modelData.text
                    color: Appearance.m3colors.darkmode ? "white" : "black"
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.expressiveFastEffects.duration
                            easing.type: Appearance.animation.expressiveFastEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                        }

                    }

                }

                Text {
                    visible: modelData.translation !== undefined && modelData.translation !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: modelData.translation || ""
                    color: Appearance.applyAlpha(Appearance.m3colors.darkmode ? "white" : "black", 0.6)
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

        }

    }

    Text {
        anchors.centerIn: lyricsView
        width: lyricsView.width - 12
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.65)
        font.family: Fonts.ui
        font.pixelSize: 13
        visible: root.status !== "ready"
        text: root.status === "loading" ? qsTr("正在加载歌词…") : root.status === "error" ? root.errorText || qsTr("歌词加载失败") : qsTr("暂无歌词")
    }

    Item {
        id: spectrum

        property var smoothValues: [0, 0, 0, 0, 0, 0]

        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        width: 21
        height: 16

        Timer {
            interval: 16
            running: root.active && AudioSpectrum.available
            repeat: true
            onTriggered: {
                const values = AudioSpectrum.values;
                if (!values || values.length < 6)
                    return ;

                const ranges = [[0.55, 0.78, 1.5], [0.18, 0.33, 1.2], [0, 0.08, 1], [0.08, 0.18, 1], [0.33, 0.55, 1.2], [0.78, 0.98, 1.5]];
                const next = spectrum.smoothValues.slice();
                for (let index = 0; index < ranges.length; ++index) {
                    const range = ranges[index];
                    const start = Math.floor(values.length * range[0]);
                    const end = Math.min(values.length - 1, Math.floor(values.length * range[1]));
                    let maximum = 0;
                    for (let sample = start; sample <= end; ++sample) maximum = Math.max(maximum, values[sample])
                    const target = Math.min(100, maximum * 100 * range[2]);
                    const difference = target - next[index];
                    next[index] += (difference > 0 ? 0.85 : 0.08) * difference;
                }
                spectrum.smoothValues = next;
                spectrumCanvas.requestPaint();
            }
        }

        Canvas {
            id: spectrumCanvas

            anchors.fill: parent
            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                context.beginPath();
                context.lineCap = "round";
                context.lineWidth = 2.5;
                context.strokeStyle = String(Appearance.colors.colPrimary);
                for (let index = 0; index < 6; ++index) {
                    const amount = Math.min(1, spectrum.smoothValues[index] / 100);
                    const barHeight = Math.max(3, amount * height);
                    const x = 1.25 + index * 3.7;
                    context.moveTo(x, height / 2 - barHeight / 2);
                    context.lineTo(x, height / 2 + barHeight / 2);
                }
                context.stroke();
            }
        }

    }

}
