import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets.common
import Clavis.Sysmon 1.0

Item {
    id: root

    // 直接使用统一的 Appearance 主题层。

    // 格式化工具函数
    function formatBytes(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return (bps / 1024).toFixed(1) + " KB/s"
        return bps.toFixed(0) + " B/s"
    }
    function formatMemKB(kb) {
        if (kb >= 1048576) return (kb / 1048576).toFixed(1) + " GB"
        if (kb >= 1024) return (kb / 1024).toFixed(1) + " MB"
        return kb + " KB"
    }

    // 折线图历史数据缓存 (31个采样点，多1个用于平滑滑动的起始锚点)
    readonly property int historyLen: 30
    property var netDownHistory: []
    property var netUpHistory: []
    property var ramHistory: []
    property var load1History: []
    property var load5History: []
    property var load15History: []

    // 平滑滑动进度 0→1，数据到达时从 0 动画至 1
    property real slideProgress: 0

    // 平滑纵坐标最大值 — 避免瞬间突变
    property real smoothMaxNet: 1024
    property real smoothMaxLoad: 1
    Behavior on smoothMaxNet { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    Behavior on smoothMaxLoad { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    onSmoothMaxNetChanged: chartCanvas.requestPaint()
    onSmoothMaxLoadChanged: chartCanvas.requestPaint()

    NumberAnimation {
        id: slideAnim
        target: root
        property: "slideProgress"
        from: 0; to: 1
        duration: 1000 // 与 fast timer 间隔一致
    }

    onSlideProgressChanged: chartCanvas.requestPaint()

    function pushHistory(arr, val) {
        arr.push(val)
        if (arr.length > historyLen + 1) arr.shift()
        return arr
    }

    Connections {
        target: SysmonPlugin
        function onFastDataChanged() {
            root.netDownHistory = pushHistory(root.netDownHistory, SysmonPlugin.netDownBps)
            root.netUpHistory = pushHistory(root.netUpHistory, SysmonPlugin.netUpBps)
            root.ramHistory = pushHistory(root.ramHistory, SysmonPlugin.ramUsage / 100.0)
            // 计算网络纵坐标平滑最大值
            var allNet = root.netDownHistory.concat(root.netUpHistory)
            var rawNetMax = Math.max.apply(null, allNet) * 1.2
            if (rawNetMax <= 0) rawNetMax = 1024
            root.smoothMaxNet = rawNetMax
            // 仅当当前标签页是 Net 或 RAM 时才触发滑动
            if (root.currentChartTab !== 2) {
                slideAnim.duration = 1000  // fast timer 间隔
                slideAnim.restart()
            }
        }
        function onMediumDataChanged() {
            root.load1History = pushHistory(root.load1History, SysmonPlugin.load1)
            root.load5History = pushHistory(root.load5History, SysmonPlugin.load5)
            root.load15History = pushHistory(root.load15History, SysmonPlugin.load15)
            // 计算负载纵坐标平滑最大值
            var allLoad = root.load1History.concat(root.load5History, root.load15History)
            var rawLoadMax = Math.max.apply(null, allLoad) * 1.2
            if (rawLoadMax <= 0) rawLoadMax = 1
            root.smoothMaxLoad = rawLoadMax
            // 仅当当前标签页是 Load 时才触发滑动
            if (root.currentChartTab === 2) {
                slideAnim.duration = 2000  // medium timer 间隔
                slideAnim.restart()
            }
        }
    }
    
    component DualArcGauge: Item {
        id: gauge

        property string titleText: "CPU temp"
        property string gapTitleText: "Usage"
        property real mainValue: 41
        property real secondaryValue: 3
        property string mainSuffix: "°C"
        property string secondarySuffix: "%"
        
        property real mainMax: 100
        property real secondaryMax: 100
        
        // 改进轨道背景底色，摒弃死灰色，采用带原色透光感觉的高级轨道。用户如果不喜欢可以降低透明度。
        property color mainTrackColor: Qt.rgba(mainArcColor.r, mainArcColor.g, mainArcColor.b, 0.15)
        property color secondaryTrackColor: Qt.rgba(secondaryArcColor.r, secondaryArcColor.g, secondaryArcColor.b, 0.15)
        
        property color mainArcColor: Appearance.colors.colPrimary
        property color secondaryArcColor: Appearance.colors.colSecondary
        
        implicitWidth: 230
        implicitHeight: 230

        Canvas {
            id: canvas
            anchors.fill: parent
            
            property real mVal: gauge.mainValue
            property real sVal: gauge.secondaryValue
            onMValChanged: requestPaint()
            onSValChanged: requestPaint()
            
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var r = Math.min(width, height) / 2 - 18;
                ctx.lineCap = "round";
                // 变细优化：按照要求将笔刷大幅削减，提供更精致的扁平化视效
                ctx.lineWidth = 9;

                var pi = Math.PI;
                var d2r = pi / 180.0;
                
                // 彻底遵照要求：右下角的缺口是原点！ 45°
                var offsetSmall = 6 * d2r;   // 左上的小缝隙 (调回6度极小缝隙)
                var offsetLarge = 22 * d2r;  // 右下的大缝隙（完美包裹占用率文字）
                
                // T1 (温度赛道, 下半部分): 紧贴右下角缺口的下方(CW 顺时针)延伸到左上
                var t1Base = 45 * d2r + offsetLarge;
                var t1End  = 225 * d2r - offsetSmall;
                
                // T2 (占用率赛道, 上半部分): 遵照要求起点改为对角（左上角缺口的上方）(CW 顺时针)延伸倒挂回右下角
                var t2Base = 225 * d2r + offsetSmall;
                var t2End  = 45 * d2r - offsetLarge + 2 * pi;
                
                // --- 画基础轨道底色 ---
                ctx.beginPath();
                ctx.arc(cx, cy, r, t1Base, t1End, false); // 顺时针
                ctx.strokeStyle = gauge.mainTrackColor;
                ctx.stroke();
                
                ctx.beginPath();
                ctx.arc(cx, cy, r, t2Base, t2End, false); // 顺时针
                ctx.strokeStyle = gauge.secondaryTrackColor;
                ctx.stroke();
                
                // --- 画温度属性 (顺时针生长) ---
                var mainProgress = Math.min(1.0, Math.max(0.0, gauge.mainValue / gauge.mainMax));
                if (mainProgress > 0) {
                    var t1Sweep = t1End - t1Base; 
                    if (t1Sweep < 0) t1Sweep += 2 * pi;
                    var t1ValEnd = t1Base + t1Sweep * mainProgress;
                    
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, t1Base, t1ValEnd, false);
                    ctx.strokeStyle = (gauge.mainValue > 85 && gauge.mainSuffix === "°C") ? Appearance.colors.colError : gauge.mainArcColor;
                    ctx.stroke();
                }
                
                // --- 画利用率属性 (从左上角顺时针攀爬向右下角) ---
                var secProgress = Math.min(1.0, Math.max(0.0, gauge.secondaryValue / gauge.secondaryMax));
                if (secProgress > 0) {
                    var t2Sweep = t2End - t2Base;
                    if (t2Sweep < 0) t2Sweep += 2 * pi;
                    var t2ValEnd = t2Base + t2Sweep * secProgress;
                    
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, t2Base, t2ValEnd, false);
                    ctx.strokeStyle = gauge.secondaryArcColor;
                    ctx.stroke();
                }
            }
        }
        
        // 1. 中央核心区: 温度
        Column {
            anchors.centerIn: parent
            Text { 
                text: Math.round(gauge.mainValue) + gauge.mainSuffix
                font.pixelSize: 42; font.family: "JetBrainsMono Nerd Font"; color: Appearance.colors.colOnSurface 
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text { 
                text: gauge.titleText 
                font.pixelSize: 14; font.family: "LXGW WenKai GB Screen"; color: Appearance.colors.colOnSurfaceVariant 
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        
        // 2. 截断区: 利用率文字 (定位精确塞进右下 45度角的大缝隙缺口)
        Item {
            // 利用三角函数定位到圆环半径的 45度角坐标 (45度正弦与余弦均为0.707)
            x: gauge.width / 2 + (Math.min(gauge.width, gauge.height) / 2 - 18) * 0.707
            y: gauge.height / 2 + (Math.min(gauge.width, gauge.height) / 2 - 18) * 0.707
            
            Column {
                anchors.centerIn: parent
                Text { 
                    text: Math.round(gauge.secondaryValue) + gauge.secondarySuffix
                    font.pixelSize: 15; font.family: "JetBrainsMono Nerd Font"; color: Appearance.colors.colOnSurface; font.bold: true 
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text { 
                    text: gauge.gapTitleText
                    font.pixelSize: 11; font.family: "LXGW WenKai GB Screen"; color: Appearance.colors.colOnSurfaceVariant 
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    property int currentChartTab: 0

    // 不再使用外层 ScrollView，只让进程 ListView 自身滚动
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 24

            // --- Section 1: 创新的双面复合仪表盘区 ---
            Row {
                Layout.fillWidth: true
                spacing: 16
                
                // 完全摒弃 Layout 系统，使用纯原生的宽度平分计算，从根源掐断宽高无限依赖的死循环 (QQuickItem::polish() loop)
                property real itemDim: (width - 16) / 2

                DualArcGauge {
                    width: parent.itemDim
                    height: parent.itemDim
                    
                    titleText: "GPU temp"
                    mainValue: SysmonPlugin.gpuTemp
                    secondaryValue: SysmonPlugin.gpuUsage
                    mainArcColor: Appearance.colors.colSecondary
                    secondaryArcColor: Appearance.colors.colSecondaryFixedDim
                }
                
                DualArcGauge {
                    width: parent.itemDim
                    height: parent.itemDim
                    
                    titleText: "CPU temp"
                    mainValue: SysmonPlugin.coreTemp
                    secondaryValue: SysmonPlugin.cpuUsage
                    mainArcColor: Appearance.colors.colPrimary
                    secondaryArcColor: Appearance.colors.colPrimaryFixedDim
                }
            }

            // --- Section 1.5: 跨界独立 MD3 悬挂胶囊按钮 ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                
                component TabBtn: Item {
                    property string textStr
                    property int tabIdx
                    property bool isActive: root.currentChartTab === tabIdx
                    property bool isFirst: false
                    property bool isLast: false
                    
                    // 立刻变形：按压即刻轻微扩张拉伸，缩小幅度以显优雅
                    Layout.preferredWidth: 64 + (btnMouse.pressed ? 8 : 0)
                    Layout.preferredHeight: 32
                    
                    // 交界处留有的缝隙：重新赋予它们 4px 的切角倒圆，完美匹配图片设定！按下瞬间彻底独立为 16px
                    property real rLeft: (isActive || isFirst || btnMouse.pressed) ? 16 : 4
                    property real rRight: (isActive || isLast || btnMouse.pressed) ? 16 : 4
                    
                    property color bgColor: isActive ? Appearance.colors.colPrimaryContainer : (btnMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2)
                    
                    // 稍微延长动画时长，找回微果冻动效的物理松弛感
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on bgColor { ColorAnimation { duration: 150 } }
                    
                    // 双重基座降维打法：底座扛最大圆角，遮罩扛最小锐角压边。完美防漏。
                    
                    // 【底座大圆角】：始终取两端所需的最大弧度。由于它拥有最大的圆角侵占，必定会被拥有较小圆角的遮罩完满覆盖。
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.rLeft > parent.rRight ? parent.rLeft : parent.rRight
                        color: parent.bgColor
                        // 稍微延长变形动画让圆润过渡清晰可见
                        Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
                    }
                    
                    // 【锐角遮罩】：它只负责去修饰要求圆角较小（更尖锐）的那一边。并且半场长度足够将其自身的微小倒圆隐藏于底座的直线中！
                    Rectangle {
                        // 锚点锁定在要求较小倒角的那一边
                        anchors.left: (parent.rLeft < parent.rRight) ? parent.left : undefined
                        anchors.right: (parent.rRight < parent.rLeft) ? parent.right : undefined
                        
                        // 当两边倒角相同（如完美的大药丸或者同为平端），这个遮罩层自动隐身下岗
                        visible: parent.rLeft !== parent.rRight
                        
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: parent.width / 2 + 5 // 安全冗余 5px 以确保另一端的内倾曲线彻底藏在底座中央的平直面上
                        
                        radius: parent.rLeft < parent.rRight ? parent.rLeft : parent.rRight
                        color: parent.bgColor
                        
                        Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: parent.textStr
                        font.family: "LXGW WenKai GB Screen"
                        font.pixelSize: 13
                        font.bold: parent.isActive
                        color: parent.isActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                        z: 2
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.currentChartTab = parent.tabIdx
                        z: 3
                    }
                }
                
                TabBtn { textStr: "Net"; tabIdx: 0; isFirst: true }
                TabBtn { textStr: "RAM"; tabIdx: 1 }
                TabBtn { textStr: "Load"; tabIdx: 2; isLast: true }
                
                Item { Layout.fillWidth: true }
            }

            // --- Section 2: 折线图 + 右侧信息 ---
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                Layout.maximumHeight: 104
                spacing: 12
                
                // 左侧: 折线图（圆角矩形背景）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Appearance.colors.colLayer0
                    radius: 16
                    clip: true
                    
                    Canvas {
                        id: chartCanvas
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        
                        Connections {
                            target: root
                            function onCurrentChartTabChanged() {
                                chartCanvas.requestPaint()
                            }
                        }
                        
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0,0,width,height);
                            
                            var datasets = [];
                            var dynamMax = 1.0;
                            var maxDisplayHeight = height - 4;
                            
                            if (root.currentChartTab === 0) {
                                var net1 = root.netDownHistory.length > 1 ? root.netDownHistory : [0, 0];
                                var net2 = root.netUpHistory.length > 1 ? root.netUpHistory : [0, 0];
                                datasets = [ {pts: net1, color: Appearance.colors.colPrimary, fill: true}, {pts: net2, color: Appearance.colors.colSecondary, fill: true} ];
                                dynamMax = root.smoothMaxNet;
                            } else if (root.currentChartTab === 1) {
                                var ram1 = root.ramHistory.length > 1 ? root.ramHistory : [0, 0]; 
                                datasets = [ {pts: ram1, color: Appearance.colors.colPrimary, fill: true} ]; 
                                dynamMax = 1.0;
                            } else {
                                var load1 = root.load1History.length > 1 ? root.load1History : [0, 0];
                                var load2 = root.load5History.length > 1 ? root.load5History : [0, 0];
                                var load3 = root.load15History.length > 1 ? root.load15History : [0, 0];
                                datasets = [ {pts: load1, color: "#f9e2af", fill: true}, {pts: load2, color: "#89b4fa", fill: true}, {pts: load3, color: "#cba6f7", fill: true} ];
                                dynamMax = root.smoothMaxLoad;
                            }
                            if (dynamMax <= 0) dynamMax = 1;
                            
                            var stepX = width / (root.historyLen - 1);
                            
                            for (var d = 0; d < datasets.length; d++) {
                                var set = datasets[d];
                                var pts = set.pts;
                                var len = pts.length;
                                var startX = width - (len - 1) * stepX - stepX * root.slideProgress + stepX;
                                
                                ctx.beginPath();
                                var firstY = height - (pts[0] / dynamMax) * maxDisplayHeight;
                                ctx.moveTo(startX, firstY);
                                for (var i = 1; i < len; i++) {
                                    var x = startX + i * stepX;
                                    var y = height - (pts[i] / dynamMax) * maxDisplayHeight;
                                    ctx.lineTo(x, y);
                                }
                                ctx.lineWidth = 2.0;
                                ctx.strokeStyle = set.color;
                                ctx.stroke();
                                
                                if (set.fill) {
                                    var lastX = startX + (len - 1) * stepX;
                                    ctx.lineTo(lastX, height);
                                    ctx.lineTo(startX, height);
                                    ctx.closePath();
                                    
                                    var c = Qt.color(set.color);
                                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                                    grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.25));
                                    grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0));
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                }
                            }
                        }
                    }
                }
                
                // 右侧: 数据信息（无背景，贴右）
                ColumnLayout {
                    id: chartInfoColumn
                    Layout.preferredWidth: 140
                    Layout.fillHeight: true
                    spacing: 8
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    
                    RowLayout {
                        spacing: 6
                        Text { text: "download"; font.family: "Material Symbols Outlined"; color: Appearance.colors.colPrimary; font.pixelSize: 16 }
                        Text { text: formatBytes(SysmonPlugin.netDownBps); color: Appearance.colors.colPrimary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
                    }
                    RowLayout {
                        spacing: 6
                        Text { text: "upload"; font.family: "Material Symbols Outlined"; color: Appearance.colors.colSecondary; font.pixelSize: 16 }
                        Text { text: formatBytes(SysmonPlugin.netUpBps); color: Appearance.colors.colSecondary; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
                    }
                    RowLayout {
                        spacing: 6
                        Text { text: "memory"; font.family: "Material Symbols Outlined"; color: Appearance.colors.colPrimary; font.pixelSize: 16 }
                        Text { text: SysmonPlugin.ramUsedGB.toFixed(1) + "/" + SysmonPlugin.ramTotalGB.toFixed(1) + " GiB"; color: Appearance.colors.colOnSurface; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
                    }
                    RowLayout {
                        spacing: 6
                        Text { text: "speed"; font.family: "Material Symbols Outlined"; color: "#f9e2af"; font.pixelSize: 16 }
                        Text { text: SysmonPlugin.load1.toFixed(2); color: "#f9e2af"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
                        Text { text: SysmonPlugin.load5.toFixed(2); color: "#89b4fa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                        Text { text: SysmonPlugin.load15.toFixed(2); color: "#cba6f7"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                    }
                }
            }

            // --- Section 3: 无上限系统属性展示网格矩阵 ---
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 16
                rowSpacing: 16
                
                component GridCard: Item {
                    property string iconTxt
                    property string title
                    property string val
                    property color acc: Appearance.colors.colPrimary
                    
                    Layout.fillWidth: true
                    Layout.preferredHeight: rowContent.height
                    
                    Row {
                        id: rowContent
                        anchors.left: parent.left // 改为向左对齐，使得视觉更整齐
                        spacing: 8
                        
                        Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.iconTxt; font.family: "Material Symbols Outlined"; color: parent.parent.acc; font.pixelSize: 16 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.title + ":"; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: 13; font.family: "LXGW WenKai GB Screen" }
                        Text { 
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.val
                            color: Appearance.colors.colOnSurface
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font" 
                        }
                    }
                }
                
                GridCard { iconTxt: "mode_fan"; title: "Fan Speed"; val: SysmonPlugin.fanRpm + " RPM"; acc: "#89b4fa" }
                GridCard { iconTxt: "memory"; title: "CPU0 Freq"; val: SysmonPlugin.cpuFreqGHz.toFixed(2) + " GHz"; acc: "#fab387" }
                GridCard { iconTxt: "account_tree"; title: "Tasks"; val: SysmonPlugin.taskRunning + " / " + SysmonPlugin.taskTotal; acc: "#cba6f7" }
                GridCard { iconTxt: "schedule"; title: "Uptime"; val: SysmonPlugin.uptime; acc: "#a6e3a1" }
            }

            // --- Section 4: 空间体积与电量柱群 ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                component RootCard: Rectangle {
                    id: rootCard
                    property string title: "Root (/)"
                    property string val: SysmonPlugin.diskUsage.toFixed(1) + "%"
                    property string usageTxt: SysmonPlugin.diskUsedGB.toFixed(0) + " GB / " + SysmonPlugin.diskTotalGB.toFixed(0) + " GB"
                    property real perc: SysmonPlugin.diskUsage / 100.0
                    property color accColor: "#cba6f7" // Mocha Mauve/Purple
                    
                    Layout.fillWidth: true
                    height: 86
                    color: Appearance.colors.colLayer0
                    radius: 16
                    clip: true
                    
                    // 进度条渲染层 (独立圆角倒圆设计)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * rootCard.perc
                        color: Qt.rgba(rootCard.accColor.r, rootCard.accColor.g, rootCard.accColor.b, 0.15)
                        radius: 16 // 让填充块本身也具有优美的圆角边界
                    }
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16
                        spacing: 16
                        
                        // Icon Block
                        Rectangle {
                            width: 50; height: 50; radius: 14 
                            color: Qt.rgba(rootCard.accColor.r, rootCard.accColor.g, rootCard.accColor.b, 0.15)
                            Text { anchors.centerIn: parent; text: "hard_drive_2"; font.family: "Material Symbols Outlined"; color: rootCard.accColor; font.pixelSize: 26 }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            RowLayout {
                                Row {
                                    spacing: 6
                                    Text {
                                        text: "storage"
                                        font.family: "Material Symbols Outlined"
                                        color: Appearance.colors.colOnSurface
                                        font.pixelSize: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: rootCard.title
                                        color: Appearance.colors.colOnSurface
                                        font.pixelSize: 15
                                        font.bold: true
                                        font.family: "LXGW WenKai GB Screen"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Text { text: rootCard.val; color: rootCard.accColor; font.pixelSize: 18; font.bold:true; font.family: "JetBrainsMono Nerd Font" }
                            }
                            RowLayout {
                                Text { text: "Used Space:"; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: 13; font.family: "LXGW WenKai GB Screen" }
                                Item { Layout.fillWidth: true }
                                Text { text: rootCard.usageTxt; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }
                
                component BatteryCard: Rectangle {
                    id: batCard
                    property string val: SysmonPlugin.batteryPercent.toFixed(1) + "%"
                    property real perc: SysmonPlugin.batteryPercent / 100.0
                    property string statusTxt: SysmonPlugin.batteryStatus
                    property int healthNum: SysmonPlugin.batteryHealth
                    property string powerTxt: SysmonPlugin.batteryPowerW.toFixed(1) + " W"
                    property color accColor: "#a6e3a1" // Mocha Green
                    
                    // 基于健康度动态分配警戒颜色
                    property color healthColor: healthNum >= 80 ? "#a6e3a1" : (healthNum >= 60 ? "#f9e2af" : "#f38ba8")
                    
                    Layout.fillWidth: true
                    height: 86
                    color: Appearance.colors.colLayer0
                    radius: 16
                    clip: true
                    
                    // 进度条渲染层 (独立圆角倒圆设计)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * batCard.perc
                        color: Qt.rgba(batCard.accColor.r, batCard.accColor.g, batCard.accColor.b, 0.15)
                        radius: 16 // 同样引入独占大圆角
                    }
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16
                        spacing: 16
                        
                        Rectangle {
                            width: 50; height: 50; radius: 14
                            color: Qt.rgba(batCard.accColor.r, batCard.accColor.g, batCard.accColor.b, 0.15)
                            Text { anchors.centerIn: parent; text: "battery_charging_full"; font.family: "Material Symbols Outlined"; color: batCard.accColor; font.pixelSize: 26 }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            RowLayout {
                                // “System Battery” 被替换为根据健康度染色的硬核纯数字百分比，并且大幅增加了字号
                                Text { text: batCard.healthNum + "%"; color: batCard.healthColor; font.pixelSize: 24; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                                Item { Layout.fillWidth: true }
                                Text { text: batCard.val; color: batCard.accColor; font.pixelSize: 18; font.bold:true; font.family: "JetBrainsMono Nerd Font" }
                            }
                            RowLayout {
                                Text { 
                                    text: batCard.statusTxt
                                    color: batCard.statusTxt === "Charging" ? batCard.accColor : Appearance.colors.colOnSurfaceVariant
                                    font.pixelSize: 13
                                    font.family: "LXGW WenKai GB Screen"
                                    font.bold: batCard.statusTxt === "Charging"
                                }
                                Item { Layout.fillWidth: true }
                                // 右下部分移除冗余文字，单独留存瓦数功率
                                Text { text: batCard.powerTxt; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                            }
                        }
                    }
                }
                
                RootCard {}
                BatteryCard {
                    visible: SysmonPlugin.hasBattery
                    height: visible ? 86 : 0
                }
            }

            // --- Section 5: 进程监控视图 ---
            ColumnLayout {
                id: procSection
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                
                // 右键菜单打开时暂停刷新
                property bool procMenuOpen: false
                
                // 分类/排序/搜索状态
                property int procTabIdx: 0    // 0=全部, 1=用户, 2=系统
                property int sortCol: 0       // 0=CPU, 1=内存, 2=PID
                property bool sortAsc: false
                property string searchText: ""
                
                // JS 过滤+排序+搜索引擎
                function getFilteredProcesses() {
                    var result = []
                    var procModel = SysmonPlugin.processes
                    if (!procModel) return result
                    var count = procModel.count()
                    
                    for (var i = 0; i < count; i++) {
                        var item = procModel.get(i)
                        if (!item || !item.name) continue
                        
                        // 分类过滤
                        var itemUid = (item.uid !== undefined) ? item.uid : 1000
                        if (procSection.procTabIdx === 1 && itemUid < 1000) continue  // 用户进程: UID >= 1000
                        if (procSection.procTabIdx === 2 && itemUid >= 1000) continue // 系统进程: UID < 1000
                        
                        // 搜索过滤
                        if (procSection.searchText.length > 0) {
                            var query = procSection.searchText.toLowerCase()
                            var nameMatch = item.name.toLowerCase().indexOf(query) >= 0
                            var pidMatch = String(item.pid).indexOf(query) >= 0
                            var cmdMatch = item.cmdline ? item.cmdline.toLowerCase().indexOf(query) >= 0 : false
                            if (!nameMatch && !pidMatch && !cmdMatch) continue
                        }
                        
                        result.push(item)
                    }
                    
                    // 排序
                    var col = procSection.sortCol
                    var asc = procSection.sortAsc
                    result.sort(function(a, b) {
                        var va, vb
                        if (col === 0) { va = a.cpuPercent; vb = b.cpuPercent }
                        else if (col === 1) { va = a.memKB; vb = b.memKB }
                        else { va = a.pid; vb = b.pid }
                        return asc ? (va - vb) : (vb - va)
                    })
                    
                    return result
                }
                
                property var filteredList: []
                
                Component.onCompleted: procSection.filteredList = getFilteredProcesses()
                
                Connections {
                    target: SysmonPlugin
                    function onFastDataChanged() {
                        if (!procSection.procMenuOpen) {
                            procSection.filteredList = procSection.getFilteredProcesses()
                        }
                    }
                }
                
                // 分类/排序/搜索变化时立即刷新
                onProcTabIdxChanged: procSection.filteredList = procSection.getFilteredProcesses()
                onSortColChanged: procSection.filteredList = procSection.getFilteredProcesses()
                onSortAscChanged: procSection.filteredList = procSection.getFilteredProcesses()
                onSearchTextChanged: procSection.filteredList = procSection.getFilteredProcesses()
                
                // --- 头部 1: 控制栏 ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Text { text: "leaderboard"; font.family: "Material Symbols Outlined"; color: Appearance.colors.colPrimary; font.pixelSize: 22 }
                    Text { text: "进程"; color: Appearance.colors.colOnSurface; font.pixelSize: 16; font.bold: true; font.family: "LXGW WenKai GB Screen" }
                    
                    Item { Layout.preferredWidth: 8 }
                    
                    RowLayout {
                        spacing: 2
                        
                        component ProcBtn: Item {
                            property string textStr
                            property int tabIdx
                            property bool isActive: procSection.procTabIdx === tabIdx
                            property bool isFirst: false
                            property bool isLast: false
                            
                            Layout.preferredWidth: 50 + (btnMouse.pressed ? 8 : 0) + (isLast ? 24 : 0)
                            Layout.preferredHeight: 30
                            
                            property real rLeft: (isActive || btnMouse.pressed) ? 15 : 8
                            property real rRight: (isActive || btnMouse.pressed) ? 15 : 8
                            
                            property color bgColor: isActive ? Appearance.colors.colPrimaryContainer : (btnMouse.containsMouse ? Appearance.colors.colLayer4 : Appearance.colors.colLayer2)
                            
                            Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                            Behavior on bgColor { ColorAnimation { duration: 150 } }
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.rLeft > parent.rRight ? parent.rLeft : parent.rRight
                                color: parent.bgColor
                                Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
                            }
                            
                            Rectangle {
                                anchors.left: (parent.rLeft < parent.rRight) ? parent.left : undefined
                                anchors.right: (parent.rRight < parent.rLeft) ? parent.right : undefined
                                visible: parent.rLeft !== parent.rRight
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: parent.width / 2 + 5 
                                radius: parent.rLeft < parent.rRight ? parent.rLeft : parent.rRight
                                color: parent.bgColor
                                Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: parent.textStr
                                font.family: "LXGW WenKai GB Screen"
                                font.pixelSize: 12
                                font.bold: parent.isActive
                                color: parent.isActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                                z: 2
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            
                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: procSection.procTabIdx = parent.tabIdx
                                z: 3
                            }
                        }
                        
                        ProcBtn { textStr: "全部"; tabIdx: 0; isFirst: true }
                        ProcBtn { textStr: "用户"; tabIdx: 1 }
                        ProcBtn { textStr: "系统工具"; tabIdx: 2; isLast: true }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Search bar - 使用 TextField 替代 TextInput 以获得完整的键盘输入支持
                    Rectangle {
                        id: searchBar
                        Layout.preferredWidth: 160; Layout.preferredHeight: 30; radius: 15
                        color: Appearance.colors.colLayer4
                        border.color: searchInput.activeFocus ? Appearance.colors.colSecondary : Appearance.colors.colPrimary
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6
                            Text { text: "search"; font.family: "Material Symbols Outlined"; color: Appearance.colors.colPrimary; font.pixelSize: 16 }
                            TextField {
                                id: searchInput
                                Layout.fillWidth: true
                                color: Appearance.colors.colOnSurface
                                font.pixelSize: 12
                                font.family: "LXGW WenKai GB Screen"
                                placeholderText: ""
                                background: Item {}
                                padding: 0
                                topPadding: 0
                                bottomPadding: 0
                                onTextChanged: procSection.searchText = text
                            }
                        }
                    }
                }
                
                // --- 进程列表主容器 ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true 
                    color: Appearance.colors.colLayer0
                    radius: 16
                    clip: true
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        
                        // Header 2 (表头) - 排序按钮
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "  名称"; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: 13; font.family: "LXGW WenKai GB Screen"; Layout.fillWidth: true }
                            
                            component SortHeader: Rectangle {
                                property string title
                                property int colIdx
                                property bool isActive: procSection.sortCol === colIdx
                                
                                Layout.preferredWidth: colIdx === 0 ? 80 : (colIdx === 1 ? 100 : 70)
                                height: 26
                                radius: 13
                                color: isActive ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.2) : (sortHoverMouse.containsMouse ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.08) : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { 
                                        text: parent.parent.title
                                        color: parent.parent.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                                        font.pixelSize: 13
                                        font.family: "LXGW WenKai GB Screen"
                                        font.bold: parent.parent.isActive 
                                    }
                                    Text { 
                                        text: procSection.sortAsc ? "arrow_upward" : "arrow_downward"
                                        font.family: "Material Symbols Outlined"
                                        color: Appearance.colors.colPrimary
                                        font.pixelSize: 14
                                        visible: parent.parent.isActive
                                    }
                                }
                                
                                MouseArea {
                                    id: sortHoverMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (procSection.sortCol === parent.colIdx) {
                                            procSection.sortAsc = !procSection.sortAsc
                                        } else {
                                            procSection.sortCol = parent.colIdx
                                            procSection.sortAsc = false
                                        }
                                    }
                                }
                            }
                            
                            SortHeader { title: "CPU"; colIdx: 0 }
                            SortHeader { title: "内存"; colIdx: 1 }
                            SortHeader { title: "PID"; colIdx: 2 }
                        }
                        
                        Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colLayer4 }
                        
                        // 列表区域
                        StyledListView {
                            id: processList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            interactive: true
                            animateAppearance: false
                            animateMovement: false

                            model: procSection.filteredList.length
                            
                            delegate: Rectangle {
                                id: procDelegate
                                width: processList.width; height: 42
                                radius: 8
                                
                                property var proc: {
                                    if (procSection.filteredList && index >= 0 && index < procSection.filteredList.length) {
                                        return procSection.filteredList[index] || {}
                                    }
                                    return {}
                                }
                                
                                property bool cpuHigh: (proc && proc.cpuPercent ? proc.cpuPercent : 0) > 5.0
                                property bool ramHigh: (proc && proc.memKB ? proc.memKB : 0) > 1048576
                                property bool hovered: procMouse.containsMouse
                                
                                // 悬浮时使用半透明主题色填充
                                color: hovered ? Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.12) : "transparent"
                                
                                Behavior on color { ColorAnimation { duration: 120 } }
                                
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                                    
                                    Text { 
                                        text: proc && proc.name ? proc.name : ""
                                        color: Appearance.colors.colOnSurface; font.pixelSize: 14
                                        font.family: "JetBrainsMono Nerd Font"
                                        Layout.fillWidth: true; elide: Text.ElideRight 
                                    }
                                    
                                    // CPU Pill
                                    Rectangle {
                                        Layout.preferredWidth: 80; height: 26; radius: 13
                                        color: cpuHigh 
                                            ? Qt.rgba(Appearance.colors.colError.r, Appearance.colors.colError.g, Appearance.colors.colError.b, 0.15) 
                                            : Qt.rgba(Appearance.colors.colOnSurface.r, Appearance.colors.colOnSurface.g, Appearance.colors.colOnSurface.b, 0.06)
                                        Text { 
                                            anchors.centerIn: parent
                                            text: (proc && proc.cpuPercent ? proc.cpuPercent : 0).toFixed(1) + "%"
                                            color: cpuHigh ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                                            font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"; font.bold: true 
                                        }
                                    }
                                    
                                    // RAM Pill
                                    Rectangle {
                                        Layout.preferredWidth: 100; height: 26; radius: 13
                                        color: ramHigh 
                                            ? Qt.rgba(Appearance.colors.colError.r, Appearance.colors.colError.g, Appearance.colors.colError.b, 0.15) 
                                            : Qt.rgba(Appearance.colors.colOnSurface.r, Appearance.colors.colOnSurface.g, Appearance.colors.colOnSurface.b, 0.06)
                                        Text { 
                                            anchors.centerIn: parent
                                            text: formatMemKB(proc && proc.memKB ? proc.memKB : 0)
                                            color: ramHigh ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                                            font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"; font.bold: true 
                                        }
                                    }
                                    
                                    Text { 
                                        text: proc && proc.pid ? proc.pid : ""
                                        color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: 14
                                        font.family: "JetBrainsMono Nerd Font"
                                        Layout.preferredWidth: 70; horizontalAlignment: Text.AlignHCenter 
                                    }
                                }
                                
                                MouseArea {
                                    id: procMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            procSection.procMenuOpen = true
                                            procMenu.popup()
                                        }
                                    }
                                }
                                
                                Menu {
                                    id: procMenu
                                    
                                    onClosed: procSection.procMenuOpen = false
                                    
                                    background: Rectangle {
                                        implicitWidth: 200
                                        color: Appearance.m3colors.m3surfaceContainer
                                        radius: 12
                                    }
                                    
                                    component ProcMenuItem: MenuItem {
                                        id: mItem
                                        property string iconTxt
                                        contentItem: RowLayout {
                                            spacing: 12
                                            Text { text: mItem.iconTxt; font.family: "Material Symbols Outlined"; color: mItem.enabled ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOutline; font.pixelSize: 16 }
                                            Text { text: mItem.text; color: mItem.enabled ? Appearance.colors.colOnSurface : Appearance.colors.colOutline; font.pixelSize: 13; font.family: "LXGW WenKai GB Screen" }
                                            Item { Layout.fillWidth: true }
                                        }
                                    }
                                    
                                    ProcMenuItem { 
                                        text: "复制进程ID"; iconTxt: "tag"
                                        onTriggered: {
                                            if (proc && proc.pid) Quickshell.execDetached(["wl-copy", String(proc.pid)])
                                        }
                                    }
                                    ProcMenuItem { 
                                        text: "复制名称"; iconTxt: "content_copy"
                                        onTriggered: {
                                            if (proc && proc.name) Quickshell.execDetached(["wl-copy", proc.name])
                                        }
                                    }
                                    ProcMenuItem { 
                                        text: "复制完整命令"; iconTxt: "code"
                                        onTriggered: {
                                            if (proc && proc.cmdline) Quickshell.execDetached(["wl-copy", proc.cmdline])
                                        } 
                                    }
                                    
                                    MenuSeparator {
                                        contentItem: Rectangle { implicitWidth: 180; implicitHeight: 1; color: Appearance.colors.colOutlineVariant; anchors.centerIn: parent }
                                    }
                                    
                                    ProcMenuItem { 
                                        text: "结束进程"; iconTxt: "close"
                                        onTriggered: {
                                            if (proc && proc.pid) Quickshell.execDetached(["kill", String(proc.pid)])
                                        }
                                    }
                                    ProcMenuItem { 
                                        text: "强制结束 (SIGKILL)"; iconTxt: "cancel"
                                        enabled: proc && proc.uid !== undefined && proc.uid >= 1000
                                        onTriggered: {
                                            if (proc && proc.pid) Quickshell.execDetached(["kill", "-9", String(proc.pid)])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
}
