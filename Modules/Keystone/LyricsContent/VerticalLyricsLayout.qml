import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    required property string lyric
    required property string artUrl
    required property bool active
    required property string edge
    required property string status
    required property string errorText
    readonly property int padding: 15
    readonly property int contentSpacing: 12
    readonly property int tokenSpacing: 3
    readonly property int lyricWidth: 42
    readonly property real lyricExtent: Math.max(20, currentTokens.implicitHeight)

    function isCjk(character) {
        return /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af]/.test(character);
    }

    function isLatinCore(character) {
        return /[A-Za-z0-9]/.test(character);
    }

    function isLatinPunctuation(character) {
        return /['’\-….,!?]/.test(character);
    }

    function tokenize(text) {
        const result = [];
        const source = String(text || "");
        let index = 0;
        while (index < source.length) {
            const character = source[index];
            if (/\s/.test(character)) {
                ++index;
                continue;
            }
            if (isCjk(character)) {
                result.push({
                    "text": character,
                    "latin": false
                });
                ++index;
                continue;
            }
            if (isLatinCore(character)) {
                let token = character;
                ++index;
                while (index < source.length && (isLatinCore(source[index]) || isLatinPunctuation(source[index]))) {
                    token += source[index];
                    ++index;
                }
                result.push({
                    "text": token,
                    "latin": true
                });
                continue;
            }
            result.push({
                "text": character,
                "latin": false
            });
            ++index;
        }
        return result;
    }

    implicitWidth: lyricWidth
    implicitHeight: padding + 26 + contentSpacing + lyricExtent + contentSpacing + 21 + padding

    LyricsAlbumArt {
        id: albumArt

        anchors.top: parent.top
        anchors.topMargin: root.padding
        anchors.horizontalCenter: parent.horizontalCenter
        sourceUrl: root.artUrl
    }

    Item {
        id: lyricSlot

        anchors.top: albumArt.bottom
        anchors.topMargin: root.contentSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.lyricWidth
        height: root.lyricExtent

        TokenColumn {
            id: currentTokens

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            lyricText: root.lyric
        }

        Text {
            anchors.centerIn: parent
            width: root.lyricWidth
            visible: root.status !== "ready"
            text: root.status === "loading" ? qsTr("加载中") : root.status === "error" ? qsTr("失败") : qsTr("暂无")
            color: Appearance.applyAlpha(Appearance.colors.colOnLayer0, 0.65)
            font.family: Fonts.ui
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAnywhere
        }

    }

    Item {
        id: spectrum

        property var smoothValues: [0, 0, 0, 0, 0, 0]

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.padding
        anchors.horizontalCenter: parent.horizontalCenter
        width: 16
        height: 21

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
                    const barWidth = Math.max(3, amount * width);
                    const half = barWidth / 2;
                    const y = 1.25 + index * 3.7;
                    context.moveTo(width / 2 - half, y);
                    context.lineTo(width / 2 + half, y);
                }
                context.stroke();
            }
        }

    }

    component TokenColumn: Column {
        required property string lyricText
        property var tokenModel: root.tokenize(lyricText)

        width: root.lyricWidth
        spacing: root.tokenSpacing

        Repeater {
            model: parent.tokenModel

            delegate: Item {
                required property var modelData
                readonly property bool latin: modelData.latin

                width: root.lyricWidth
                height: latin ? tokenText.implicitWidth : Math.max(18, tokenText.implicitHeight)

                Text {
                    id: tokenText

                    anchors.centerIn: parent
                    text: parent.modelData.text
                    color: Appearance.m3colors.darkmode ? "white" : "black"
                    font.family: Fonts.ui
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    rotation: parent.latin ? (root.edge === "left" ? -90 : 90) : 0
                    horizontalAlignment: Text.AlignHCenter
                }

            }

        }

    }

}
