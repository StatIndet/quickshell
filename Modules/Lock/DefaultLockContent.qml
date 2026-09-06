import QtQuick
import QtQuick.Controls
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
    readonly property real uiScale: Math.min(1, Math.max(0.45, (width - 48) / 880), Math.max(0.45, height
                                                                                             / 800))
    readonly property real contentWidth: 880 * uiScale
    readonly property real avatarSize: 240 * uiScale
    readonly property real columnGap: 40 * uiScale
    readonly property real fieldHeight: 64 * uiScale
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

    Row {
        id: authRow
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24 * root.uiScale + root.authOffset
        width: root.contentWidth
        height: root.avatarSize
        spacing: root.columnGap
        opacity: root.authOpacity

        Rectangle {
            width: root.avatarSize
            height: width
            radius: width / 2
            color: Appearance.colors.colSecondaryContainer
            anchors.verticalCenter: parent.verticalCenter

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
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.avatarSize - parent.spacing
            spacing: 24 * root.uiScale

            Text {
                width: parent.width
                height: 88 * root.uiScale
                verticalAlignment: Text.AlignVCenter
                text: SystemIdentityService.accountName
                color: "white"
                font.family: Fonts.ui
                font.pixelSize: 64 * root.uiScale
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                id: field
                width: Math.min(parent.width, 400 * root.uiScale)
                height: root.fieldHeight
                radius: height / 2
                color: Appearance.colors.colSurfaceContainerHigh
                border.width: root.context.showFailure ? 2 : 0
                border.color: Appearance.colors.colError

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 24 * root.uiScale
                    anchors.rightMargin: root.fieldHeight
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
                        dotsView.positionViewAtEnd();
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
                    anchors.left: parent.left
                    anchors.leftMargin: 24 * root.uiScale
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
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
                    anchors.left: parent.left
                    anchors.right: submit.left
                    anchors.margins: 24 * root.uiScale
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28 * root.uiScale
                    orientation: ListView.Horizontal
                    interactive: false
                    clip: true
                    spacing: 10 * root.uiScale
                    model: dots
                    onCountChanged: Qt.callLater(positionViewAtEnd)

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

                Button {
                    id: submit
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.uiScale
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48 * root.uiScale
                    height: width
                    focusPolicy: Qt.NoFocus
                    enabled: !root.busy && input.text.length > 0
                    Accessible.name: qsTr("解锁")
                    onClicked: root.context.tryUnlock()
                    background: Rectangle {
                        radius: width / 2
                        color: Appearance.colors.colPrimary
                        opacity: submit.down ? 0.7 : 1
                    }
                    contentItem: Text {
                        text: root.busy ? "" : "arrow_forward"
                        font.family: Fonts.materialSymbolsRounded
                        font.pixelSize: 26 * root.uiScale
                        color: Appearance.colors.colOnPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    InlineBusyIndicator {
                        anchors.centerIn: parent
                        busy: root.busy
                        spinnerColor: Appearance.colors.colOnPrimary
                    }
                    StyledToolTip {
                        text: qsTr("解锁")
                        extraVisibleCondition: root.authenticating && submit.hovered
                    }
                }
            }
        }

        // Status belongs below the aligned avatar/form block, outside Row layout.
    }

    Text {
        anchors.top: authRow.bottom
        anchors.topMargin: 16 * root.uiScale
        x: authRow.x + root.avatarSize + root.columnGap
        width: root.contentWidth - root.avatarSize - root.columnGap
        opacity: root.authOpacity
        text: root.context.showFailure ? qsTr("密码错误，请重试") : (KeyboardLockState.capsLock ? qsTr("大写锁定已开启") :
                                                                                          "")
        color: root.context.showFailure ? Appearance.colors.colError : "white"
        font.family: Fonts.ui
        font.pixelSize: 20 * root.uiScale
        wrapMode: Text.WordWrap
    }

    Connections {
        target: root.context
        function onCurrentTextChanged() {
            if (input.text !== root.context.currentText)
                input.text = root.context.currentText;
        }
        function onUnlockFailed() {
            root.forceAuthFocus();
        }
    }
}
