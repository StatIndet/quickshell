import QtQuick
import QtQuick.Layouts
import Clavis.Audio 1.0
import qs.Common

Item {
    id: root

    required property bool sessionActive
    required property bool recording
    required property bool stopping
    required property string sourceNodeName
    required property bool captureSink
    required property double elapsedMs

    property real contentProgress: 0

    signal stopRequested()
    signal collapseRequested()
    signal exitFinished()

    function formatElapsed(milliseconds) {
        const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000));
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        const pad = value => value < 10 ? "0" + value : String(value);
        return hours > 0
            ? pad(hours) + ":" + pad(minutes) + ":" + pad(seconds)
            : pad(minutes) + ":" + pad(seconds);
    }

    function beginEntry() {
        exitSequence.stop();
        entryAnimation.stop();
        root.contentProgress = 0;
        entryAnimation.restart();
    }

    function beginExit() {
        entryAnimation.stop();
        exitSequence.restart();
    }

    AudioLevelProvider {
        id: levelProvider

        active: root.recording && root.sourceNodeName !== ""
        sourceNodeName: root.sourceNodeName
        captureSink: root.captureSink

        onErrorStringChanged: {
            if (errorString !== "")
                console.warn("[AudioLevelProvider]", errorString);
        }
    }

    Item {
        id: contentLayer

        anchors.fill: parent
        opacity: root.contentProgress

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            AudioWaveform {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                active: root.sessionActive
                acceptSamples: root.recording
                sourceAvailable: levelProvider.available
                amplitude: levelProvider.normalizedAmplitude
                sampleTimestampMs: levelProvider.timestampMs
            }

            Text {
                Layout.preferredWidth: 72
                Layout.alignment: Qt.AlignVCenter
                text: root.formatElapsed(root.elapsedMs)
                horizontalAlignment: Text.AlignRight
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }

            AudioStopButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignVCenter
                stopping: root.stopping
                canStop: root.recording
                onStopRequested: root.stopRequested()
            }
        }
    }

    NumberAnimation {
        id: entryAnimation

        target: root
        property: "contentProgress"
        to: 1
        duration: KeystoneMotion.audioContentEnterDuration
        easing.type: KeystoneMotion.type
        easing.bezierCurve: KeystoneMotion.hoverBezier
    }

    SequentialAnimation {
        id: exitSequence

        NumberAnimation {
            target: root
            property: "contentProgress"
            to: 0
            duration: KeystoneMotion.audioContentExitDuration
            easing.type: Appearance.animation.emphasizedAccel.type
            easing.bezierCurve: Appearance.animation.emphasizedAccel.bezierCurve
        }
        ScriptAction {
            script: root.collapseRequested()
        }
        PauseAnimation {
            duration: KeystoneMotion.audioCollapseDuration
        }
        ScriptAction {
            script: root.exitFinished()
        }
    }
}
