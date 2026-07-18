import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: backendRoot
    
    function pickColor() { colorPickerProcess.running = false; colorPickerProcess.running = true }
    function takeScreenshot() { screenshotProcess.running = false; screenshotProcess.running = true }

    function startRecord(mode) {
        RecordingService.start(mode, {
            audio: "none",
            fps: 60
        })
    }

    function stopRecord() {
        RecordingService.stop()
    }

    // ================= 【录音控制后端】 =================
    // 接收 mode 参数 (audio_mic 或 audio_sys)
    function startAudio(mode) {
        startAudioProcess.command = ["bash", "-c", "nohup bash \"" + Paths.scriptPath("capture", "record.sh") + "\" start " + mode + " >/dev/null 2>&1 &"]
        startAudioProcess.running = false
        startAudioProcess.running = true
    }

    // 停止时统一传 audio
    function stopAudio() {
        stopAudioProcess.command = ["bash", "-c", "nohup bash \"" + Paths.scriptPath("capture", "record.sh") + "\" stop audio >/dev/null 2>&1 &"]
        stopAudioProcess.running = false
        stopAudioProcess.running = true
    }

    // 简单工具依然保持内联
    Process { id: colorPickerProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; hyprpicker -a' >/dev/null 2>&1 &"] }
    Process { id: screenshotProcess; command: ["bash", "-c", "nohup bash -c 'sleep 0.3; grim -g \"$(slurp)\" - | wl-copy' >/dev/null 2>&1 &"] }
    
    // 【新增：录音专用的 Process 节点】
    Process { id: startAudioProcess }
    Process { id: stopAudioProcess }
}
