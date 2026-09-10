pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // The coordinator only describes Clavis-owned recording sessions.
    readonly property bool ownScreenSessionPresent: RecordingService.isActive
    readonly property bool ownAudioSessionPresent: AudioRecordingService.isActive
    readonly property bool ownSessionPresent: ownScreenSessionPresent || ownAudioSessionPresent
    readonly property bool ownRecordingActive: RecordingService.isRecording
                                               || AudioRecordingService.isRecording
    readonly property bool capturePresent: ownSessionPresent
    readonly property bool captureActive: ownRecordingActive
    readonly property string source: ownScreenSessionPresent ? "clavis-screen" : (ownAudioSessionPresent
                                                                                  ? "clavis-audio" : "none")
    readonly property string state: ownScreenSessionPresent ? RecordingService.state : (
                                                                  ownAudioSessionPresent
                                                                  ? AudioRecordingService.state : "idle")
    readonly property var ownScreenStatusTexts: ({
                                                     "selecting": qsTr("Selecting recording region"),
                                                     "starting": qsTr("Starting recording"),
                                                     "recording": qsTr("Recording"),
                                                     "paused": qsTr("Recording"),
                                                     "stopping": qsTr("Processing recording"),
                                                     "finalizing": qsTr("Processing recording")
                                                 })
    readonly property var ownAudioStatusTexts: ({
                                                    "starting": qsTr("Starting audio recording"),
                                                    "recording": qsTr("Recording audio"),
                                                    "stopping": qsTr("Stopping audio recording"),
                                                    "finalizing": qsTr("Finishing audio recording")
                                                })
    readonly property string statusText: ownScreenSessionPresent ? (
                                                                       ownScreenStatusTexts[RecordingService.state]
                                                                       || "") : (ownAudioSessionPresent ? (
                                                                                                              ownAudioStatusTexts[AudioRecordingService.state]
                                                                                                              || "") : "")
    readonly property bool canStop: (RecordingService.isRecording || RecordingService.state === "paused") &&
                                    !RecordingService.isStopPending || AudioRecordingService.isRecording
}
