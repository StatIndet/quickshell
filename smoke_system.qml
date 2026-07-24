import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "Modules/Sidebars/Left"

// Repeatable visual/data smoke:
//   CLAVIS_KEY="$PWD/core/build/bin/key" qs -p ./smoke_system.qml
ApplicationWindow {
    id: smoke

    readonly property bool testOpenTop:
        Quickshell.env("CLAVIS_SMOKE_OPEN_TOP") === "1"
    readonly property bool expectServiceError:
        Quickshell.env("CLAVIS_SMOKE_EXPECT_ERROR") === "1"
    readonly property bool testLifecycle:
        Quickshell.env("CLAVIS_SMOKE_LIFECYCLE") === "1"
    readonly property string testThemeMode:
        String(Quickshell.env("CLAVIS_SMOKE_THEME_MODE") || "").toLowerCase()
    readonly property string testColorsPath:
        String(Quickshell.env("CLAVIS_SMOKE_COLORS_PATH") || "").trim()
    readonly property int requestedDurationMs: {
        const value = Number(
            Quickshell.env("CLAVIS_SMOKE_DURATION_MS") || 0
        );
        return isFinite(value) && value >= 1000
            ? Math.round(value)
            : 5000;
    }
    readonly property int requestedHeight: {
        const value = Number(
            Quickshell.env("CLAVIS_SMOKE_HEIGHT") || 0
        );
        return isFinite(value) && value >= 480
            ? Math.round(value)
            : 900;
    }
    property bool observedLifecycleStop: false

    visible: true
    width: 540
    height: requestedHeight
    color: Appearance.m3colors.m3background
    Material.theme: Appearance.m3colors.darkmode
        ? Material.Dark
        : Material.Light

    Component.onCompleted: {
        if (smoke.testThemeMode === "light"
                || smoke.testThemeMode === "dark") {
            Appearance.matugenMode = smoke.testThemeMode;
        }
        WidgetState.leftSidebarView = "sys";
        WidgetState.leftSidebarOpen = true;
    }

    SystemView {
        anchors.fill: parent
    }

    FileView {
        path: smoke.testColorsPath
        onLoaded: {
            if (smoke.testColorsPath.length > 0)
                Appearance.applyGeneratedColors(this.text());
        }
    }

    Timer {
        interval: 2500
        running: smoke.testOpenTop
        repeat: false
        onTriggered: SystemMonitorService.openFullMonitor()
    }

    Timer {
        interval: 1500
        running: smoke.testLifecycle
        repeat: false
        onTriggered: WidgetState.leftSidebarView = "info"
    }

    Timer {
        interval: 2200
        running: smoke.testLifecycle
        repeat: false
        onTriggered: {
            smoke.observedLifecycleStop =
                !SystemMonitorService.processRunning;
            WidgetState.leftSidebarView = "weather";
        }
    }

    Timer {
        interval: 2800
        running: smoke.testLifecycle
        repeat: false
        onTriggered: WidgetState.leftSidebarView = "sys"
    }

    Timer {
        interval: smoke.testLifecycle
            ? Math.max(6500, smoke.requestedDurationMs)
            : smoke.requestedDurationMs
        running: true
        repeat: false

        onTriggered: {
            const passed = smoke.expectServiceError
                ? (!SystemMonitorService.hasData
                    && (SystemMonitorService.error
                        || SystemMonitorService.reconnecting)
                    && SystemMonitorService.errorMessage.length > 0)
                : (SystemMonitorService.hasData
                    && SystemMonitorService.sequence >= 1
                    && SystemMonitorService.cpuHistory.length >= 1
                    && SystemMonitorService.processRunning
                    && UiPreferences.preferencesReady
                    && Number(
                        UiPreferences.systemGridLayout.version
                    ) === 3
                    && (!smoke.testLifecycle
                        || smoke.observedLifecycleStop)
                    && (!smoke.testOpenTop
                        || (!SystemMonitorService.actionBusy
                            && SystemMonitorService.actionError.length === 0)));
            console.log(
                passed ? "SYSMON_SMOKE_PASS" : "SYSMON_SMOKE_FAIL",
                "state=" + SystemMonitorService.state,
                "sequence=" + SystemMonitorService.sequence,
                "history=" + SystemMonitorService.cpuHistory.length,
                "disks=" + SystemMonitorService.disks.length,
                "gpus=" + SystemMonitorService.gpus.length,
                "battery=" + (SystemMonitorService.battery.present === true),
                "theme=" + Appearance.effectiveMatugenMode
            );
            WidgetState.leftSidebarOpen = false;
            Qt.callLater(Qt.quit);
        }
    }
}
