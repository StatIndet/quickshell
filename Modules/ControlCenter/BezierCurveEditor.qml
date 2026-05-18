import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common

Item {
    id: root

    property var curve: [0.43, 1.19, 1.0, 0.4, 1.0, 1.0]
    property var workingCurve: curve
    property string easingMode: "customBezier"
    readonly property bool editable: easingMode === "customBezier"
    property real chartSize: 320
    property int activePoint: -1
    property bool playing: false
    property int playbackDirection: 1
    property real playhead: 0
    property int playDurationMs: 1000
    property string editText: ""
    property bool editTextInvalid: false
    property int editingCoordinate: -1
    property string coordinateDraft: ""
    property bool coordinateInvalid: false
    property color chartSurfaceColor: Appearance.m3colors.m3surfaceContainerLowest
    property color chartAxisColor: Appearance.colors.colOnSurfaceVariant
    property color chartPrimaryColor: Appearance.colors.colPrimary
    property color chartSecondaryColor: Appearance.colors.colSecondary
    property color chartTertiaryColor: Appearance.colors.colTertiary

    signal controlsEdited(var nextCurve)
    signal editRequested()

    implicitWidth: chartSize
    implicitHeight: chartColumn.implicitHeight

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function clamp01(value) {
        return clamp(value, 0, 1);
    }

    function control(index, fallback) {
        const value = Number(workingCurve[index]);
        return isNaN(value) ? fallback : value;
    }

    function rawP1() {
        return [control(0, 0.43), control(1, 1.19)];
    }

    function rawP2() {
        return [control(2, 1.0), control(3, 0.4)];
    }

    function displayPoint(point) {
        return [clamp01(point[0]), clamp01(point[1])];
    }

    function formatNumber(value) {
        const rounded = Math.round(value * 100) / 100;
        return rounded.toFixed(2).replace(/\.?0+$/, "");
    }

    function cubicCoord(t, a, b) {
        const u = 1 - t;
        return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t;
    }

    function presetValueAt(t) {
        const mode = easingMode;
        if (mode === "linear")
            return t;
        if (mode === "quad")
            return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
        if (mode === "cubic")
            return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
        if (mode === "quart")
            return t < 0.5 ? 8 * Math.pow(t, 4) : 1 - Math.pow(-2 * t + 2, 4) / 2;
        if (mode === "quint")
            return t < 0.5 ? 16 * Math.pow(t, 5) : 1 - Math.pow(-2 * t + 2, 5) / 2;
        if (mode === "sine")
            return -(Math.cos(Math.PI * t) - 1) / 2;
        if (mode === "expo") {
            if (t === 0 || t === 1)
                return t;
            return t < 0.5 ? Math.pow(2, 20 * t - 10) / 2 : (2 - Math.pow(2, -20 * t + 10)) / 2;
        }
        if (mode === "circ")
            return t < 0.5 ? (1 - Math.sqrt(1 - Math.pow(2 * t, 2))) / 2 : (Math.sqrt(1 - Math.pow(-2 * t + 2, 2)) + 1) / 2;

        return t;
    }

    function customBezierValueAt(x) {
        const p1 = rawP1();
        const p2 = rawP2();
        let lo = 0;
        let hi = 1;
        let s = x;
        for (let i = 0; i < 18; i += 1) {
            s = (lo + hi) / 2;
            if (cubicCoord(s, p1[0], p2[0]) < x)
                lo = s;
            else
                hi = s;
        }
        return cubicCoord(s, p1[1], p2[1]);
    }

    function valueAt(t) {
        if (easingMode === "customBezier")
            return customBezierValueAt(t);
        return presetValueAt(t);
    }

    function curvePathPoint(t) {
        return [t, clamp01(valueAt(t))];
    }

    function plotX(x) {
        return chart.plotLeft + clamp01(x) * chart.plotSize;
    }

    function plotY(y) {
        return chart.plotTop + (1 - clamp01(y)) * chart.plotSize;
    }

    function pointFromMouse(mx, my) {
        return [
            clamp01((mx - chart.plotLeft) / chart.plotSize),
            clamp01(1 - (my - chart.plotTop) / chart.plotSize)
        ];
    }

    function hitTest(mx, my) {
        if (!editable)
            return -1;

        const p1 = displayPoint(rawP1());
        const p2 = displayPoint(rawP2());
        const p1x = plotX(p1[0]);
        const p1y = plotY(p1[1]);
        const p2x = plotX(p2[0]);
        const p2y = plotY(p2[1]);
        const d1 = Math.hypot(mx - p1x, my - p1y);
        const d2 = Math.hypot(mx - p2x, my - p2y);
        if (d1 < 18 || d2 < 18)
            return d1 <= d2 ? 0 : 1;
        return -1;
    }

    function coordinateListText() {
        const p1 = rawP1();
        const p2 = rawP2();
        return formatNumber(p1[0]) + ", " + formatNumber(p1[1]) + ", "
            + formatNumber(p2[0]) + ", " + formatNumber(p2[1]);
    }

    function parseBezierText(text) {
        const parts = text.trim().split(",");
        if (parts.length !== 4)
            return null;

        const values = [];
        for (let i = 0; i < 4; i += 1) {
            const value = Number(parts[i].trim());
            if (!isFinite(value))
                return null;
            values.push(value);
        }
        return [values[0], values[1], values[2], values[3], 1, 1];
    }

    function coordinateFallback(index) {
        const defaults = [0.43, 1.19, 1.0, 0.4];
        return defaults[index] || 0;
    }

    function coordinateValue(index) {
        return control(index, coordinateFallback(index));
    }

    function coordinateText(index) {
        return formatNumber(coordinateValue(index));
    }

    function openCoordinateField(index) {
        if (!editable)
            return;

        editingCoordinate = index;
        coordinateDraft = coordinateText(index);
        coordinateInvalid = false;
    }

    function applyCoordinateField() {
        if (editingCoordinate < 0)
            return;

        const value = Number(coordinateDraft.trim());
        if (!isFinite(value)) {
            coordinateInvalid = true;
            return;
        }

        const next = workingCurve.slice();
        while (next.length < 6)
            next.push(1);
        next[editingCoordinate] = value;
        next[4] = 1;
        next[5] = 1;
        workingCurve = next;
        controlsEdited(next);
        editingCoordinate = -1;
        coordinateInvalid = false;
        chart.requestPaint();
    }

    function cancelCoordinateField() {
        editingCoordinate = -1;
        coordinateInvalid = false;
    }

    function openCoordinateEditor() {
        if (!editable)
            return;

        editText = coordinateListText();
        editTextInvalid = false;
        coordEditPopup.open();
        coordPopupInput.forceActiveFocus();
        coordPopupInput.selectAll();
    }

    function applyCoordinateEdit() {
        const next = parseBezierText(editText);
        if (next === null) {
            editTextInvalid = true;
            return;
        }

        workingCurve = next;
        controlsEdited(next);
        coordEditPopup.close();
        chart.requestPaint();
    }

    function startPlayback() {
        if (playhead >= 1)
            playhead = 0;

        playbackDirection = 1;
        playing = true;
        playbackAnimation.from = playhead;
        playbackAnimation.to = 1;
        playbackAnimation.duration = Math.max(160, Math.round(playDurationMs * (1 - playhead)));
        playbackAnimation.start();
    }

    function togglePlayback() {
        if (playing) {
            playbackAnimation.stop();
            playing = false;
            return;
        }

        startPlayback();
    }

    function reversePlayback() {
        playbackAnimation.stop();
        playing = false;
        if (playhead <= 0)
            playhead = 1;

        playbackDirection = -1;
        playing = true;
        playbackAnimation.from = playhead;
        playbackAnimation.to = 0;
        playbackAnimation.duration = Math.max(160, Math.round(playDurationMs * playhead));
        playbackAnimation.start();
    }

    function flipCurve() {
        if (!editable)
            return;

        const p1 = rawP1();
        const p2 = rawP2();
        const next = [
            1 - p2[0],
            1 - p2[1],
            1 - p1[0],
            1 - p1[1],
            1,
            1
        ];
        workingCurve = next;
        controlsEdited(next);
        chart.requestPaint();
    }

    function repaintChart() {
        if (chart)
            chart.requestPaint();
    }

    onCurveChanged: {
        if (activePoint < 0)
            workingCurve = curve;
        chart.requestPaint();
    }
    onWorkingCurveChanged: chart.requestPaint()
    onEasingModeChanged: chart.requestPaint()
    onPlayheadChanged: chart.requestPaint()
    onWidthChanged: chart.requestPaint()
    onHeightChanged: chart.requestPaint()
    onChartSurfaceColorChanged: repaintChart()
    onChartAxisColorChanged: repaintChart()
    onChartPrimaryColorChanged: repaintChart()
    onChartSecondaryColorChanged: repaintChart()
    onChartTertiaryColorChanged: repaintChart()

    NumberAnimation {
        id: playbackAnimation
        target: root
        property: "playhead"
        to: 1
        easing.type: Easing.Linear
        onStopped: {
            if ((root.playbackDirection > 0 && root.playhead >= 1) || (root.playbackDirection < 0 && root.playhead <= 0))
                root.playing = false;
        }
    }

    ColumnLayout {
        id: chartColumn

        anchors.fill: parent
        spacing: 8

        Item {
            Layout.alignment: Qt.AlignLeft
            Layout.preferredWidth: root.chartSize
            Layout.preferredHeight: root.chartSize

            Canvas {
                id: chart

                property real axisPadding: 14
                readonly property real plotLeft: axisPadding
                readonly property real plotTop: axisPadding
                readonly property real plotSize: Math.max(1, Math.min(width, height) - axisPadding * 2)

                anchors.fill: parent

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    const left = plotLeft;
                    const top = plotTop;
                    const size = plotSize;
                    const right = left + size;
                    const bottom = top + size;
                    const p1 = root.displayPoint(root.rawP1());
                    const p2 = root.displayPoint(root.rawP2());
                    const startX = root.plotX(0);
                    const startY = root.plotY(0);
                    const endX = root.plotX(1);
                    const endY = root.plotY(1);

                    ctx.fillStyle = root.chartSurfaceColor;
                    ctx.fillRect(left, top, size, size);

                    ctx.strokeStyle = root.chartAxisColor;
                    ctx.lineWidth = 1.4;
                    ctx.beginPath();
                    ctx.rect(left, top, size, size);
                    ctx.stroke();

                    if (root.editable) {
                        ctx.strokeStyle = Appearance.applyAlpha(root.chartSecondaryColor, 0.72);
                        ctx.lineWidth = 1.6;
                        ctx.setLineDash([5, 5]);
                        ctx.beginPath();
                        ctx.moveTo(startX, startY);
                        ctx.lineTo(root.plotX(p1[0]), root.plotY(p1[1]));
                        ctx.moveTo(endX, endY);
                        ctx.lineTo(root.plotX(p2[0]), root.plotY(p2[1]));
                        ctx.stroke();
                        ctx.setLineDash([]);
                    }

                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.strokeStyle = root.chartPrimaryColor;
                    ctx.lineWidth = 3.4;
                    ctx.beginPath();
                    for (let i = 0; i <= 120; i += 1) {
                        const point = root.curvePathPoint(i / 120);
                        const x = root.plotX(point[0]);
                        const y = root.plotY(point[1]);
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.stroke();

                    const trailSteps = Math.max(1, Math.round(root.playhead * 120));
                    if (root.playhead > 0) {
                        ctx.strokeStyle = root.chartTertiaryColor;
                        ctx.lineWidth = 3.4;
                        ctx.beginPath();
                        for (let i = 0; i <= trailSteps; i += 1) {
                            const point = root.curvePathPoint((i / trailSteps) * root.playhead);
                            const x = root.plotX(point[0]);
                            const y = root.plotY(point[1]);
                            if (i === 0)
                                ctx.moveTo(x, y);
                            else
                                ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }

                    function drawControlPoint(x, y, selected) {
                        const side = selected ? 15 : 13;
                        ctx.fillStyle = root.chartSurfaceColor;
                        ctx.strokeStyle = selected ? root.chartTertiaryColor : root.chartSecondaryColor;
                        ctx.lineWidth = selected ? 2.4 : 2;
                        ctx.beginPath();
                        ctx.rect(x - side / 2, y - side / 2, side, side);
                        ctx.fill();
                        ctx.stroke();
                    }

                    if (root.editable) {
                        drawControlPoint(root.plotX(p1[0]), root.plotY(p1[1]), root.activePoint === 0);
                        drawControlPoint(root.plotX(p2[0]), root.plotY(p2[1]), root.activePoint === 1);
                    }

                    const playPoint = root.curvePathPoint(root.playhead);
                    ctx.fillStyle = root.chartTertiaryColor;
                    ctx.strokeStyle = root.chartSurfaceColor;
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.arc(root.plotX(playPoint[0]), root.plotY(playPoint[1]), 9, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.stroke();
                }
            }

            MouseArea {
                anchors.fill: chart
                acceptedButtons: Qt.LeftButton
                enabled: root.editable
                hoverEnabled: true
                preventStealing: true
                cursorShape: root.activePoint >= 0 || root.hitTest(mouseX, mouseY) >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

                onPressed: mouse => {
                    if (mouse.button !== Qt.LeftButton) {
                        mouse.accepted = false;
                        return;
                    }

                    const hit = root.hitTest(mouse.x, mouse.y);
                    if (hit < 0) {
                        mouse.accepted = false;
                        return;
                    }

                    root.activePoint = hit;
                    mouse.accepted = true;
                    chart.requestPaint();
                }

                onPositionChanged: mouse => {
                    if (root.activePoint < 0)
                        return;

                    const point = root.pointFromMouse(mouse.x, mouse.y);
                    const next = root.workingCurve.slice();
                    if (root.activePoint === 0) {
                        next[0] = point[0];
                        next[1] = point[1];
                    } else {
                        next[2] = point[0];
                        next[3] = point[1];
                    }
                    next[4] = 1;
                    next[5] = 1;
                    root.workingCurve = next;
                    chart.requestPaint();
                }

                onReleased: {
                    if (root.activePoint >= 0)
                        root.controlsEdited(root.workingCurve);
                    root.activePoint = -1;
                    chart.requestPaint();
                }

                onCanceled: {
                    root.workingCurve = root.curve;
                    root.activePoint = -1;
                    chart.requestPaint();
                }
            }
        }

        Item {
            id: coordContainer
            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: chart.axisPadding
            Layout.preferredWidth: chart.plotSize
            Layout.preferredHeight: coordRow.implicitHeight
            visible: root.editable

            RowLayout {
                id: coordRow

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Repeater {
                    model: [
                        ({ "index": 0 }),
                        ({ "index": 1 }),
                        ({ "index": 2 }),
                        ({ "index": 3 })
                    ]

                    delegate: Item {
                        id: coordItem

                        required property var modelData
                        readonly property bool editing: root.editingCoordinate === modelData.index

                        implicitWidth: 50
                        implicitHeight: 26

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.extraSmall
                            color: coordItem.editing ? Appearance.colors.colLayer2 : "transparent"
                            border.width: coordItem.editing ? 1 : 0
                            border.color: root.coordinateInvalid ? Appearance.colors.colError : Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.28)
                        }

                        Text {
                            id: coordText

                            anchors.centerIn: parent
                            visible: !coordItem.editing
                            text: root.coordinateText(coordItem.modelData.index)
                            color: coordMouse.containsMouse ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        TextField {
                            id: coordInput

                            anchors.fill: parent
                            visible: coordItem.editing
                            text: root.coordinateDraft
                            color: Appearance.colors.colOnSurface
                            selectedTextColor: Appearance.colors.colOnPrimary
                            selectionColor: Appearance.colors.colPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            selectByMouse: true
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: 13
                            padding: 0
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            Material.accent: Appearance.colors.colPrimary
                            background: Item {}
                            onTextChanged: {
                                if (coordItem.editing) {
                                    root.coordinateDraft = text;
                                    root.coordinateInvalid = false;
                                }
                            }
                            onVisibleChanged: {
                                if (visible) {
                                    Qt.callLater(() => {
                                        coordInput.forceActiveFocus();
                                        coordInput.selectAll();
                                    });
                                }
                            }
                            onEditingFinished: root.applyCoordinateField()
                            Keys.onReturnPressed: root.applyCoordinateField()
                            Keys.onEnterPressed: root.applyCoordinateField()
                            Keys.onEscapePressed: event => {
                                root.cancelCoordinateField();
                                event.accepted = true;
                            }
                        }

                        MouseArea {
                            id: coordMouse

                            anchors.fill: parent
                            enabled: !coordItem.editing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openCoordinateField(coordItem.modelData.index)
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: coordEditPopup

        width: Math.min(360, Math.max(300, root.width - 16))
        height: coordEditLayout.implicitHeight + 28
        x: Math.max(0, (root.width - width) / 2)
        y: Math.max(0, (root.height - height) / 2)
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainerHighest
            border.color: Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.2)
            border.width: 1
        }

        contentItem: ColumnLayout {
            id: coordEditLayout

            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "编辑贝塞尔"
                color: Appearance.colors.colOnSurface
                font.family: Sizes.fontFamily
                font.pixelSize: 16
                font.weight: Font.Medium
            }

            TextField {
                id: coordPopupInput

                Layout.fillWidth: true
                text: root.editText
                color: Appearance.colors.colOnSurface
                selectedTextColor: Appearance.colors.colOnPrimary
                selectionColor: Appearance.colors.colPrimary
                font.family: Sizes.fontFamilyMono
                font.pixelSize: 14
                placeholderText: ".43,1.19,1,.4"
                Material.accent: Appearance.colors.colPrimary
                onTextChanged: {
                    root.editText = text;
                    root.editTextInvalid = false;
                }
                Keys.onReturnPressed: root.applyCoordinateEdit()
                Keys.onEnterPressed: root.applyCoordinateEdit()

                background: Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    border.color: root.editTextInvalid ? Appearance.colors.colError : Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.32)
                    border.width: 1
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.editTextInvalid ? "格式应为 4 个数字，例如 .43,1.19,1,.4" : "输入 x1,y1,x2,y2；显示时会映射到 0..1 坐标框。"
                color: root.editTextInvalid ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                font.family: Sizes.fontFamily
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Button {
                    text: "取消"
                    flat: true
                    Material.foreground: Appearance.colors.colOnSurfaceVariant
                    onClicked: coordEditPopup.close()
                }

                Button {
                    text: "应用"
                    Material.background: Appearance.colors.colPrimary
                    Material.foreground: Appearance.colors.colOnPrimary
                    onClicked: root.applyCoordinateEdit()
                }
            }
        }
    }
}
