pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Clavis 自己的会话始终优先于外部 niri Cast；屏幕捕获语义保持独立。
    readonly property bool ownScreenSessionPresent: RecordingService.isActive
    readonly property bool ownAudioSessionPresent: AudioRecordingService.isActive
    readonly property bool ownSessionPresent: ownScreenSessionPresent
        || ownAudioSessionPresent
    readonly property bool ownRecordingActive: RecordingService.isRecording
        || AudioRecordingService.isRecording
    readonly property bool externalCapturePresent: ScreencastService.anyCastPresent
    readonly property bool externalCaptureActive: ScreencastService.anyCastActive
    readonly property bool capturePresent: ownScreenSessionPresent
        || externalCapturePresent
    readonly property bool captureActive: RecordingService.isRecording
        || externalCaptureActive
    readonly property string source: ownScreenSessionPresent
        ? "clavis-screen"
        : (ownAudioSessionPresent
            ? "clavis-audio"
            : (externalCapturePresent ? "external" : "none"))
    readonly property string state: ownScreenSessionPresent
        ? RecordingService.state
        : (ownAudioSessionPresent
            ? AudioRecordingService.state
            : (externalCaptureActive ? "capturing" : "idle"))
    readonly property var ownScreenStatusTexts: ({
        "selecting": "正在选择录制区域",
        "starting": "正在启动录制",
        "recording": "正在录制",
        "finalizing": "正在处理录制文件"
    })
    readonly property var ownAudioStatusTexts: ({
        "starting": "正在启动录音",
        "recording": "正在录音",
        "stopping": "正在停止录音",
        "finalizing": "正在完成录音文件"
    })
    readonly property string statusText: ownScreenSessionPresent
        ? (ownScreenStatusTexts[RecordingService.state] || "")
        : (ownAudioSessionPresent
            ? (ownAudioStatusTexts[AudioRecordingService.state] || "")
            : ScreencastService.statusText)
    readonly property bool canStop: RecordingService.isRecording
        || RecordingService.isFinalizing
        || AudioRecordingService.isRecording
}
