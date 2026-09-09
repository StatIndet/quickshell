/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/.
*
* Adapted from Zen Browser, commit 412731f37e567223097101d9fae9f9d364708b6b.
* See licenses/README.md for source mapping and modification details.
* Alternatively, the contents of this file may be used under the terms
* of the GNU General Public License Version 3 or (at your option) later.
* This file is free software: you may copy, redistribute and/or modify it
* under those terms as published by the Free Software Foundation.
* This file is distributed WITHOUT ANY WARRANTY; without even the implied
* warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
* You should have received a copy of the GNU General Public License along
* with this program. If not, see https://www.gnu.org/licenses/.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common
import "../../Common/functions/ZenPalette.js" as Zen

ColumnLayout {
    id: root
    required property var paletteState
    property int page: 0
    property bool draggingPoints: false
    readonly property var points: Zen.positions(paletteState)
    readonly property var colors: Zen.colors(paletteState)
    readonly property var algorithmNames: ({
                                               floating: qsTr("Single color"),
                                               complementary: qsTr("Complementary"),
                                               singleAnalogous: qsTr("Analogous"),
                                               splitComplementary: qsTr("Split complementary"),
                                               analogous: qsTr("Analogous"),
                                               triadic: qsTr("Triadic")
                                           })
    signal edited(var value)
    function change(key, value) {
        var next = Zen.copy(root.paletteState);
        next[key] = value;
        root.edited(next);
    }
    spacing: 8
    Rectangle {
        id: pad
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 250
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer2Base
        clip: true
        Canvas {
            id: grid
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "#22888888";
                for (let y = 3; y < height; y += 6)
                    for (let x = 3; x < width; x += 6) {
                        ctx.beginPath();
                        ctx.arc(x, y, 0.7, 0, Math.PI * 2);
                        ctx.fill();
                    }
            }
        }
        MouseArea {
            anchors.fill: parent
            property point pressPosition
            function updatePosition(mouse) {
                const p = mapToItem(wheel, mouse.x, mouse.y);
                root.edited(Zen.move(root.paletteState, p.x / wheel.width, p.y / wheel.height, 0));
            }
            onPressed: mouse => {
                root.draggingPoints = false;
                pressPosition = Qt.point(mouse.x, mouse.y);
                updatePosition(mouse);
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                if (!root.draggingPoints && Math.abs(mouse.x - pressPosition.x) + Math.abs(mouse.y
                                                                                           - pressPosition.y)
                        < 3)
                    return;
                root.draggingPoints = true;
                updatePosition(mouse);
            }
            onReleased: root.draggingPoints = false
            onCanceled: root.draggingPoints = false
        }
        Item {
            id: wheel
            width: Math.min(parent.width, parent.height) - 48
            height: width
            anchors.centerIn: parent
            Repeater {
                model: root.points.length
                Rectangle {
                    id: dot
                    required property int index
                    width: index === 0 ? 50 : 26
                    height: width
                    radius: width / 2
                    // Animation state is separate from the authoritative draft.
                    // Normalized positions avoid animating geometry on resize.
                    property bool initialized: false
                    property real displayX: root.points[index].x
                    property real displayY: root.points[index].y
                    x: displayX * wheel.width - width / 2
                    y: displayY * wheel.height - height / 2
                    Component.onCompleted: initialized = true
                    Behavior on displayX {
                        enabled: dot.initialized && !root.draggingPoints
                        NumberAnimation {
                            duration: Animations.animation.expressiveFastSpatial.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Animations.animation.expressiveFastSpatial.bezierCurve
                        }
                    }
                    Behavior on displayY {
                        enabled: dot.initialized && !root.draggingPoints
                        NumberAnimation {
                            duration: Animations.animation.expressiveFastSpatial.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Animations.animation.expressiveFastSpatial.bezierCurve
                        }
                    }
                    color: Zen.hex(root.colors[index])
                    border.width: index === 0 ? 6 : 3
                    border.color: "#ffffff"
                    scale: drag.pressed ? 1.15 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                    Accessible.name: index === 0 ? qsTr("Primary color") : qsTr("Color %1").arg(index + 1)
                    Accessible.role: Accessible.Button
                    HoverHandler {
                        cursorShape: Qt.OpenHandCursor
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        property bool moved: false
                        property point origin
                        onPressed: mouse => {
                            moved = false;
                            root.draggingPoints = false;
                            origin = mapToItem(pad, mouse.x, mouse.y);
                        }
                        onPositionChanged: mouse => {
                            if (!pressed || pressedButtons !== Qt.LeftButton)
                                return;
                            const pointer = mapToItem(pad, mouse.x, mouse.y);
                            if (!moved && Math.abs(pointer.x - origin.x) + Math.abs(pointer.y - origin.y) < 3)
                                return;
                            moved = true;
                            root.draggingPoints = true;
                            const p = mapToItem(wheel, mouse.x, mouse.y);
                            root.edited(Zen.move(root.paletteState, p.x / wheel.width, p.y / wheel.height,
                                                 dot.index));
                        }
                        onReleased: root.draggingPoints = false
                        onCanceled: root.draggingPoints = false
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (root.paletteState.count > 1)
                                    root.edited(Zen.remove(root.paletteState, dot.index));
                            } else if (!moved && dot.index > 0) {
                                const next = Zen.copy(root.paletteState);
                                next.x = root.points[dot.index].x;
                                next.y = root.points[dot.index].y;
                                root.edited(next);
                            }
                        }
                    }
                }
            }
        }
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: 8
            IconButton {
                iconName: "add"
                tooltipText: qsTr("Add color")
                enabled: root.paletteState.count < 3
                onClicked: root.edited(Zen.resize(root.paletteState, root.paletteState.count + 1))
            }
            IconButton {
                iconName: "remove"
                tooltipText: qsTr("Remove color")
                enabled: root.paletteState.count > 1
                onClicked: root.edited(Zen.resize(root.paletteState, root.paletteState.count - 1))
            }
            IconButton {
                iconName: "shuffle"
                enabled: root.paletteState.count > 1
                tooltipText: root.algorithmNames[root.paletteState.algorithm]
                onClicked: {
                    const choices = Zen.algorithms(root.paletteState.count);
                    root.change("algorithm", choices[(choices.indexOf(root.paletteState.algorithm) + 1)
                                                     % choices.length]);
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        IconButton {
            iconName: "chevron_left"
            Accessible.name: qsTr("Previous presets")
            enabled: root.page > 0
            onClicked: root.page--
        }
        Item {
            id: presetViewport
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            clip: true
            // Animate page units so resizing never adds a second scrolling motion.
            property real displayedPage: root.page
            Behavior on displayedPage {
                NumberAnimation {
                    duration: Animations.animation.standard.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Animations.animation.standard.bezierCurve
                }
            }
            Row {
                x: -presetViewport.displayedPage * presetViewport.width
                height: parent.height
                Repeater {
                    model: 5
                    RowLayout {
                        id: presetPage
                        required property int index
                        width: presetViewport.width
                        height: presetViewport.height
                        spacing: 4
                        Repeater {
                            model: presetPage.index === 4 ? 9 : 8
                            Item {
                                id: presetItem
                                required property int index
                                readonly property int presetIndex: presetPage.index * 8 + index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                Canvas {
                                    id: swatch
                                    anchors.centerIn: parent
                                    width: 26
                                    height: width
                                    property var colors: Zen.swatches[presetItem.presetIndex]
                                    onColorsChanged: requestPaint()
                                    scale: presetMouse.pressed ? 0.95 : presetMouse.containsMouse ? 1.05 : 1
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 100
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Animations.curves.standard
                                        }
                                    }
                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.beginPath();
                                        ctx.arc(width / 2, height / 2, width / 2, 0, Math.PI * 2);
                                        ctx.clip();
                                        if (colors.length === 1) {
                                            ctx.fillStyle = colors[0];
                                            ctx.fillRect(0, 0, width, height);
                                        } else {
                                            // CSS backgrounds paint last to first, with premultiplied alpha.
                                            let gradient = ctx.createLinearGradient(0, height, 0, height
                                                                                    * 0.4);
                                            gradient.addColorStop(0, colors[2]);
                                            gradient.addColorStop(1, "transparent");
                                            ctx.fillStyle = gradient;
                                            ctx.fillRect(0, 0, width, height);
                                            for (let i = 1; i >= 0; --i) {
                                                const x = i === 0 ? 0 : width;
                                                gradient = ctx.createRadialGradient(x, 0, 0, x, 0, Math.sqrt(
                                                                                        width * width
                                                                                        + height * height));
                                                gradient.addColorStop(0, colors[i]);
                                                gradient.addColorStop(1, "transparent");
                                                ctx.fillStyle = gradient;
                                                ctx.fillRect(0, 0, width, height);
                                            }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: presetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.edited(Zen.preset(presetItem.presetIndex,
                                                                      root.paletteState))
                                }
                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Preset %1").arg(presetIndex + 1)
                            }
                        }
                    }
                }
            }
        }
        IconButton {
            iconName: "chevron_right"
            Accessible.name: qsTr("Next presets")
            enabled: root.page < 4
            onClicked: root.page++
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Slider {
            id: opacitySlider
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            from: 0.25
            to: 0.8
            stepSize: 0.001
            hoverEnabled: true
            Accessible.name: qsTr("Opacity")
            Binding {
                target: opacitySlider
                property: "value"
                value: root.paletteState.opacity
                when: !opacitySlider.pressed
            }
            onMoved: root.change("opacity", value)
            readonly property real progress: (root.paletteState.opacity - 0.25) / 0.55
            leftPadding: 15
            rightPadding: 15
            background: Item {
                y: (opacitySlider.height - height) / 2
                width: opacitySlider.width
                height: 48
                Rectangle {
                    x: opacitySlider.leftPadding - 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: opacitySlider.availableWidth + 6
                    height: 18
                    radius: height / 2
                    color: UiPreferences.darkMode ? "#1affffff" : "#1a000000"
                }
                Canvas {
                    id: wave
                    anchors.fill: parent
                    property real progress: opacitySlider.progress
                    property real visualProgress: opacitySlider.visualPosition
                    property bool dark: UiPreferences.darkMode
                    onProgressChanged: requestPaint()
                    onVisualProgressChanged: requestPaint()
                    onDarkChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const start = opacitySlider.leftPadding;
                        const span = opacitySlider.availableWidth;
                        const split = start + visualProgress * span;
                        const center = height / 2;
                        // Zen's SVG has six waves made of cubic half-wave segments.
                        // Interpolate their control-point heights from a flat line.
                        const amplitude = 35.898 / 70 * height * progress;
                        function drawWave(color) {
                            ctx.strokeStyle = color;
                            ctx.lineWidth = 5;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.beginPath();
                            ctx.moveTo(start, center);
                            for (let i = 0; i < 12; ++i) {
                                const x = start + i * span / 12;
                                const segment = span / 12;
                                const y = center + (i % 2 === 0 ? -amplitude : amplitude);
                                ctx.bezierCurveTo(x + segment / 3, y, x + segment * 2 / 3, y, x + segment,
                                                  center);
                            }
                            ctx.stroke();
                        }
                        // Clip only the color split; the canvas includes room for both round caps.
                        const active = dark ? "rgb(161,161,161)" : "rgb(90,90,90)";
                        const inactive = dark ? "rgba(161,161,161,0.5)" : "rgba(77,77,77,0.5)";
                        for (let side = 0; side < 2; ++side) {
                            ctx.save();
                            ctx.beginPath();
                            ctx.rect(side === 0 ? 0 : split, 0, side === 0 ? split : width - split, height);
                            ctx.clip();
                            const filled = opacitySlider.mirrored ? side === 1 : side === 0;
                            drawWave(filled && progress > 0.001 ? active : inactive);
                            ctx.restore();
                        }
                    }
                }
            }
            handle: Rectangle {
                width: 10 + opacitySlider.progress * 15
                height: 40 + opacitySlider.progress * 15
                radius: width / 2
                x: opacitySlider.leftPadding + opacitySlider.visualPosition * opacitySlider.availableWidth
                   - width / 2
                y: (opacitySlider.height - height) / 2
                color: UiPreferences.darkMode ? "#ffffff" : "#000000"
                scale: opacitySlider.pressed ? 1.06 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
            StyledToolTip {
                text: qsTr("Opacity: %1%").arg(Math.round(root.paletteState.opacity * 100))
                extraVisibleCondition: opacitySlider.hovered || opacitySlider.pressed
            }
        }
        Item {
            id: knob
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            Accessible.name: qsTr("Grain")
            Accessible.role: Accessible.Slider
            focus: knobMouse.pressed
            Keys.onLeftPressed: root.change("grain", Math.max(0, root.paletteState.grain - 1 / 16))
            Keys.onRightPressed: root.change("grain", Math.min(15 / 16, root.paletteState.grain + 1 / 16))
            readonly property real ringRadius: width / 2 - 4
            Repeater {
                model: 16
                Rectangle {
                    required property int index
                    width: 4
                    height: 4
                    radius: 2
                    x: knob.width / 2 - width / 2 + knob.ringRadius * Math.sin(index * Math.PI / 8)
                    y: knob.height / 2 - height / 2 - knob.ringRadius * Math.cos(index * Math.PI / 8)
                    color: UiPreferences.darkMode ? "#4dffffff" : "#4d000000"
                    opacity: index <= root.paletteState.grain * 16 ? 1 : 0.4
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }
            }
            Canvas {
                anchors.centerIn: parent
                width: knob.width * 0.6
                height: width
                property real amount: root.paletteState.grain
                property bool dark: UiPreferences.darkMode
                property color base: Appearance.colors.colLayer2Base
                onAmountChanged: requestPaint()
                onDarkChanged: requestPaint()
                onBaseChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, width / 2 - 0.5, 0, Math.PI * 2);
                    ctx.save();
                    ctx.clip();
                    // Stationary monochrome texture with the knob's hard-light blend.
                    function blend(c, n) {
                        return n < 0.5 ? 2 * c * n : 1 - 2 * (1 - c) * (1 - n);
                    }
                    for (let y = 0; y < height; ++y)
                        for (let x = 0; x < width; ++x) {
                            let hash = Math.imul(x, 0x9e3779b9) ^ Math.imul(y, 0x85ebca6b);
                            hash = Math.imul(hash ^ (hash >>> 16), 0x7feb352d);
                            hash = Math.imul(hash ^ (hash >>> 15), 0x846ca68b);
                            const n = ((hash ^ (hash >>> 16)) >>> 8) / 16777216;
                            ctx.fillStyle = Qt.rgba(blend(base.r, n), blend(base.g, n), blend(base.b, n),
                                                    amount * 0.25);
                            ctx.fillRect(x, y, 1, 1);
                        }
                    // Zen's subtle diagonal face shading is above the texture.
                    const shade = ctx.createLinearGradient(width, height, 0, 0);
                    shade.addColorStop(0, dark ? "rgba(255,255,255,0.008)" : "rgba(0,0,0,0.008)");
                    shade.addColorStop(1, dark ? "rgba(255,255,255,0.092)" : "rgba(0,0,0,0.092)");
                    ctx.fillStyle = shade;
                    ctx.fillRect(0, 0, width, height);
                    ctx.restore();
                    ctx.strokeStyle = dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)";
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }
            Rectangle {
                width: 6
                height: indicatorHover.hovered || knobMouse.pressed ? 14 : 12
                radius: 2
                x: knob.width / 2 + knob.ringRadius * Math.sin(root.paletteState.grain * Math.PI * 2) - width
                   / 2
                y: knob.height / 2 - knob.ringRadius * Math.cos(root.paletteState.grain * Math.PI * 2)
                   - height / 2
                rotation: root.paletteState.grain * 360
                color: UiPreferences.darkMode ? "#d1d1d1" : "#757575"
                Behavior on height {
                    NumberAnimation {
                        duration: 100
                    }
                }
                HoverHandler {
                    id: indicatorHover
                }
            }
            MouseArea {
                id: knobMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function updateValue(mouse) {
                    let angle = (Math.atan2(mouse.y - knob.height / 2, mouse.x - knob.width / 2) * 180
                                 / Math.PI + 450) % 360;
                    root.change("grain", (Math.round(angle / 360 * 16) % 16) / 16);
                }
                onPressed: mouse => updateValue(mouse)
                onPositionChanged: mouse => {
                    if (pressed)
                        updateValue(mouse);
                }
            }
            StyledToolTip {
                text: qsTr("Grain: %1%").arg(Math.round(root.paletteState.grain * 100))
                extraVisibleCondition: knobMouse.containsMouse
            }
        }
    }
}
