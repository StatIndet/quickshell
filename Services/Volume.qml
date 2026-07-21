pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property bool ready: Pipewire.ready
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audioNodes: Pipewire.nodes.values.filter(node => node && node.audio)
    readonly property var outputDevices: root.sortedNodes(root.audioNodes.filter(node => !node.isStream && node.isSink))
    readonly property var inputDevices: root.sortedNodes(root.audioNodes.filter(node => !node.isStream && !node.isSink))
    readonly property var playbackStreams: root.playbackNodes(playbackTracker.linkGroups)
    readonly property bool available: root.ready && (root.outputDevices.length > 0 || root.inputDevices.length > 0)
    readonly property bool outputAvailable: root.sink !== null && root.sink !== undefined
    readonly property bool inputAvailable: root.source !== null && root.source !== undefined
    readonly property bool busy: false

    readonly property bool isHeadphone: root.nodeIconName(root.sink) === "headphones"
    readonly property bool sinkMuted: root.nodeMuted(root.sink)
    readonly property real sinkVolume: root.nodeVolume(root.sink)
    readonly property bool sourceMuted: root.nodeMuted(root.source)
    readonly property real sourceVolume: root.nodeVolume(root.source)
    readonly property string sinkName: root.nodeDisplayName(root.sink)
    readonly property string sourceName: root.nodeDisplayName(root.source)

    property string lastError: ""

    signal operationFailed(string operation, string message)

    PwObjectTracker {
        // PwNode properties and audio controls are only valid while tracked.
        objects: root.audioNodes
    }

    PwNodeLinkTracker {
        id: playbackTracker
        node: root.sink
    }

    function fail(operation, message) {
        root.lastError = message;
        root.operationFailed(operation, message);
        return false;
    }

    function clearError() {
        root.lastError = "";
    }

    function sortedNodes(nodes) {
        return nodes.slice().sort((left, right) => root.nodeDisplayName(left).localeCompare(root.nodeDisplayName(right)));
    }

    function playbackNodes(groups) {
        const streams = [];
        const seenIds = {};

        for (let index = 0; index < groups.length; index += 1) {
            const node = groups[index] ? groups[index].source : null;
            if (!node || !node.audio || !node.isStream)
                continue;

            const id = root.nodeId(node);
            if (seenIds[id])
                continue;

            seenIds[id] = true;
            streams.push(node);
        }

        return root.sortedNodes(streams);
    }

    function nodeId(node) {
        return node ? String(node.id) : "";
    }

    function sameNode(left, right) {
        return left && right && root.nodeId(left) === root.nodeId(right);
    }

    function nodeProperties(node) {
        return node && node.properties ? node.properties : ({});
    }

    function nodeDisplayName(node) {
        if (!node)
            return "";

        const properties = root.nodeProperties(node);
        return properties["application.name"]
            || node.description
            || node.nickname
            || node.name
            || "未知音频设备";
    }

    function nodeSupportingText(node) {
        if (!node)
            return "";

        const properties = root.nodeProperties(node);
        if (node.isStream) {
            const binary = properties["application.process.binary"] || properties["application.process.id"] || "";
            const mediaName = properties["media.name"] || "";
            return binary && binary !== root.nodeDisplayName(node) ? binary : mediaName;
        }

        const profile = properties["device.profile.description"] || properties["device.product.name"] || "";
        if (profile && profile !== root.nodeDisplayName(node))
            return profile;
        if (node.name && node.name !== root.nodeDisplayName(node))
            return node.name;
        return node.isSink ? "音频输出设备" : "音频输入设备";
    }

    function nodeIconName(node) {
        if (!node)
            return "volume_off";

        const properties = root.nodeProperties(node);
        const descriptor = [
            properties["device.icon-name"] || "",
            properties["media.icon-name"] || "",
            node.description || "",
            node.name || ""
        ].join(" ").toLowerCase();

        if (node.isStream)
            return "music_note";
        if (descriptor.indexOf("headphone") >= 0 || descriptor.indexOf("headset") >= 0 || descriptor.indexOf("耳机") >= 0)
            return "headphones";
        if (descriptor.indexOf("bluetooth") >= 0 || descriptor.indexOf("bluez") >= 0)
            return node.isSink ? "headphones" : "mic";
        if (descriptor.indexOf("hdmi") >= 0 || descriptor.indexOf("displayport") >= 0)
            return "tv";
        if (descriptor.indexOf("speaker") >= 0 || descriptor.indexOf("扬声器") >= 0)
            return "speaker";
        return node.isSink ? "volume_up" : "mic";
    }

    function applicationIconSource(node) {
        if (!node)
            return "";

        const properties = root.nodeProperties(node);
        const rawIcon = properties["application.icon-name"] || properties["application.process.binary"] || "";
        const iconAliases = {
            "zen": "zen-browser",
            "zen-bin": "zen-browser",
            "zen-alpha": "zen-browser"
        };
        const icon = iconAliases[String(rawIcon).toLowerCase()] || rawIcon;
        if (!icon)
            return "";
        if (String(icon).startsWith("file://"))
            return String(icon);
        if (String(icon).startsWith("/"))
            return "file://" + icon;
        return "image://icon/" + icon;
    }

    function nodeVolume(node) {
        return node && node.audio ? Math.max(0, Math.min(1, node.audio.volume)) : 0;
    }

    function nodeMuted(node) {
        return node && node.audio ? node.audio.muted : false;
    }

    function isDefaultOutput(node) {
        return root.sameNode(node, root.sink);
    }

    function isDefaultInput(node) {
        return root.sameNode(node, root.source);
    }

    function resolveNode(node, candidates) {
        const id = root.nodeId(node);
        for (let index = 0; index < candidates.length; index += 1) {
            if (root.nodeId(candidates[index]) === id)
                return candidates[index];
        }
        return null;
    }

    function setDefaultOutput(node) {
        const currentNode = root.resolveNode(node, root.outputDevices);
        if (!currentNode)
            return root.fail("set-default-output", "所选输出设备已不可用");

        root.clearError();
        Pipewire.preferredDefaultAudioSink = currentNode;
        return true;
    }

    function setDefaultInput(node) {
        const currentNode = root.resolveNode(node, root.inputDevices);
        if (!currentNode)
            return root.fail("set-default-input", "所选输入设备已不可用");

        root.clearError();
        Pipewire.preferredDefaultAudioSource = currentNode;
        return true;
    }

    function setNodeVolume(node, volume) {
        if (!node || !node.audio)
            return root.fail("set-volume", "音频对象已不可用");

        const safeVolume = Math.max(0, Math.min(1, Number(volume)));
        if (isNaN(safeVolume))
            return root.fail("set-volume", "音量数值无效");

        root.clearError();
        node.audio.volume = safeVolume;
        if (node.audio.muted)
            node.audio.muted = false;
        return true;
    }

    function toggleNodeMute(node) {
        if (!node || !node.audio)
            return root.fail("toggle-mute", "音频对象已不可用");

        root.clearError();
        node.audio.muted = !node.audio.muted;
        return true;
    }

    function toggleSinkMute() {
        return root.toggleNodeMute(root.sink);
    }

    function setSinkVolume(volume) {
        return root.setNodeVolume(root.sink, volume);
    }

    function toggleSourceMute() {
        return root.toggleNodeMute(root.source);
    }

    function setSourceVolume(volume) {
        return root.setNodeVolume(root.source, volume);
    }

    function openMixer() {
        Quickshell.execDetached(["pavucontrol"]);
    }
}
