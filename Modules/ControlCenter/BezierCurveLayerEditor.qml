import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

FloatingWindow {
    id: root

    property var parentModal: null
    property var sourceCurve: [0.43, 1.19, 1.0, 0.4, 1, 1]
    property var workingCurve: [0.43, 1.19, 1.0, 0.4, 1, 1]
    property var animationTargetCurve: [0.43, 1.19, 1.0, 0.4, 1, 1]
    property bool fabExpanded: false
    property bool manualInputVisible: false
    property bool manualInputInvalid: false
    property string manualInputText: ""
    property int activePoint: -1
    property bool panning: false
    property bool playing: false
    property int playbackDirection: 1
    property real playhead: 0
    property real pixelsPerUnit: 220
    property real panX: 0
    property real panY: 0
    property real lastMouseX: 0
    property real lastMouseY: 0
    property real renderX1: 0.43
    property real renderY1: 1.19
    property real renderX2: 1.0
    property real renderY2: 0.4

    readonly property real headerInfoWidth: 168

    visible: false
    parentWindow: root.parentModal
    title: qsTr("编辑贝塞尔曲线")
    implicitWidth: 980
    implicitHeight: 720
    minimumSize: Qt.size(560, 460)
    color: "transparent"

    onClosed: root.dismiss()

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => modalContent.forceActiveFocus());
    }

    signal curveEdited(var nextCurve)

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value));
    }

    function defaultCurve() {
        return [0.43, 1.19, 1.0, 0.4, 1, 1];
    }

    function normalizeCurve(source) {
        const defaults = defaultCurve();
        const next = [];
        for (let i = 0; i < 6; i += 1) {
            const value = source && source.length > i ? Number(source[i]) : defaults[i];
            next.push(isFinite(value) ? value : defaults[i]);
        }
        next[4] = 1;
        next[5] = 1;
        return next;
    }

    function dimensionValue(t, p1, p2) {
        const u = 1 - t;
        return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t;
    }

    function dimensionWithinUnit(p1, p2) {
        if (!isFinite(p1) || !isFinite(p2))
            return false;

        const epsilon = 0.0001;
        const values = [0, 1];
        const a = 3 * p1 - 3 * p2 + 1;
        const b = -4 * p1 + 2 * p2;
        const c = p1;

        function addRoot(t) {
            if (isFinite(t) && t > epsilon && t < 1 - epsilon)
                values.push(dimensionValue(t, p1, p2));
        }

        if (Math.abs(a) < 0.000001) {
            if (Math.abs(b) >= 0.000001)
                addRoot(-c / b);
        } else {
            const discriminant = b * b - 4 * a * c;
            if (discriminant >= -epsilon) {
                const root = Math.sqrt(Math.max(0, discriminant));
                addRoot((-b + root) / (2 * a));
                addRoot((-b - root) / (2 * a));
            }
        }

        for (let i = 0; i < values.length; i += 1) {
            if (values[i] < -epsilon || values[i] > 1 + epsilon)
                return false;
        }
        return true;
    }

    function dimensionMonotonicIncreasing(p1, p2) {
        if (!isFinite(p1) || !isFinite(p2))
            return false;

        const epsilon = 0.0001;
        const a = 3 * p1 - 3 * p2 + 1;
        const b = -4 * p1 + 2 * p2;
        const c = p1;
        const values = [c, a + b + c];

        if (Math.abs(a) >= 0.000001) {
            const t = -b / (2 * a);
            if (t > epsilon && t < 1 - epsilon)
                values.push(a * t * t + b * t + c);
        }

        for (let i = 0; i < values.length; i += 1) {
            if (values[i] < -epsilon)
                return false;
        }
        return true;
    }

    function dimensionAllowed(p1, p2, requireFunction) {
        return dimensionWithinUnit(p1, p2) && (!requireFunction || dimensionMonotonicIncreasing(p1, p2));
    }

    function curveWithinUnit(curve) {
        const next = normalizeCurve(curve);
        return dimensionAllowed(next[0], next[2], true) && dimensionAllowed(next[1], next[3], false);
    }

    function constrainedDimension(current, target, fixed, movingFirst, requireFunction) {
        if (!isFinite(target))
            return current;

        function isValid(value) {
            return movingFirst
                ? dimensionAllowed(value, fixed, requireFunction)
                : dimensionAllowed(fixed, value, requireFunction);
        }

        if (isValid(target))
            return target;

        if (!isValid(current))
            return current;

        let valid = current;
        let invalid = target;
        for (let i = 0; i < 24; i += 1) {
            const middle = (valid + invalid) / 2;
            if (isValid(middle))
                valid = middle;
            else
                invalid = middle;
        }
        return valid;
    }

    function safeCurve(source) {
        const next = normalizeCurve(source);
        return curveWithinUnit(next) ? next : defaultCurve();
    }

    function formatNumber(value) {
        const rounded = Math.round(value * 1000) / 1000;
        return rounded.toFixed(3).replace(/\.?0+$/, "");
    }

    function curveText(curve) {
        const c = normalizeCurve(curve || workingCurve);
        return formatNumber(c[0]) + ", " + formatNumber(c[1]) + ", " + formatNumber(c[2]) + ", " + formatNumber(c[3]);
    }

    function copyCurve() {
        Quickshell.execDetached(["wl-copy", curveText([renderX1, renderY1, renderX2, renderY2, 1, 1])]);
    }

    function p1() {
        return [renderX1, renderY1];
    }

    function p2() {
        return [renderX2, renderY2];
    }

    function originX() {
        return editorCanvas.width / 2 - pixelsPerUnit / 2 + panX;
    }

    function originY() {
        return editorCanvas.height / 2 + pixelsPerUnit / 2 + panY;
    }

    function screenX(x) {
        return originX() + x * pixelsPerUnit;
    }

    function screenY(y) {
        return originY() - y * pixelsPerUnit;
    }

    function worldX(x) {
        return (x - originX()) / pixelsPerUnit;
    }

    function worldY(y) {
        return (originY() - y) / pixelsPerUnit;
    }

    function cubicCoord(t, a, b) {
        const u = 1 - t;
        return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t;
    }

    function curvePoint(t) {
        const first = p1();
        const second = p2();
        return [cubicCoord(t, first[0], second[0]), cubicCoord(t, first[1], second[1])];
    }

    function hitTest(mouseX, mouseY) {
        const first = p1();
        const second = p2();
        const d1 = Math.hypot(mouseX - screenX(first[0]), mouseY - screenY(first[1]));
        const d2 = Math.hypot(mouseX - screenX(second[0]), mouseY - screenY(second[1]));
        if (d1 < 18 || d2 < 18)
            return d1 <= d2 ? 0 : 1;
        return -1;
    }

    function setRenderCurve(nextCurve) {
        const next = normalizeCurve(nextCurve);
        renderX1 = next[0];
        renderY1 = next[1];
        renderX2 = next[2];
        renderY2 = next[3];
        editorCanvas.requestPaint();
    }

    function setDraftCurve(nextCurve) {
        const next = normalizeCurve(nextCurve);
        if (!curveWithinUnit(next))
            return false;

        workingCurve = next;
        setRenderCurve(next);
        return true;
    }

    function setControlPoint(index, x, y) {
        const next = normalizeCurve(workingCurve);
        if (index === 0) {
            next[0] = constrainedDimension(next[0], x, next[2], true, true);
            next[1] = constrainedDimension(next[1], y, next[3], true, false);
        } else {
            next[2] = constrainedDimension(next[2], x, next[0], false, true);
            next[3] = constrainedDimension(next[3], y, next[1], false, false);
        }
        setDraftCurve(next);
    }

    function parseCurveText(text) {
        const parts = String(text || "").trim().split(",");
        if (parts.length !== 4)
            return null;

        const next = [];
        for (let i = 0; i < 4; i += 1) {
            const value = Number(parts[i].trim());
            if (!isFinite(value))
                return null;
            next.push(value);
        }
        const curve = [next[0], next[1], next[2], next[3], 1, 1];
        return curveWithinUnit(curve) ? curve : null;
    }

    function applyManualInput() {
        const next = parseCurveText(manualInputText);
        if (next === null) {
            manualInputInvalid = true;
            return;
        }
        manualInputInvalid = false;
        setDraftCurve(next);
    }

    function toggleManualInput() {
        manualInputVisible = !manualInputVisible;
        manualInputInvalid = false;
        if (manualInputVisible) {
            manualInputText = curveText(workingCurve);
            Qt.callLater(() => {
                manualInputPanel.focusInput();
            });
        }
    }

    function resetView() {
        if (editorCanvas.width <= 0 || editorCanvas.height <= 0)
            return;
        pixelsPerUnit = Math.max(140, Math.min(280, Math.min(editorCanvas.width, editorCanvas.height) * 0.46));
        panX = 0;
        panY = 0;
        editorCanvas.requestPaint();
    }

    function saveCurve() {
        const next = normalizeCurve(workingCurve);
        if (!curveWithinUnit(next)) {
            manualInputInvalid = true;
            return;
        }

        root.curveEdited(next);
        root.dismiss();
    }

    function openWithCurve(curve) {
        if (!root.parentModal) {
            console.warn("BezierCurveLayerEditor cannot open without parentModal");
            return;
        }
        sourceCurve = safeCurve(curve);
        workingCurve = sourceCurve.slice();
        setRenderCurve(workingCurve);
        playhead = 0;
        playing = false;
        fabExpanded = false;
        manualInputVisible = false;
        manualInputInvalid = false;
        root.visible = true;
        Qt.callLater(() => {
            resetView();
            modalContent.forceActiveFocus();
        });
    }

    function dismiss() {
        root.visible = false;
        activePoint = -1;
        panning = false;
        playing = false;
        fabExpanded = false;
        manualInputVisible = false;
        playbackAnimation.stop();
        curveAnimation.stop();
    }

    function startPlayback() {
        if (playhead >= 1)
            playhead = 0;
        playbackDirection = 1;
        playing = true;
        playbackAnimation.from = playhead;
        playbackAnimation.to = 1;
        playbackAnimation.duration = Math.max(160, Math.round(1000 * (1 - playhead)));
        playbackAnimation.start();
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
        playbackAnimation.duration = Math.max(160, Math.round(1000 * playhead));
        playbackAnimation.start();
    }

    function togglePlayback() {
        if (playing) {
            playbackAnimation.stop();
            playing = false;
        } else {
            startPlayback();
        }
    }

    function flipCurve() {
        const first = p1();
        const second = p2();
        const next = normalizeCurve([
            1 - second[0],
            1 - second[1],
            1 - first[0],
            1 - first[1],
            1,
            1
        ]);
        if (!curveWithinUnit(next))
            return;

        animationTargetCurve = next;
        curveAnimation.stop();
        curveAnimation.start();
    }

    onWorkingCurveChanged: editorCanvas.requestPaint()
    onPixelsPerUnitChanged: editorCanvas.requestPaint()
    onPanXChanged: editorCanvas.requestPaint()
    onPanYChanged: editorCanvas.requestPaint()
    onRenderX1Changed: editorCanvas.requestPaint()
    onRenderY1Changed: editorCanvas.requestPaint()
    onRenderX2Changed: editorCanvas.requestPaint()
    onRenderY2Changed: editorCanvas.requestPaint()
    onPlayheadChanged: editorCanvas.requestPaint()

    NumberAnimation {
        id: playbackAnimation
        target: root
        property: "playhead"
        easing.type: Easing.Linear
        onStopped: {
            if ((root.playbackDirection > 0 && root.playhead >= 1) || (root.playbackDirection < 0 && root.playhead <= 0))
                root.playing = false;
        }
    }

    ParallelAnimation {
        id: curveAnimation

        NumberAnimation {
            target: root
            property: "renderX1"
            to: root.animationTargetCurve[0]
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "renderY1"
            to: root.animationTargetCurve[1]
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "renderX2"
            to: root.animationTargetCurve[2]
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "renderY2"
            to: root.animationTargetCurve[3]
            duration: Appearance.animation.standard.duration
            easing.type: Appearance.animation.standard.type
            easing.bezierCurve: Appearance.animation.standard.bezierCurve
        }

        onStopped: root.workingCurve = root.animationTargetCurve
    }

        FocusScope {
            id: modalContent

            anchors.fill: parent
            focus: root.visible
            clip: true

            Rectangle {
                id: dialogBackground

                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: BlurService.backgroundColor(
                    Appearance.m3colors.m3surfaceContainerLow)
                antialiasing: true
            }

            CompositorBlurRegion {
                targetWindow: root
                backgroundItem: dialogBackground
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                z: -1
                onPressed: mouse => mouse.accepted = true
                onClicked: mouse => mouse.accepted = true
            }

            Keys.onEscapePressed: event => {
                root.dismiss();
                event.accepted = true;
            }

            Canvas {
                id: editorCanvas

                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    const w = width;
                    const h = height;
                    ctx.clearRect(0, 0, w, h);

                    function roundedPath(x, y, width, height, radius) {
                        const r = Math.max(0, Math.min(radius, width / 2, height / 2));
                        ctx.beginPath();
                        ctx.moveTo(x + r, y);
                        ctx.lineTo(x + width - r, y);
                        ctx.quadraticCurveTo(x + width, y, x + width, y + r);
                        ctx.lineTo(x + width, y + height - r);
                        ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
                        ctx.lineTo(x + r, y + height);
                        ctx.quadraticCurveTo(x, y + height, x, y + height - r);
                        ctx.lineTo(x, y + r);
                        ctx.quadraticCurveTo(x, y, x + r, y);
                        ctx.closePath();
                    }

                    ctx.save();
                    roundedPath(0, 0, w, h, Appearance.rounding.normal - 1);
                    ctx.clip();

                    ctx.fillStyle = Appearance.m3colors.m3surfaceContainerLowest;
                    ctx.fillRect(0, 0, w, h);

                    const minX = root.worldX(0);
                    const maxX = root.worldX(w);
                    const minY = root.worldY(h);
                    const maxY = root.worldY(0);
                    const step = root.pixelsPerUnit >= 320 ? 0.1 : root.pixelsPerUnit >= 160 ? 0.25 : root.pixelsPerUnit >= 80 ? 0.5 : 1;

                    function drawGridLines(gridStep, major) {
                        const xStart = Math.floor(minX / gridStep) * gridStep;
                        const xEnd = Math.ceil(maxX / gridStep) * gridStep;
                        const yStart = Math.floor(minY / gridStep) * gridStep;
                        const yEnd = Math.ceil(maxY / gridStep) * gridStep;
                        ctx.strokeStyle = major
                            ? Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.24)
                            : Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.10);
                        ctx.lineWidth = major ? 1.1 : 0.8;
                        ctx.beginPath();
                        for (let x = xStart; x <= xEnd + gridStep / 2; x += gridStep) {
                            if (major && Math.abs(x - Math.round(x)) > 0.0001)
                                continue;
                            const sx = root.screenX(x);
                            ctx.moveTo(sx, 0);
                            ctx.lineTo(sx, h);
                        }
                        for (let y = yStart; y <= yEnd + gridStep / 2; y += gridStep) {
                            if (major && Math.abs(y - Math.round(y)) > 0.0001)
                                continue;
                            const sy = root.screenY(y);
                            ctx.moveTo(0, sy);
                            ctx.lineTo(w, sy);
                        }
                        ctx.stroke();
                    }

                    drawGridLines(step, false);
                    drawGridLines(1, true);

                    ctx.strokeStyle = Appearance.applyAlpha(Appearance.colors.colPrimary, 0.74);
                    ctx.lineWidth = 1.8;
                    ctx.beginPath();
                    ctx.moveTo(root.screenX(0), 0);
                    ctx.lineTo(root.screenX(0), h);
                    ctx.moveTo(0, root.screenY(0));
                    ctx.lineTo(w, root.screenY(0));
                    ctx.stroke();

                    ctx.strokeStyle = Appearance.applyAlpha(Appearance.colors.colSecondary, 0.74);
                    ctx.lineWidth = 1.6;
                    ctx.setLineDash([7, 5]);
                    ctx.strokeRect(root.screenX(0), root.screenY(1), root.pixelsPerUnit, root.pixelsPerUnit);
                    ctx.setLineDash([]);

                    const first = root.p1();
                    const second = root.p2();
                    const startX = root.screenX(0);
                    const startY = root.screenY(0);
                    const endX = root.screenX(1);
                    const endY = root.screenY(1);
                    const p1x = root.screenX(first[0]);
                    const p1y = root.screenY(first[1]);
                    const p2x = root.screenX(second[0]);
                    const p2y = root.screenY(second[1]);

                    ctx.strokeStyle = Appearance.applyAlpha(Appearance.colors.colSecondary, 0.78);
                    ctx.lineWidth = 1.8;
                    ctx.setLineDash([8, 6]);
                    ctx.beginPath();
                    ctx.moveTo(startX, startY);
                    ctx.lineTo(p1x, p1y);
                    ctx.moveTo(endX, endY);
                    ctx.lineTo(p2x, p2y);
                    ctx.stroke();
                    ctx.setLineDash([]);

                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.strokeStyle = Appearance.colors.colPrimary;
                    ctx.lineWidth = 3.6;
                    ctx.beginPath();
                    for (let i = 0; i <= 180; i += 1) {
                        const t = i / 180;
                        const point = root.curvePoint(t);
                        if (i === 0)
                            ctx.moveTo(root.screenX(point[0]), root.screenY(point[1]));
                        else
                            ctx.lineTo(root.screenX(point[0]), root.screenY(point[1]));
                    }
                    ctx.stroke();

                    const playPoint = root.curvePoint(root.playhead);
                    ctx.fillStyle = Appearance.colors.colTertiary;
                    ctx.beginPath();
                    ctx.arc(root.screenX(playPoint[0]), root.screenY(playPoint[1]), 9, 0, Math.PI * 2);
                    ctx.fill();

                    function drawEndpoint(x, y) {
                        ctx.fillStyle = Appearance.colors.colPrimary;
                        ctx.beginPath();
                        ctx.arc(x, y, 5, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    function drawControlPoint(x, y, selected) {
                        const side = selected ? 17 : 15;
                        ctx.fillStyle = Appearance.m3colors.m3surfaceContainerLowest;
                        ctx.strokeStyle = selected ? Appearance.colors.colTertiary : Appearance.colors.colSecondary;
                        ctx.lineWidth = selected ? 2.7 : 2.2;
                        ctx.beginPath();
                        ctx.rect(x - side / 2, y - side / 2, side, side);
                        ctx.fill();
                        ctx.stroke();
                    }

                    drawEndpoint(startX, startY);
                    drawEndpoint(endX, endY);
                    drawControlPoint(p1x, p1y, root.activePoint === 0);
                    drawControlPoint(p2x, p2y, root.activePoint === 1);

                    ctx.restore();
                }
            }

            MouseArea {
                anchors.fill: editorCanvas
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                preventStealing: true
                cursorShape: root.activePoint >= 0 || root.panning ? Qt.ClosedHandCursor : root.hitTest(mouseX, mouseY) >= 0 ? Qt.PointingHandCursor : Qt.OpenHandCursor

                onPressed: mouse => {
                    const hit = root.hitTest(mouse.x, mouse.y);
                    root.lastMouseX = mouse.x;
                    root.lastMouseY = mouse.y;
                    if (hit >= 0) {
                        root.activePoint = hit;
                    } else {
                        root.panning = true;
                    }
                    editorCanvas.requestPaint();
                }

                onPositionChanged: mouse => {
                    if (root.activePoint >= 0) {
                        root.setControlPoint(root.activePoint, root.worldX(mouse.x), root.worldY(mouse.y));
                        return;
                    }

                    if (root.panning) {
                        root.panX += mouse.x - root.lastMouseX;
                        root.panY += mouse.y - root.lastMouseY;
                        root.lastMouseX = mouse.x;
                        root.lastMouseY = mouse.y;
                        editorCanvas.requestPaint();
                    }
                }

                onReleased: {
                    root.activePoint = -1;
                    root.panning = false;
                    editorCanvas.requestPaint();
                }

                onCanceled: {
                    root.activePoint = -1;
                    root.panning = false;
                    editorCanvas.requestPaint();
                }

                onWheel: wheel => {
                    const beforeX = root.worldX(wheel.x);
                    const beforeY = root.worldY(wheel.y);
                    const factor = wheel.angleDelta.y > 0 ? 1.12 : 0.89;
                    root.pixelsPerUnit = Math.max(48, Math.min(720, root.pixelsPerUnit * factor));
                    root.panX = wheel.x - (editorCanvas.width / 2 - root.pixelsPerUnit / 2) - beforeX * root.pixelsPerUnit;
                    root.panY = wheel.y + beforeY * root.pixelsPerUnit - editorCanvas.height / 2 - root.pixelsPerUnit / 2;
                    wheel.accepted = true;
                    editorCanvas.requestPaint();
                }
            }

            Item {
                id: topOverlay

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 18
                anchors.topMargin: 18
                width: root.headerInfoWidth
                height: infoColumn.implicitHeight

                ColumnLayout {
                    id: infoColumn

                    anchors.fill: parent
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: "P1 " + root.formatNumber(root.renderX1) + ", " + root.formatNumber(root.renderY1)
                        color: Appearance.colors.colSubtext
                        font.family: Fonts.mono
                        font.pixelSize: 12
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 9
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "P2 " + root.formatNumber(root.renderX2) + ", " + root.formatNumber(root.renderY2)
                        color: Appearance.colors.colSubtext
                        font.family: Fonts.mono
                        font.pixelSize: 12
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 9
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                    }
                }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 14
                anchors.topMargin: 14
                spacing: 8

                EditorIconButton {
                    iconName: "content_copy"
                    tooltipText: qsTr("复制")
                    onClicked: root.copyCurve()
                }

                EditorIconButton {
                    iconName: "save"
                    tooltipText: qsTr("保存")
                    onClicked: root.saveCurve()
                }

                EditorIconButton {
                    iconName: "center_focus_strong"
                    tooltipText: qsTr("重置视图")
                    onClicked: root.resetView()
                }

                EditorIconButton {
                    iconName: "close"
                    tooltipText: qsTr("关闭")
                    onClicked: root.dismiss()
                }
            }

            ManualInputBox {
                id: manualInputPanel

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.bottomMargin: 14
                width: Math.min(380, parent.width - 116)
                visible: opacity > 0
                opacity: root.manualInputVisible ? 1 : 0
                scale: root.manualInputVisible ? 1 : 0.96

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveEffects.duration
                        easing.type: Appearance.animation.expressiveEffects.type
                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.standard.duration
                        easing.type: Appearance.animation.standard.type
                        easing.bezierCurve: Appearance.animation.standard.bezierCurve
                    }
                }
            }

            Item {
                id: fabMenu

                readonly property real collapsedMainSize: 72
                readonly property real expandedMainSize: 50
                readonly property real actionSize: 50
                readonly property real actionGap: 4
                readonly property real mainGap: 8
                readonly property int actionCount: 4

                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 18
                anchors.bottomMargin: 18
                width: Math.max(collapsedMainSize, playMiniFab.implicitWidth, reverseMiniFab.implicitWidth, flipMiniFab.implicitWidth, manualMiniFab.implicitWidth)
                height: expandedMainSize + mainGap + actionCount * actionSize + (actionCount - 1) * actionGap

                Item {
                    id: menuColumn

                    anchors.fill: parent

                    MiniFab {
                        id: playMiniFab

                        iconName: root.playing ? "pause" : "play_arrow"
                        labelText: root.playing ? qsTr("暂停") : qsTr("播放")
                        expanded: root.fabExpanded
                        order: 4
                        itemCount: fabMenu.actionCount
                        actionSize: fabMenu.actionSize
                        expandedY: fabMenu.height - fabMenu.expandedMainSize - fabMenu.mainGap - order * fabMenu.actionSize - (order - 1) * fabMenu.actionGap
                        onClicked: root.togglePlayback()
                    }

                    MiniFab {
                        id: reverseMiniFab

                        iconName: "keyboard_double_arrow_left"
                        labelText: qsTr("倒放")
                        expanded: root.fabExpanded
                        order: 3
                        itemCount: fabMenu.actionCount
                        actionSize: fabMenu.actionSize
                        expandedY: fabMenu.height - fabMenu.expandedMainSize - fabMenu.mainGap - order * fabMenu.actionSize - (order - 1) * fabMenu.actionGap
                        onClicked: root.reversePlayback()
                    }

                    MiniFab {
                        id: flipMiniFab

                        iconName: "swap_vert"
                        labelText: qsTr("翻转")
                        expanded: root.fabExpanded
                        order: 2
                        itemCount: fabMenu.actionCount
                        actionSize: fabMenu.actionSize
                        expandedY: fabMenu.height - fabMenu.expandedMainSize - fabMenu.mainGap - order * fabMenu.actionSize - (order - 1) * fabMenu.actionGap
                        onClicked: root.flipCurve()
                    }

                    MiniFab {
                        id: manualMiniFab

                        iconName: "edit_note"
                        labelText: qsTr("手动输入")
                        expanded: root.fabExpanded
                        order: 1
                        itemCount: fabMenu.actionCount
                        actionSize: fabMenu.actionSize
                        expandedY: fabMenu.height - fabMenu.expandedMainSize - fabMenu.mainGap - order * fabMenu.actionSize - (order - 1) * fabMenu.actionGap
                        onClicked: root.toggleManualInput()
                    }

                    MainFab {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        expanded: root.fabExpanded
                        collapsedSize: fabMenu.collapsedMainSize
                        expandedSize: fabMenu.expandedMainSize
                        onClicked: root.fabExpanded = !root.fabExpanded
                    }
                }
            }

        }

    component EditorIconButton: IconButton {
        controlSize: 36
        iconSize: 20
        iconColor: Appearance.colors.colOnSurface
        normalContainerColor: Appearance.colors.colLayer2
        hoverStateLayerColor: Appearance.colors.colLayer4
        pressedStateLayerColor: Appearance.colors.colLayer4Active
    }

    component MainFab: Item {
        id: fab

        property bool expanded: false
        property real collapsedSize: 72
        property real expandedSize: 50
        property real collapsedRadius: 18
        property real morphProgress: expanded ? 1 : 0
        readonly property QtObject spatialMotion: Appearance.animation.elementMoveFast
        readonly property real currentSize: collapsedSize
            + (expandedSize - collapsedSize) * morphProgress
        readonly property real currentRadius: collapsedRadius
            + (expandedSize / 2 - collapsedRadius) * morphProgress

        signal clicked

        implicitWidth: collapsedSize
        implicitHeight: collapsedSize
        width: currentSize
        height: currentSize

        Behavior on morphProgress {
            NumberAnimation {
                duration: fab.spatialMotion.duration
                easing.type: fab.spatialMotion.type
                easing.bezierCurve: fab.spatialMotion.bezierCurve
            }
        }

        RippleButton {
            id: mainFabButton

            anchors.fill: parent
            buttonRadius: Math.min(width / 2, fab.currentRadius)
            containerColor: Appearance.colors.colPrimary
            rippleColor: Appearance.colors.colOnPrimary
            stateLayerColor: Appearance.colors.colPrimaryHover
            pressedStateLayerColor: Appearance.colors.colPrimaryActive
            onClicked: fab.clicked()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "add"
                iconSize: 28 - 5 * fab.morphProgress
                color: Appearance.colors.colOnPrimary
                rotation: 45 * fab.morphProgress
            }
        }
    }

    component MiniFab: Item {
        id: miniFab

        property string iconName: ""
        property string labelText: ""
        property bool expanded: false
        property int order: 0
        property int itemCount: 1
        property real actionSize: 50
        property real expandedY: 0
        property real collapsedWidth: actionSize
        property real revealProgress: expanded ? 1 : 0
        readonly property real horizontalPadding: 16
        readonly property int motionDelay: expanded
            ? (order - 1) * 18
            : (itemCount - order) * 12
        readonly property QtObject spatialMotion: Appearance.animation.elementMoveFast
        readonly property real visibleProgress: Math.max(0, Math.min(1, revealProgress))

        signal clicked

        implicitWidth: Math.max(collapsedWidth, contentRow.implicitWidth + horizontalPadding * 2)
        width: collapsedWidth + (implicitWidth - collapsedWidth) * revealProgress
        height: actionSize
        opacity: Math.max(0, Math.min(1, visibleProgress * 1.5))
        scale: 0.72 + 0.28 * revealProgress
        transformOrigin: Item.Right
        enabled: expanded && revealProgress > 0.8
        x: parent ? parent.width - width : 0
        y: expandedY

        Behavior on revealProgress {
            SequentialAnimation {
                PauseAnimation {
                    duration: miniFab.motionDelay
                }
                NumberAnimation {
                    duration: miniFab.spatialMotion.duration
                    easing.type: miniFab.spatialMotion.type
                    easing.bezierCurve: miniFab.spatialMotion.bezierCurve
                }
            }
        }

        RippleButton {
            id: miniButton

            anchors.fill: parent
            buttonRadius: height / 2
            containerColor: Appearance.colors.colPrimaryContainer
            rippleColor: Appearance.colors.colOnPrimaryContainer
            stateLayerColor: Appearance.colors.colPrimaryContainerHover
            pressedStateLayerColor: Appearance.colors.colPrimaryContainerActive
            enabled: miniFab.enabled
            onClicked: miniFab.clicked()

            contentItem: ButtonLabel {
                id: contentRow

                iconName: miniFab.iconName
                primaryText: miniFab.labelText
                spacing: 8
                iconSize: 20
                iconFill: miniButton.pointerHovered ? 1 : 0
                iconColor: Appearance.colors.colOnPrimaryContainer
                primaryColor: Appearance.colors.colOnPrimaryContainer
                primaryPixelSize: 13
            }
        }
    }

    component ManualInputBox: Rectangle {
        id: inputBox

        implicitHeight: 92
        radius: Appearance.rounding.normal
        color: Appearance.applyAlpha(Appearance.m3colors.m3surfaceContainerHigh, 0.92)
        border.width: 1
        border.color: root.manualInputInvalid ? Appearance.colors.colError : Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.22)

        function focusInput() {
            manualInput.forceActiveFocus();
            manualInput.selectAll();
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 64

                Rectangle {
                    id: outlinedInputFrame

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 56
                    radius: Appearance.rounding.small
                    color: "transparent"
                    border.width: 1
                    border.color: root.manualInputInvalid
                                  ? Appearance.colors.colError
                                  : manualInput.activeFocus
                                    ? Appearance.colors.colPrimary
                                    : Appearance.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.32)
                }

                Rectangle {
                    x: outlinedInputLabel.x - 4
                    y: outlinedInputLabel.y + outlinedInputLabel.height / 2 - 8
                    width: outlinedInputLabel.implicitWidth + 8
                    height: 16
                    color: Appearance.m3colors.m3surfaceContainerHigh
                }

                Text {
                    id: outlinedInputLabel

                    x: 14
                    y: 0
                    text: "x1, y1, x2, y2"
                    color: root.manualInputInvalid ? Appearance.colors.colError : manualInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    font.family: Fonts.ui
                    font.pixelSize: 12
                }

                TextField {
                    id: manualInput

                    anchors.fill: outlinedInputFrame
                    text: root.manualInputText
                    color: Appearance.colors.colOnSurface
                    selectedTextColor: Appearance.colors.colOnPrimary
                    selectionColor: Appearance.colors.colPrimary
                    selectByMouse: true
                    font.family: Fonts.mono
                    font.pixelSize: 13
                    leftPadding: 16
                    rightPadding: 12
                    topPadding: 14
                    bottomPadding: 4
                    verticalAlignment: TextInput.AlignVCenter
                    Material.accent: Appearance.colors.colPrimary
                    background: Item {}
                    onTextChanged: {
                        root.manualInputText = text;
                        root.manualInputInvalid = false;
                    }
                    onAccepted: root.applyManualInput()
                    Keys.onEscapePressed: event => {
                        root.manualInputVisible = false;
                        event.accepted = true;
                    }
                }
            }

            EditorIconButton {
                iconName: "check"
                tooltipText: qsTr("应用到草稿")
                onClicked: root.applyManualInput()
            }
        }
    }
}
