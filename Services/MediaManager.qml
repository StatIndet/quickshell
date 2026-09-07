pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    // 获取所有可用的播放器数组
    readonly property list<MprisPlayer> list: Mpris.players.values

    // 保存用户手动指定的播放器
    property var manualActive: null

    // 核心计算逻辑：优先手动指定 -> 正在播放的 -> 列表第一个 -> null
    readonly property MprisPlayer active: {
        if (manualActive)
            return manualActive;
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    // One shared, low-frequency position tick feeds all media surfaces. MPRIS
    // implementations do not need a separate QML polling loop per consumer.
    property real currentPosition: 0

    function refreshPosition() {
        const player = root.active;
        root.currentPosition = player ? Math.max(0, Number(player.position) || 0) : 0;
    }

    onActiveChanged: root.refreshPosition()
    Component.onCompleted: root.refreshPosition()

    Timer {
        interval: 250
        repeat: true
        triggeredOnStart: true
        running: root.active !== null
        onTriggered: {
            const player = root.active;
            if (player && player.positionChanged)
                player.positionChanged();
            root.refreshPosition();
        }
    }

    Connections {
        target: root.active
        ignoreUnknownSignals: true

        function onPositionChanged() {
            root.refreshPosition();
        }
        function onLengthChanged() {
            root.refreshPosition();
        }
    }

    // 监听底层状态：如果用户手动指定的播放器被彻底关掉（进程结束），则清空手动状态，让系统重新接管
    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.manualActive) {
                let stillExists = false;
                for (let i = 0; i < Mpris.players.values.length; i++) {
                    if (Mpris.players.values[i] === root.manualActive) {
                        stillExists = true;
                        break;
                    }
                }
                if (!stillExists)
                    root.manualActive = null;
            }
        }
    }

    // 辅助函数：将乱七八糟的底层进程名清洗为美观的名称
    function getIdentity(player) {
        if (!player || !player.identity)
            return qsTr("No media");
        let name = player.identity.toLowerCase();

        if (name.includes("chrome") || name.includes("chromium"))
            return qsTr("Browser");
        if (name.includes("firefox"))
            return "Firefox";
        if (name.includes("spotify"))
            return "Spotify";
        if (name.includes("vlc"))
            return "VLC";
        if (name.includes("edge"))
            return "Edge";

        return player.identity;
    }
}
