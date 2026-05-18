import QtQuick
import QtQuick.Layouts
import QtQuick.Effects 
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Common 
import qs.Services 
import qs.Widgets.common

Item {
    id: root
    
    required property var player
    property bool active: false
    property var lyricsModel: []
    property int currentLineIndex: 0
    
    readonly property string trackTitle: player ? player.trackTitle : ""
    readonly property string trackArtist: player ? player.trackArtist : ""
    readonly property string playerName: player ? (player.identity || player.busName || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    
    property string currentLoadedTitle: ""
    readonly property string spectrumToken: "dynamic-island-lyrics"

    Component.onCompleted: {
        if (root.active)
            AudioSpectrum.acquire(root.spectrumToken);
    }
    Component.onDestruction: AudioSpectrum.release(root.spectrumToken)

    // ============================================================
    // 【动态自适应宽度引擎】
    // ============================================================
    property int defaultTextWidth: 350 
    property int currentTextWidth: defaultTextWidth 
    
    // 左边距(15) + 封面(26) + 间距(12) + 歌词(动态) + 间距(12) + 频谱(22) + 右边距(15) = 102
    implicitWidth: 102 + currentTextWidth 

    Connections {
        target: root
        function onActiveChanged() {
            if (root.active)
                AudioSpectrum.acquire(root.spectrumToken);
            else
                AudioSpectrum.release(root.spectrumToken);
        }
    }

    // ================= 1. 歌词获取逻辑 =================
    Process {
        id: lyricsFetcher
        command: ["python3", Paths.scriptPath("media", "lyrics_fetcher.py"), root.trackTitle, root.trackArtist, root.playerName]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var json = JSON.parse(data)
                    if (json.length > 0) { 
                        root.lyricsModel = json; root.currentLineIndex = 0;
                        root.currentLoadedTitle = root.trackTitle
                    } else { 
                        root.lyricsModel = [{time: 0, text: "暂无歌词"}] 
                    }
                } catch (e) { root.lyricsModel = [{time: 0, text: "歌词错误"}] }
            }
        }
    }

    onTrackTitleChanged: triggerReload()
    onActiveChanged: { if (active && root.trackTitle !== root.currentLoadedTitle) triggerReload() }

    function triggerReload() {
        if (!root.active) return
        if (lyricsFetcher.running) lyricsFetcher.running = false
        debounceTimer.restart()
    }

    Timer { 
        id: debounceTimer; interval: 300; repeat: false; 
        onTriggered: {
            if (root.trackTitle !== "") { 
                root.lyricsModel = []; root.currentLineIndex = 0; 
                lyricsFetcher.running = true 
            }
        }
    }

    // ================= 2. 极简同步逻辑 =================
    Timer {
        interval: 100
        running: root.active && root.lyricsModel.length > 1 && root.player
        repeat: true
        onTriggered: {
            if (!root.player) return
            var rawPos = root.player.position
            var currentSec = (rawPos > 100000) ? (rawPos / 1000000) : rawPos
            var activeIdx = -1
            for (var i = 0; i < root.lyricsModel.length; i++) {
                if (root.lyricsModel[i].time <= (currentSec + 0.5)) activeIdx = i; else break
            }
            if (activeIdx === -1) activeIdx = 0
            if (activeIdx !== root.currentLineIndex) {
                root.currentLineIndex = activeIdx
            }
        }
    }

    // ================= 3. 界面层 =================
    Item {
        anchors.fill: parent
        clip: true 

        // --- 专辑封面 ---
        Item {
            id: albumCoverContainer
            anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            
            Image {
                id: coverImg; anchors.fill: parent
                source: root.artUrl; visible: root.artUrl !== ""; fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource { sourceItem: Rectangle { width: coverImg.width; height: coverImg.height; radius: 5; color: "black" } }
                }
            }
            Text {
                visible: root.artUrl === ""; anchors.centerIn: parent
                text: "\uf001"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: 14; color: "#80ffffff"
            }
        }

        // --- 歌词列表 ---
        StyledListView {
            id: lyricsView
            anchors.left: albumCoverContainer.right
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            
            width: root.currentTextWidth
            
            interactive: false
            animateAppearance: false
            animateMovement: false
            showVerticalScrollBar: false
            smoothWheelEnabled: false
            model: root.lyricsModel
            currentIndex: root.currentLineIndex
            
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: 0 
            highlightMoveDuration: 400 

            delegate: Item {
                width: ListView.view.width
                height: 42 
                property bool isCurrent: ListView.isCurrentItem

                onIsCurrentChanged: {
                    if (isCurrent) {
                        root.currentTextWidth = Math.max(root.defaultTextWidth, Math.min(lyricText.implicitWidth, 800))
                    }
                }

                Text {
                    id: lyricText
                    anchors.centerIn: parent
                    text: modelData.text
                    color: "white"
                    font.family: Sizes.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter 
                }
            }
        }

        // ============================================================
        // 【全新】：高动态对称聚合频谱条
        // ============================================================
        Item {
            id: spectrumContainer
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 21  
            height: 16 

            property var smoothValues: [0, 0, 0, 0, 0, 0]

            Timer {
                interval: 16 
                running: root.active && AudioSpectrum.available
                repeat: true
                onTriggered: {
                    let s = spectrumContainer.smoothValues;
                    let r = AudioSpectrum.values;
                    if (!r || r.length < 6) return;
                    
                    let getRegionMax = (startRatio, endRatio) => {
                        let start = Math.max(0, Math.min(r.length - 1, Math.floor(r.length * startRatio)));
                        let end = Math.max(start, Math.min(r.length - 1, Math.floor(r.length * endRatio)));
                        let maxV = 0;
                        for (let i = start; i <= end; i++) {
                            if (r[i] > maxV) maxV = r[i];
                        }
                        return maxV * 100;
                    };

                    let targets = [0, 0, 0, 0, 0, 0];
                    
                    targets[0] = getRegionMax(0.55, 0.78) * 1.5;
                    targets[5] = getRegionMax(0.78, 0.98) * 1.5;
                    
                    targets[1] = getRegionMax(0.18, 0.33) * 1.2;
                    targets[4] = getRegionMax(0.33, 0.55) * 1.2;
                    
                    targets[2] = getRegionMax(0.00, 0.08);
                    targets[3] = getRegionMax(0.08, 0.18);

                    let globalBeat = Math.max(targets[2], targets[3]);

                    for (let i = 0; i < 6; i++) {
                        let finalTarget = Math.min(100, targets[i] * 0.8 + globalBeat * 0.2);
                        
                        let diff = finalTarget - s[i];
                        
                        if (diff > 0) s[i] += 0.85 * diff;
                        else s[i] += 0.08 * diff;
                    }
                    
                    spectrumContainer.smoothValues = s;
                    spectrumCanvas.requestPaint();
                }
            }

            Canvas {
                id: spectrumCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    let s = parent.smoothValues;
                    
                    ctx.beginPath();
                    ctx.lineCap = "round"; 
                    ctx.lineWidth = 2.5;   
                    ctx.strokeStyle = String(Appearance.colors.colPrimary); 

                    for(let i = 0; i < 6; i++) {
                        let val = Math.min(1.0, s[i] / 100.0);
                        let h = Math.max(3, val * height); // 最低保持 3px 圆点
                        
                        let x = 1.25 + i * 3.7; 
                        
                        ctx.moveTo(x, height / 2 - h / 2);
                        ctx.lineTo(x, height / 2 + h / 2);
                    }
                    ctx.stroke();
                }
            }
        }
    }
}
