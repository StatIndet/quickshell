import QtQuick
import Quickshell.Io
import qs.Services

Item {
    id: backendRoot

    function pickColor() {
        colorPickerProcess.running = false;
        colorPickerProcess.running = true;
    }

    function startRecord(mode) {
        RecordingService.start(mode, {
            "audio": "none",
            "fps": 60,
            "output": mode === "gif" ? UiPreferences.recordingGifDirectory : UiPreferences.recordingVideoDirectory
        });
    }

    function stopRecord() {
        RecordingService.stop();
    }

    function startAudio(source) {
        return AudioRecordingService.start(source, {
            "output": source === "system" ? UiPreferences.recordingSystemAudioDirectory : UiPreferences.recordingMicrophoneDirectory
        });
    }

    function stopAudio() {
        return AudioRecordingService.stop();
    }

    Process {
        id: colorPickerProcess

        command: ["hyprpicker", "-a"]
    }

}
