import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: backendRoot
    
    function pickColor() { colorPickerProcess.running = false; colorPickerProcess.running = true }
    function takeScreenshot() {
        return RegionSelectionService.begin("screenshot", {})
    }

    function startRecord(mode) {
        RecordingService.start(mode, {
            audio: "none",
            fps: 60
        })
    }

    function stopRecord() {
        RecordingService.stop()
    }

    function startAudio(source) {
        return AudioRecordingService.start(source)
    }

    function stopAudio() {
        return AudioRecordingService.stop()
    }

    Connections {
        target: RegionSelectionService

        function onSelectionAccepted(action, geometry, options) {
            if (action !== "screenshot")
                return

            screenshotProcess.command = [
                "bash",
                "-c",
                "grim -g \"$1\" - | wl-copy",
                "clavis-screenshot",
                geometry
            ]
            screenshotProcess.running = true
        }
    }

    // 简单工具依然保持内联
    Process { id: colorPickerProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; hyprpicker -a' >/dev/null 2>&1 &"] }
    Process { id: screenshotProcess }
}
