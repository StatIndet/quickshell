import QtQuick
import QtQuick.Effects
import Clavis.Keyboard
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    required property var context
    property date now: new Date()
    readonly property bool authenticating: context.authRevealed
    readonly property bool busy: context.unlockInProgress
    readonly property real uiScale: Math.min(1, (width - 48) / 360, height / 720)
    readonly property real contentWidth: 360 * uiScale
    readonly property real avatarSize: 240 * uiScale
    readonly property real fieldHeight: 64 * uiScale
    property real clockScale: authenticating ? 1.08 : 1
    property real authScale: authenticating ? 1 : 0.94

    Behavior on clockScale {
        NumberAnimation {
            duration: 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
        }
    }
    Behavior on authScale {
        NumberAnimation {
            duration: 460
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
        }
    }
    property real clockOpacity: authenticating ? 0 : 1
    property real clockOffset: authenticating ? -80 * uiScale : 0
    property real authOpacity: authenticating ? 1 : 0
    property real authOffset: authenticating ? 0 : 56 * uiScale

    function forceAuthFocus() {
        input.forceActiveFocus();
    }

    // Independent effects and spatial curves keep the incoming form legible
    // while the clock clears it. Reversing midway continues from current values.
    Behavior on clockOpacity {
        NumberAnimation {
            duration: 240
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
        }
    }
    Behavior on clockOffset {
        NumberAnimation {
            duration: 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
        }
    }
    Behavior on authOpacity {
        NumberAnimation {
            duration: 360
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
        }
    }
    Behavior on authOffset {
        NumberAnimation {
            duration: 460
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.context.authRevealed = true;
            root.forceAuthFocus();
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24 * root.uiScale + root.clockOffset
        width: parent.width - 48
        spacing: 12
        opacity: root.clockOpacity
        scale: root.clockScale

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            Text {
                text: (UiPreferences.useTwelveHourClock ? String((root.now.getHours() + 11) % 12 + 1) : String(
                                                              root.now.getHours()).padStart(2, "0")) + ":"
                      + Qt.formatTime(root.now, "mm")
                color: "white"
                font.family: Fonts.numeric
                font.pixelSize: Math.min(root.width * 0.19, root.height * 0.24, 240)
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.18
                visible: UiPreferences.useTwelveHourClock
                text: root.now.getHours() < 12 ? "AM" : "PM"
                color: "white"
                font.family: Fonts.numeric
                font.pixelSize: Math.min(root.width * 0.045, 48)
                font.weight: Font.Medium
            }
        }

        Text {
            width: parent.width
            text: Qt.formatDate(root.now, "yyyy MMMM d, dddd")
            color: "white"
            font.family: Fonts.ui
            font.pixelSize: Math.min(26, root.width * 0.035)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    Column {
        id: authRow
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24 * root.uiScale + root.authOffset
        width: root.contentWidth
        spacing: 24 * root.uiScale
        opacity: root.authOpacity
        scale: root.authScale

        Rectangle {
            width: root.avatarSize
            height: width
            radius: width / 2
            color: Appearance.colors.colSecondaryContainer
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: SystemIdentityService.accountName.slice(0, 1).toUpperCase()
                font.family: Fonts.ui
                font.pixelSize: parent.width * 0.4
                color: Appearance.colors.colOnSecondaryContainer
            }

            Image {
                anchors.fill: parent
                source: AvatarService.avatarUrl
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: avatarMask
                }
            }

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                layer.enabled: true
                visible: false
            }
        }

        Column {
            width: parent.width
            spacing: 18 * root.uiScale

            Text {
                width: parent.width
                height: 52 * root.uiScale
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: SystemIdentityService.accountName
                color: "white"
                font.family: Fonts.ui
                font.pixelSize: 40 * root.uiScale
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 280 * root.uiScale
                height: root.fieldHeight
                radius: height / 2
                color: Appearance.colors.colSurfaceContainerHigh
                border.width: 2 * root.uiScale
                border.color: Appearance.colors.colOutline

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 24 * root.uiScale
                    anchors.rightMargin: 24 * root.uiScale
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    echoMode: TextInput.NoEcho
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    readOnly: root.busy
                    focus: true
                    activeFocusOnPress: true
                    cursorVisible: false
                    maximumLength: 4096
                    Accessible.name: qsTr("密码")
                    Accessible.description: root.context.showFailure ? qsTr("密码错误") : ""
                    onCursorVisibleChanged: {
                        if (cursorVisible)
                            cursorVisible = false;
                    }
                    onTextChanged: {
                        if (root.context.currentText !== text)
                            root.context.currentText = text;
                        if (text.length > 0) {
                            root.context.authRevealed = true;
                            root.context.showFailure = false;
                        }
                        while (dots.count < text.length)
                            dots.append({});
                        while (dots.count > text.length)
                            dots.remove(dots.count - 1);
                    }
                    onAccepted: {
                        root.context.authRevealed = true;
                        root.context.tryUnlock();
                    }
                    Keys.onEscapePressed: {
                        if (!root.busy) {
                            text = "";
                            root.context.showFailure = false;
                            root.context.authRevealed = false;
                        }
                    }
                    Component.onCompleted: text = root.context.currentText
                }

                Text {
                    anchors.centerIn: parent
                    visible: input.text.length === 0 && !root.busy
                    text: qsTr("密码")
                    font.family: Fonts.ui
                    font.pixelSize: 20 * root.uiScale
                    color: Appearance.colors.colOnSurfaceVariant
                }

                ListModel {
                    id: dots
                }

                ListView {
                    id: dotsView
                    readonly property real naturalWidth: count > 0 ? count * (26 * root.uiScale) - spacing + 8
                                                                     * root.uiScale : 0
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48 * root.uiScale, naturalWidth)
                    leftMargin: 4 * root.uiScale
                    rightMargin: 4 * root.uiScale
                    height: 28 * root.uiScale
                    orientation: ListView.Horizontal
                    interactive: false
                    clip: true
                    spacing: 10 * root.uiScale
                    model: dots
                    onCountChanged: Qt.callLater(positionViewAtEnd)
                    onWidthChanged: positionViewAtEnd()
                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                        }
                    }

                    delegate: Item {
                        id: dot
                        width: 16 * root.uiScale
                        height: 28 * root.uiScale
                        ListView.onRemove: {
                            ListView.delayRemove = true;
                            appear.stop();
                            disappear.start();
                        }
                        Rectangle {
                            id: circle
                            anchors.centerIn: parent
                            width: 16 * root.uiScale
                            height: width
                            radius: width / 2
                            color: Appearance.colors.colOnSurface
                            SequentialAnimation {
                                id: appear
                                running: true
                                NumberAnimation {
                                    target: circle
                                    properties: "scale,opacity"
                                    from: 0
                                    to: 1.3
                                    duration: 180
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                                }
                                NumberAnimation {
                                    target: circle
                                    property: "scale"
                                    to: 1
                                    duration: 240
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                                }
                            }
                            NumberAnimation {
                                id: disappear
                                target: circle
                                properties: "scale,opacity"
                                to: 0
                                duration: 160
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.3, 0, 1, 1, 1, 1]
                                onFinished: dot.ListView.delayRemove = false
                            }
                        }
                    }
                }

                Rectangle {
                    id: errorBorder
                    anchors.fill: parent
                    radius: field.radius
                    color: "transparent"
                    border.width: 3 * root.uiScale
                    border.color: Appearance.colors.colError
                    opacity: 0

                    SequentialAnimation {
                        id: failureFlash
                        loops: 2
                        NumberAnimation {
                            target: errorBorder
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 120
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                        }
                        PauseAnimation {
                            duration: 80
                        }
                        NumberAnimation {
                            target: errorBorder
                            property: "opacity"
                            to: 0
                            duration: 180
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.3, 0, 1, 1, 1, 1]
                        }
                        PauseAnimation {
                            duration: 80
                        }
                    }
                }

                InlineBusyIndicator {
                    anchors.centerIn: parent
                    busy: root.busy && input.text.length === 0
                }
            }
        }
    }

    InlineBusyIndicator {
        anchors.top: authRow.bottom
        anchors.topMargin: 12 * root.uiScale
        anchors.horizontalCenter: parent.horizontalCenter
        busy: root.busy && input.text.length > 0
        opacity: root.authOpacity
    }

    Text {
        anchors.top: authRow.bottom
        anchors.topMargin: 40 * root.uiScale
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.contentWidth
        opacity: root.authOpacity
        text: KeyboardLockState.capsLock ? qsTr("大写锁定已开启") : ""
        horizontalAlignment: Text.AlignHCenter
        color: "white"
        font.family: Fonts.ui
        font.pixelSize: 18 * root.uiScale
        wrapMode: Text.WordWrap
    }

    Connections {
        target: root.context
        function onCurrentTextChanged() {
            if (input.text !== root.context.currentText)
                input.text = root.context.currentText;
        }
        function onUnlockFailed() {
            failureFlash.restart();
            root.forceAuthFocus();
        }
    }
}
