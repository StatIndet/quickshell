import QtQuick
import Clavis.Sysmon 1.0

Item {
    property int count: 0
    property var pModel: SysmonPlugin.processes

    Component.onCompleted: {
        console.log("SUCCESS! Clavis.Sysmon fully loaded with all providers.")
        console.log("Battery present:", SysmonPlugin.hasBattery)
    }

    Connections {
        target: SysmonPlugin
        function onFastDataChanged() {
            count++
            console.log("\n=== Fast Tick [" + count + "] ===")
            console.log("CPU: " + SysmonPlugin.cpuUsage.toFixed(1) + "%")
            console.log("RAM: " + SysmonPlugin.ramUsedGB.toFixed(1) + " / " + SysmonPlugin.ramTotalGB.toFixed(1) + " GB (" + SysmonPlugin.ramUsage.toFixed(1) + "%)")
            console.log("Net: ↓ " + (SysmonPlugin.netDownBps / 1024).toFixed(1) + " KB/s  ↑ " + (SysmonPlugin.netUpBps / 1024).toFixed(1) + " KB/s")
            
            console.log("TOP 5 Processes:")
            for (var i = 0; i < 5; i++) {
                var item = pModel.get(i);
                if (item.name === undefined) break;
                var memMB = (item.memKB / 1024).toFixed(1);
                console.log("  " + (i+1) + " | PID " + item.pid + " | " + item.name + " | CPU: " + item.cpuPercent.toFixed(1) + "% | RAM: " + memMB + " MB | cmd: " + item.cmdline);
            }

            if (count >= 4) {
                Qt.quit()
            }
        }
        function onMediumDataChanged() {
            console.log("\n--- Medium Tick ---")
            console.log("Core Temp: " + SysmonPlugin.coreTemp.toFixed(1) + "°C")
            console.log("GPU Temp: " + SysmonPlugin.gpuTemp.toFixed(1) + "°C | GPU Usage: " + SysmonPlugin.gpuUsage.toFixed(1) + "%")
            console.log("CPU Freq: " + SysmonPlugin.cpuFreqGHz.toFixed(2) + " GHz")
        }
        function onSlowDataChanged() {
            console.log("\n--- Slow Tick ---")
            console.log("Fan: " + SysmonPlugin.fanRpm + " RPM")
            console.log("Battery: " + SysmonPlugin.batteryPercent.toFixed(1) + "% | Status: " + SysmonPlugin.batteryStatus + " | Health: " + SysmonPlugin.batteryHealth + "% | Power: " + SysmonPlugin.batteryPowerW.toFixed(1) + " W")
        }
        function onGlacialDataChanged() {
            console.log("\n--- Glacial Tick ---")
            console.log("Disk: " + SysmonPlugin.diskUsedGB.toFixed(1) + " / " + SysmonPlugin.diskTotalGB.toFixed(1) + " GB (" + SysmonPlugin.diskUsage.toFixed(1) + "%)")
            console.log("Uptime: " + SysmonPlugin.uptime)
        }
    }
}
