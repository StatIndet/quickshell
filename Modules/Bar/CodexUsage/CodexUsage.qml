import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    property var primary: null
    property var secondary: null
    property bool ready: false
    property bool failed: false
    readonly property var displayWindow: primary || secondary
    readonly property int remainingPercent: displayWindow
        ? Math.max(0, Math.round(100 - Number(displayWindow.usedPercent || 0)))
        : 0
    readonly property color usageColor: remainingPercent <= 20
        ? Appearance.colors.colError
        : remainingPercent <= 40
            ? Appearance.colors.colTertiary
            : Appearance.colors.colPrimary

    implicitHeight: 36
    implicitWidth: content.implicitWidth + 20

    function windowText(label, windowData) {
        if (!windowData)
            return ""
        const remaining = Math.max(0,
            Math.round(100 - Number(windowData.usedPercent || 0)))
        const reset = windowData.resetsAt
            ? Qt.formatDateTime(new Date(windowData.resetsAt), "M月d日 HH:mm")
            : qsTr("未知")
        return label + qsTr("剩余 ") + remaining + "% · "
            + qsTr("重置 ") + reset
    }

    readonly property string tooltipText: {
        if (failed && !ready)
            return qsTr("Codex 用量暂时不可用")
        const lines = [qsTr("Codex 用量")]
        if (primary)
            lines.push(windowText(qsTr("5 小时："), primary))
        if (secondary)
            lines.push(windowText(qsTr("每周："), secondary))
        if (!primary && !secondary)
            lines.push(qsTr("当前账户未返回额度窗口"))
        lines.push(qsTr("点击打开用量页面"))
        return lines.join("\n")
    }

    function refresh() {
        if (!usageProcess.running)
            usageProcess.running = true
    }

    Component.onCompleted: refresh()

    Rectangle {
        id: background
        anchors.fill: parent
        radius: height / 2
        color: BlurService.backgroundColor(Appearance.colors.colLayer0)
        visible: false
    }

    MultiEffect {
        anchors.fill: background
        source: background
        shadowEnabled: true
        shadowColor: Qt.alpha(Appearance.colors.colShadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: "data_object"
            color: root.failed && !root.ready
                ? Appearance.colors.colError
                : root.usageColor
            font.family: Sizes.fontMaterialSymbols
            font.pixelSize: 18
        }

        Text {
            text: root.ready
                ? root.remainingPercent + "%"
                : usageProcess.running ? "…" : "?"
            color: Appearance.colors.colOnSurface
            font.family: Sizes.fontFamilyMono
            font.pixelSize: 13
            font.weight: Font.Bold
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached([
            "xdg-open",
            "https://chatgpt.com/codex/settings/usage"
        ])
    }

    PopupToolTip {
        extraVisibleCondition: mouseArea.containsMouse
        text: root.tooltipText
    }

    Process {
        id: usageProcess
        command: [
            Quickshell.env("CLAVIS_CODEXBAR") || "codexbar",
            "--provider", "codex",
            "--source", "oauth",
            "--format", "json"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(this.text)
                    const item = Array.isArray(payload) ? payload[0] : payload
                    if (!item || !item.usage)
                        throw new Error("missing usage")
                    root.primary = item.usage.primary || null
                    root.secondary = item.usage.secondary || null
                    root.ready = true
                    root.failed = false
                } catch (error) {
                    root.failed = true
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.failed = true
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
