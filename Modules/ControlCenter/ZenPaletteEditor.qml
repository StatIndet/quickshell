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
import qs.Widgets.common
import qs.Modules.Wallpaper
import "../../Common/functions/ZenPalette.js" as Zen

ColumnLayout {
    id: root
    required property var paletteState
    property int page: 0
    property bool draggingPoints: false
    readonly property var points: Zen.positions(paletteState)
    readonly property var colors: Zen.colors(paletteState)
    readonly property var pageNames: [qsTr("Light"), qsTr("Light gradients"), qsTr("Dark"), qsTr("Dark gradients"),
        qsTr("Grayscale")]
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
        color: Appearance.colors.colLayer2
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
                    width: index === 0 ? 38 : 28
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
                            duration: Animations.animation.expressiveDefaultSpatial.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Animations.animation.expressiveDefaultSpatial.bezierCurve
                        }
                    }
                    Behavior on displayY {
                        enabled: dot.initialized && !root.draggingPoints
                        NumberAnimation {
                            duration: Animations.animation.expressiveDefaultSpatial.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Animations.animation.expressiveDefaultSpatial.bezierCurve
                        }
                    }
                    color: Zen.hex(root.colors[index])
                    border.width: index === 0 ? 5 : 3
                    border.color: index === 0 ? Appearance.colors.colOnSurface : Appearance.colors.colSurface
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
            anchors.right: parent.right
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
        IconButton {
            iconName: "chevron_left"
            tooltipText: qsTr("Previous presets")
            enabled: root.page > 0
            onClicked: root.page--
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.pageNames[root.page]
            color: Appearance.colors.colOnSurface
            font.family: Fonts.ui
        }
        IconButton {
            iconName: "chevron_right"
            tooltipText: qsTr("Next presets")
            enabled: root.page < 4
            onClicked: root.page++
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.page === 4 ? 9 : 8
            Item {
                id: presetItem
                required property int index
                readonly property var value: Zen.preset(root.page * 8 + index, root.paletteState)
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                clip: true
                ZenPaletteRenderer {
                    anchors.fill: parent
                    paletteState: presetItem.value
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.edited(presetItem.value)
                }
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Preset %1").arg(root.page * 8 + index + 1)
            }
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
            background: Canvas {
                id: wave
                x: 15
                y: 15
                width: Math.max(1, opacitySlider.width - 30)
                height: 48
                property real progress: opacitySlider.progress
                property color strokeColor: Appearance.colors.colOnSurfaceVariant
                onProgressChanged: requestPaint()
                onStrokeColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.lineWidth = 4;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = strokeColor;
                    ctx.beginPath();
                    for (let x = 0; x <= width; x++) {
                        const y = height / 2 + Math.sin(x / width * Math.PI * 24) * progress * 12;
                        if (x === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }
            }
            handle: Rectangle {
                width: 10 + opacitySlider.progress * 15
                height: 40 + opacitySlider.progress * 15
                radius: width / 2
                x: 15 + opacitySlider.visualPosition * (opacitySlider.width - 30) - width / 2
                y: (opacitySlider.height - height) / 2
                color: Appearance.colors.colPrimary
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
            Repeater {
                model: 16
                Rectangle {
                    required property int index
                    width: 4
                    height: 4
                    radius: 2
                    x: 38 + 34 * Math.sin(index * Math.PI / 8)
                    y: 38 - 34 * Math.cos(index * Math.PI / 8)
                    color: index <= root.paletteState.grain * 16 ? Appearance.colors.colPrimary :
                                                                   Appearance.colors.colOutline
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 48
                height: 48
                radius: 24
                color: Appearance.colors.colLayer3
                border.color: Appearance.colors.colOutline
                rotation: root.paletteState.grain * 360
                Canvas {
                    anchors.fill: parent
                    property real amount: root.paletteState.grain
                    property color base: Appearance.colors.colLayer3
                    onAmountChanged: requestPaint()
                    onBaseChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2 - 1, 0, Math.PI * 2);
                        ctx.clip();
                        function blend(c, n) {
                            return n < 0.5 ? 2 * c * n : 1 - 2 * (1 - c) * (1 - n);
                        }
                        for (let y = 0; y < height; y += 2)
                            for (let x = 0; x < width; x += 2) {
                                const n = Math.abs(Math.sin(x * 12.9898 + y * 78.233) * 43758.5453) % 1;
                                ctx.fillStyle = Qt.rgba(blend(base.r, n), blend(base.g, n), blend(base.b, n),
                                                        amount * 0.25);
                                ctx.fillRect(x, y, 2, 2);
                            }
                    }
                }
                Rectangle {
                    x: 22
                    y: 5
                    width: 4
                    height: 10
                    radius: 2
                    color: Appearance.colors.colPrimary
                }
            }
            MouseArea {
                id: knobMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function updateValue(mouse) {
                    let angle = (Math.atan2(mouse.y - 40, mouse.x - 40) * 180 / Math.PI + 450) % 360;
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
