import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import M3Shapes
import qs.Common
import qs.Widgets.common

FocusScope {
    id: root

    property var context: null
    readonly property var passwordShapeQueue: {
        const shapes = [MaterialShape.Slanted, MaterialShape.Arch, MaterialShape.Fan, MaterialShape.Arrow, MaterialShape.SemiCircle, MaterialShape.Triangle, MaterialShape.Diamond, MaterialShape.ClamShell, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Sunny, MaterialShape.VerySunny, MaterialShape.Cookie4Sided, MaterialShape.Ghostish, MaterialShape.SoftBurst];
        for (let i = shapes.length - 1; i > 0; --i) {
            const j = Math.floor(Math.random() * (i + 1));
            const shape = shapes[i];
            shapes[i] = shapes[j];
            shapes[j] = shape;
        }
        return shapes;
    }
    readonly property bool hasText: input.text.length > 0
    readonly property bool busy: context && context.unlockInProgress
    readonly property bool enterEnabled: hasText && !busy
    readonly property bool enterHovered: frameMouse.containsMouse && frameMouse.mouseX >= enterButton.x
    readonly property bool enterPressed: frameMouse.pressed && frameMouse.mouseX >= enterButton.x

    signal requestUnlock()

    Layout.fillWidth: true
    Layout.preferredHeight: Metrics.lockAuthHeight
    Component.onCompleted: input.forceActiveFocus()
    onActiveFocusChanged: {
        if (activeFocus)
            input.forceActiveFocus();

    }

    Rectangle {
        id: inputFrame

        anchors.fill: parent
        color: Appearance.colors.colLayer2
        radius: height / 2
        clip: true

        RippleEffect {
            id: rippleEffect

            anchors.fill: parent
            color: Appearance.colors.colOnSurface
            effectOpacity: Appearance.interaction.rippleOpacity
            shapeRadius: inputFrame.radius
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingXS
            spacing: Metrics.spacingL

            Item {
                Layout.preferredWidth: Metrics.controlHeightXL
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
                        font.family: Fonts.materialSymbolsRounded
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
                    onCursorVisibleChanged: {
                        if (cursorVisible)
                            cursorVisible = false;

                    }
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
                        while (dotsModel.count < text.length)dotsModel.append({
                        })
                        while (dotsModel.count > text.length)dotsModel.remove(dotsModel.count - 1)
                    }

                    Connections {
                        function onCurrentTextChanged() {
                            if (root.context && input.text !== root.context.currentText)
                                input.text = root.context.currentText;

                        }

                        target: root.context
                        ignoreUnknownSignals: true
                    }

                }

                Text {
                    id: placeholder

                    property bool animateOnNextShow: true

                    anchors.centerIn: parent
                    text: root.busy ? qsTr("正在加载…") : qsTr("输入密码")
                    color: root.busy ? Appearance.colors.colSecondary : Appearance.colors.colOutline
                    font.family: Fonts.numeric
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

                ListView {
                    id: dotsList

                    readonly property real fullWidth: {
                        if (count === 0)
                            return 0;

                        let width = (count - 1) * spacing + dotSize;
                        for (let i = 0; i < count; ++i) {
                            const item = itemAtIndex(i);
                            width += (item ? item.nonAnimatedWidthScale : 1) * dotSize;
                        }
                        return width;
                    }
                    property int dotSize: 17

                    function bindImplicitWidth() {
                        implicitWidthBehavior.enabled = false;
                        implicitWidth = Qt.binding(() => {
                            return fullWidth;
                        });
                        implicitWidthBehavior.enabled = true;
                    }

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: implicitWidth > parent.width ? -(implicitWidth - parent.width) / 2 : 0
                    implicitWidth: fullWidth
                    implicitHeight: dotSize
                    orientation: ListView.Horizontal
                    spacing: Metrics.spacingS
                    interactive: false
                    model: dotsModel

                    Behavior on implicitWidth {
                        id: implicitWidthBehavior

                        NumberAnimation {
                            duration: Appearance.animation.standard.duration
                            easing.type: Appearance.animation.standard.type
                            easing.bezierCurve: Appearance.animation.standard.bezierCurve
                        }

                    }

                    delegate: Item {
                        id: character

                        required property int index
                        property real nonAnimatedWidthScale: 1

                        implicitWidth: dotsList.dotSize
                        width: implicitWidth
                        height: dotsList.dotSize
                        ListView.onRemove: {
                            appearAnimation.stop();
                            removeAnimation.start();
                        }

                        MaterialShape {
                            id: characterShape

                            anchors.centerIn: parent
                            implicitSize: dotsList.dotSize * 1.5
                            shape: root.passwordShapeQueue[character.index % root.passwordShapeQueue.length] ?? MaterialShape.Circle
                            color: Appearance.colors.colOnSurface
                            animationDuration: Appearance.animation.expressiveFastSpatial.duration

                            SequentialAnimation {
                                id: appearAnimation

                                running: true

                                ParallelAnimation {
                                    NumberAnimation {
                                        target: characterShape
                                        property: "opacity"
                                        from: 0
                                        to: 1
                                        duration: Appearance.animation.expressiveEffects.duration
                                        easing.type: Appearance.animation.expressiveEffects.type
                                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                    }

                                    NumberAnimation {
                                        target: characterShape
                                        property: "scale"
                                        from: 0
                                        to: 1
                                        duration: Appearance.animation.expressiveFastSpatial.duration
                                        easing.type: Appearance.animation.expressiveFastSpatial.type
                                        easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                                    }

                                    NumberAnimation {
                                        target: character
                                        property: "implicitWidth"
                                        from: dotsList.dotSize
                                        to: dotsList.dotSize * 1.3
                                        duration: Appearance.animation.expressiveDefaultSpatial.duration
                                        easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                        easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                                    }

                                    PropertyAction {
                                        target: character
                                        property: "nonAnimatedWidthScale"
                                        value: 1.5
                                    }

                                }

                                PauseAnimation {
                                    duration: Appearance.animation.expressiveEffects.duration * 0.9
                                }

                                PropertyAction {
                                    target: characterShape
                                    property: "shape"
                                    value: MaterialShape.Circle
                                }

                                ParallelAnimation {
                                    NumberAnimation {
                                        target: characterShape
                                        property: "scale"
                                        to: 2 / 3
                                        duration: Appearance.animation.expressiveFastSpatial.duration
                                        easing.type: Appearance.animation.expressiveFastSpatial.type
                                        easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                                    }

                                    NumberAnimation {
                                        target: character
                                        property: "implicitWidth"
                                        to: dotsList.dotSize
                                        duration: Appearance.animation.expressiveDefaultSpatial.duration
                                        easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                        easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                                    }

                                    PropertyAction {
                                        target: character
                                        property: "nonAnimatedWidthScale"
                                        value: 1
                                    }

                                }

                            }

                            SequentialAnimation {
                                id: removeAnimation

                                PropertyAction {
                                    target: character
                                    property: "ListView.delayRemove"
                                    value: true
                                }

                                ParallelAnimation {
                                    NumberAnimation {
                                        target: characterShape
                                        property: "opacity"
                                        to: 0
                                        duration: Appearance.animation.expressiveEffects.duration
                                        easing.type: Appearance.animation.expressiveEffects.type
                                        easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                                    }

                                    NumberAnimation {
                                        target: characterShape
                                        property: "scale"
                                        to: 0.5
                                        duration: Appearance.animation.expressiveFastSpatial.duration
                                        easing.type: Appearance.animation.expressiveFastSpatial.type
                                        easing.bezierCurve: Appearance.animation.expressiveFastSpatial.bezierCurve
                                    }

                                }

                                PropertyAction {
                                    target: character
                                    property: "ListView.delayRemove"
                                    value: false
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.expressiveSlowEffects.duration
                                    easing.type: Appearance.animation.expressiveSlowEffects.type
                                    easing.bezierCurve: Appearance.animation.expressiveSlowEffects.bezierCurve
                                }

                            }

                        }

                    }

                }

            }

            Rectangle {
                id: enterButton

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth + (root.enterPressed ? Metrics.lockOuterPadding * 2 : root.hasText ? Metrics.lockOuterPadding : 0)
                implicitWidth: enterIcon.implicitWidth + Metrics.lockOuterPadding * 2
                implicitHeight: enterIcon.implicitHeight + Metrics.spacingM * 2
                radius: root.hasText || root.enterPressed ? Metrics.cornerL : Math.min(implicitWidth, implicitHeight) / 2
                color: root.hasText ? Appearance.colors.colPrimary : Appearance.colors.colLayer3

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
                    font.family: Fonts.materialSymbolsRounded
                    font.pixelSize: 24
                    font.weight: 500
                }

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

            }

        }

        MouseArea {
            id: frameMouse

            anchors.fill: parent
            z: 10
            hoverEnabled: true
            cursorShape: root.enterEnabled && mouseX >= enterButton.x ? Qt.PointingHandCursor : Qt.IBeamCursor
            onPressed: (mouse) => {
                rippleEffect.startAt(mouse.x, mouse.y);
                input.forceActiveFocus();
            }
            onClicked: (mouse) => {
                input.forceActiveFocus();
                if (root.enterEnabled && mouse.x >= enterButton.x)
                    root.requestUnlock();

            }
        }

    }

}
