import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Common
import qs.Widgets.common

FocusScope {
    id: root

    property var context: null
    readonly property bool hasText: input.text.length > 0
    readonly property bool busy: context && context.unlockInProgress
    readonly property bool enterEnabled: hasText && !busy
    readonly property bool enterHovered: frameMouse.containsMouse && frameMouse.mouseX >= enterButton.x
    readonly property bool enterPressed: frameMouse.pressed && frameMouse.mouseX >= enterButton.x

    signal requestUnlock()

    Layout.fillWidth: true
    Layout.preferredHeight: Sizes.lockAuthHeight

    Component.onCompleted: input.forceActiveFocus()
    onActiveFocusChanged: if (activeFocus) input.forceActiveFocus()

    Rectangle {
        id: inputFrame

        anchors.fill: parent
        color: Appearance.colors.colLayer2
        radius: height / 2
        clip: true

        Shape {
            id: rippleLayer

            property real pressX: width / 2
            property real pressY: height / 2
            property real circleRadius: 0
            readonly property real cornerRadius: inputFrame.radius
            readonly property real endRadius: {
                const d1 = distSq(0, 0);
                const d2 = distSq(width, 0);
                const d3 = distSq(0, height);
                const d4 = distSq(width, height);
                return Math.sqrt(Math.max(d1, d2, d3, d4));
            }

            function distSq(x, y) {
                return Math.pow(pressX - x, 2) + Math.pow(pressY - y, 2);
            }

            function start(x, y) {
                pressX = x;
                pressY = y;
                circleRadius = 0;
                opacity = 0.14;
                rippleAnim.restart();
            }

            anchors.fill: parent
            opacity: 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: rippleLayer.pressX
                    centerY: rippleLayer.pressY
                    centerRadius: rippleLayer.circleRadius
                    focalX: centerX
                    focalY: centerY

                    GradientStop {
                        position: 0
                        color: Appearance.colors.colOnSurface
                    }
                    GradientStop {
                        position: 0.99
                        color: Appearance.colors.colOnSurface
                    }
                    GradientStop {
                        position: 1
                        color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0)
                    }
                }

                startX: rippleLayer.cornerRadius
                startY: 0

                PathLine {
                    x: rippleLayer.width - rippleLayer.cornerRadius
                    y: 0
                }
                PathArc {
                    x: rippleLayer.width
                    y: rippleLayer.cornerRadius
                    radiusX: rippleLayer.cornerRadius
                    radiusY: rippleLayer.cornerRadius
                }
                PathLine {
                    x: rippleLayer.width
                    y: rippleLayer.height - rippleLayer.cornerRadius
                }
                PathArc {
                    x: rippleLayer.width - rippleLayer.cornerRadius
                    y: rippleLayer.height
                    radiusX: rippleLayer.cornerRadius
                    radiusY: rippleLayer.cornerRadius
                }
                PathLine {
                    x: rippleLayer.cornerRadius
                    y: rippleLayer.height
                }
                PathArc {
                    x: 0
                    y: rippleLayer.height - rippleLayer.cornerRadius
                    radiusX: rippleLayer.cornerRadius
                    radiusY: rippleLayer.cornerRadius
                }
                PathLine {
                    x: 0
                    y: rippleLayer.cornerRadius
                }
                PathArc {
                    x: rippleLayer.cornerRadius
                    y: 0
                    radiusX: rippleLayer.cornerRadius
                    radiusY: rippleLayer.cornerRadius
                }
            }

            ParallelAnimation {
                id: rippleAnim

                NumberAnimation {
                    target: rippleLayer
                    property: "circleRadius"
                    to: rippleLayer.endRadius
                    duration: Appearance.animation.expressiveSlowEffects.duration * 2
                    easing.type: Appearance.animation.expressiveSlowEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                }

                NumberAnimation {
                    target: rippleLayer
                    property: "opacity"
                    to: 0
                    duration: Appearance.animation.expressiveSlowEffects.duration * 2
                    easing.type: Appearance.animation.expressiveSlowEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Math.round(5 * 4 / 3)
            spacing: Math.round(12 * 4 / 3)

            Item {
                Layout.preferredWidth: Math.round(38 * 4 / 3)
                Layout.fillHeight: true

                Item {
                    id: progressHost

                    anchors.centerIn: parent
                    width: 32
                    height: 32

                    BusyIndicator {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        padding: 0
                        running: root.busy
                        opacity: root.busy ? 1 : 0
                        Material.theme: Appearance.m3colors.darkmode ? Material.Dark : Material.Light
                        Material.accent: Appearance.colors.colSecondary

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }

                    Text {
                        id: lockIcon

                        anchors.centerIn: parent
                        text: "lock"
                        color: Appearance.colors.colOnSurface
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24
                        opacity: root.busy ? 0 : 1
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                TextInput {
                    id: input

                    anchors.fill: parent
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    focus: true
                    cursorVisible: false
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    onActiveFocusChanged: cursorVisible = false
                    onCursorVisibleChanged: if (cursorVisible) cursorVisible = false

                    onAccepted: {
                        placeholder.animateOnNextShow = false;
                        if (!root.busy)
                            root.requestUnlock();
                    }

                    onTextChanged: {
                        if (root.context)
                            root.context.currentText = text;

                        if (text.length > dotsModel.count)
                            dotsList.bindImplicitWidth();
                        else if (text.length === 0)
                            placeholder.animateOnNextShow = true;

                        while (dotsModel.count < text.length)
                            dotsModel.append({});

                        while (dotsModel.count > text.length)
                            dotsModel.remove(dotsModel.count - 1);
                    }

                    Connections {
                        target: root.context
                        ignoreUnknownSignals: true

                        function onCurrentTextChanged() {
                            if (root.context && input.text !== root.context.currentText)
                                input.text = root.context.currentText;
                        }
                    }
                }

                Text {
                    id: placeholder

                    property bool animateOnNextShow: true

                    anchors.centerIn: parent
                    text: root.busy ? "Loading..." : "Enter your password"
                    color: root.busy ? Appearance.colors.colSecondary : Appearance.colors.colOutline
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 17
                    opacity: root.hasText ? 0 : 1
                    scale: root.hasText ? 0.96 : 1

                    Behavior on opacity {
                        enabled: placeholder.animateOnNextShow
                        NumberAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveFastSpatial.duration
                            easing.type: Appearance.animation.expressiveFastSpatial.type
                            easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                        }
                    }
                }

                ListModel {
                    id: dotsModel
                }

                StyledListView {
                    id: dotsList

                    readonly property int fullWidth: count === 0 ? 0 : count * (dotSize + spacing) - spacing
                    property int dotSize: 17

                    function bindImplicitWidth() {
                        implicitWidthBehavior.enabled = false;
                        implicitWidth = Qt.binding(() => fullWidth);
                        implicitWidthBehavior.enabled = true;
                    }

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: implicitWidth > parent.width ? -(implicitWidth - parent.width) / 2 : 0
                    implicitWidth: fullWidth
                    implicitHeight: dotSize
                    orientation: ListView.Horizontal
                    spacing: Math.round(Sizes.lockCardGap / 2)
                    interactive: false
                    animateAppearance: false
                    animateMovement: false
                    showVerticalScrollBar: false
                    smoothWheelEnabled: false
                    model: dotsModel

                    Behavior on implicitWidth {
                        id: implicitWidthBehavior

                        NumberAnimation {
                            duration: Appearance.animation.standard.duration
                            easing.type: Appearance.animation.standard.type
                            easing.bezierCurve: Appearance.animation.standard.bezierCurve
                        }
                    }

                    delegate: Rectangle {
                        id: dot

                        width: dotsList.dotSize
                        height: dotsList.dotSize
                        radius: Sizes.lockCardRadiusSmall / 2
                        color: Appearance.colors.colOnSurface
                        opacity: 0
                        scale: 0

                        Component.onCompleted: {
                            opacity = 1;
                            scale = 1;
                        }

                        ListView.onRemove: removeAnim.start()

                        SequentialAnimation {
                            id: removeAnim

                            PropertyAction {
                                target: dot
                                property: "ListView.delayRemove"
                                value: true
                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: dot
                                    property: "opacity"
                                    to: 0
                                    duration: Appearance.animation.expressiveEffects.duration
                                    easing.type: Appearance.animation.expressiveEffects.type
                                    easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                }
                                NumberAnimation {
                                    target: dot
                                    property: "scale"
                                    to: 0.5
                                    duration: Appearance.animation.expressiveFastSpatial.duration
                                    easing.type: Appearance.animation.expressiveFastSpatial.type
                                    easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                                }
                            }

                            PropertyAction {
                                target: dot
                                property: "ListView.delayRemove"
                                value: false
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.animation.expressiveFastSpatial.duration
                                easing.type: Appearance.animation.expressiveFastSpatial.type
                                easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: enterButton

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth + (root.enterPressed ? Sizes.lockOuterPadding * 2 : root.hasText ? Sizes.lockOuterPadding : 0)
                implicitWidth: enterIcon.implicitWidth + Sizes.lockOuterPadding * 2
                implicitHeight: enterIcon.implicitHeight + Math.round(10 * 4 / 3) * 2
                radius: root.hasText || root.enterPressed ? Math.round(17 * 4 / 3) : Math.min(implicitWidth, implicitHeight) / 2
                color: root.hasText ? Appearance.colors.colPrimary : Appearance.colors.colLayer3

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveFastSpatial.duration
                        easing.type: Appearance.animation.expressiveFastSpatial.type
                        easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                    }
                }

                Behavior on radius {
                    NumberAnimation {
                        duration: Appearance.animation.expressiveFastSpatial.duration
                        easing.type: Appearance.animation.expressiveFastSpatial.type
                        easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.standard.duration
                        easing.type: Appearance.animation.standard.type
                        easing.bezierCurve: Appearance.animation.standard.bezierCurve
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.hasText ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                    opacity: root.enterPressed ? 0.2 : root.enterHovered ? 0.12 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }
                    }
                }

                Text {
                    id: enterIcon

                    anchors.centerIn: parent
                    text: "arrow_forward"
                    color: root.hasText ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 24
                    font.weight: 500
                }
            }
        }

        MouseArea {
            id: frameMouse

            anchors.fill: parent
            z: 10
            hoverEnabled: true
            cursorShape: root.enterEnabled && mouseX >= enterButton.x ? Qt.PointingHandCursor : Qt.IBeamCursor
            onPressed: mouse => {
                rippleLayer.start(mouse.x, mouse.y);
                input.forceActiveFocus();
            }
            onClicked: mouse => {
                input.forceActiveFocus();
                if (root.enterEnabled && mouse.x >= enterButton.x)
                    root.requestUnlock();
            }
        }
    }
}
