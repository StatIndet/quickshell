import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Clavis.Keyboard
import qs.Common
import qs.Services
import "Cards"

Item {
    id: root

    property var context: null
    property real screenHeight: height
    readonly property real availableWidth: width
    readonly property real availableHeight: height
    readonly property bool veryCompact: availableHeight < Metrics.lockVeryCompactBreakpoint
    readonly property bool compact: availableHeight < Metrics.lockCompactBreakpoint
    readonly property bool spacious: availableHeight >= Metrics.lockFetchExpandedBreakpoint
    readonly property real centerScale: Math.min(1, root.screenHeight / 1440)
    readonly property real centerWidth: Metrics.lockCenterWidth * centerScale
    readonly property int clockHour24: clockTimer.now.getHours()
    readonly property int clockHour: UiPreferences.useTwelveHourClock ? ((clockHour24 + 11) % 12) + 1 : clockHour24

    function forceAuthFocus() {
        authCard.forceActiveFocus();
    }

    RowLayout {
        anchors.fill: parent
        spacing: Metrics.lockColumnGap

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Metrics.lockCardGap

            WeatherCard {
                Layout.fillWidth: true
                radius: Metrics.lockCardRadiusSmall
                topLeftRadius: Metrics.lockCardRadius
                availableHeight: root.availableHeight
            }

            LockFetchCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                detailLevel: root.spacious ? 3 : root.compact ? (root.veryCompact ? 0 : 1) : 2
                radius: Metrics.lockCardRadiusSmall
            }

            MediaCard {
                Layout.fillWidth: true
                compact: root.compact
                radius: Metrics.lockCardRadiusSmall
                bottomLeftRadius: Metrics.lockCardRadius
            }

        }

        ColumnLayout {
            Layout.preferredWidth: root.centerWidth
            Layout.fillHeight: true
            Layout.fillWidth: false
            spacing: Metrics.lockColumnGap

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Metrics.spacingS

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: String(root.clockHour).padStart(2, "0")
                    color: Appearance.colors.colSecondary
                    font.family: Fonts.numeric
                    font.pixelSize: Math.floor(Metrics.lockTimeFontSize * root.centerScale)
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: ":"
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.numeric
                    font.pixelSize: Math.floor(Metrics.lockTimeFontSize * root.centerScale)
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Qt.formatTime(clockTimer.now, "mm")
                    color: Appearance.colors.colSecondary
                    font.family: Fonts.numeric
                    font.pixelSize: Math.floor(Metrics.lockTimeFontSize * root.centerScale)
                    font.bold: true
                }

                Text {
                    Layout.leftMargin: Metrics.spacingS
                    Layout.alignment: Qt.AlignVCenter
                    visible: UiPreferences.useTwelveHourClock
                    text: Qt.formatTime(clockTimer.now, "AP")
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.numeric
                    font.pixelSize: Math.floor(Metrics.lockTimeSuffixFontSize * root.centerScale)
                    font.bold: true
                }

            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -Metrics.lockOuterPadding * 2
                text: Qt.formatDate(clockTimer.now, "dddd, d MMMM yyyy")
                color: Appearance.colors.colTertiary
                font.family: Fonts.numeric
                font.pixelSize: Math.floor(Metrics.lockDateFontSize * root.centerScale)
                font.bold: true
            }

            Item {
                Layout.preferredWidth: root.centerWidth / 2
                Layout.preferredHeight: root.centerWidth / 2
                Layout.topMargin: Metrics.lockColumnGap
                Layout.alignment: Qt.AlignHCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Appearance.colors.colLayer2
                }

                Rectangle {
                    id: avatarMask

                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    color: "black"
                }

                Image {
                    id: fallbackAvatarImg

                    anchors.fill: parent
                    source: Paths.fileUrl(Paths.defaultAvatar)
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    cache: true
                }

                Image {
                    id: avatarImg

                    anchors.fill: parent
                    source: AvatarService.avatarUrl
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    cache: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: avatarImg.status === Image.Ready ? avatarImg : fallbackAvatarImg
                    maskSource: avatarMask
                }

                Text {
                    anchors.centerIn: parent
                    text: "person"
                    visible: avatarImg.status !== Image.Ready && fallbackAvatarImg.status !== Image.Ready
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.materialSymbolsRounded
                    font.pixelSize: parent.width * 0.45
                }

            }

            AuthCard {
                id: authCard

                Layout.preferredWidth: root.centerWidth * 0.8
                Layout.preferredHeight: Metrics.lockAuthHeight
                Layout.alignment: Qt.AlignHCenter
                context: root.context
                onRequestUnlock: {
                    if (root.context)
                        root.context.tryUnlock();

                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: -Metrics.spacingXL
                implicitHeight: Math.max(errorMessage.implicitHeight, stateMessage.implicitHeight, 18)

                Text {
                    id: errorMessage

                    property string msg: root.context && root.context.showFailure ? qsTr("密码错误，请重试。") : ""
                    property string pendingText: ""

                    function showText(newText) {
                        if (newText === text && opacity > 0) {
                            errorExitAnim.stop();
                            if (scale < 1)
                                errorAppearAnim.restart();
                            else
                                errorFlashAnim.restart();
                            return ;
                        }
                        errorExitAnim.stop();
                        errorFlashAnim.stop();
                        if (opacity > 0 && text.length > 0) {
                            pendingText = newText;
                            errorSwapAnim.restart();
                            return ;
                        }
                        text = newText;
                        errorAppearAnim.restart();
                    }

                    function hideText() {
                        pendingText = "";
                        errorAppearAnim.stop();
                        errorFlashAnim.stop();
                        errorSwapAnim.stop();
                        errorExitAnim.restart();
                    }

                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: ""
                    opacity: 0
                    scale: 0.7
                    color: Appearance.colors.colError
                    font.family: Fonts.numeric
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    lineHeight: 1.2
                    onMsgChanged: {
                        if (msg.length > 0)
                            showText(msg);
                        else
                            hideText();
                    }

                    ParallelAnimation {
                        id: errorAppearAnim

                        onFinished: errorFlashAnim.restart()

                        NumberAnimation {
                            target: errorMessage
                            property: "scale"
                            to: 1
                            duration: Appearance.animation.expressiveDefaultSpatial.duration
                            easing.type: Appearance.animation.expressiveDefaultSpatial.type
                            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                        }

                        NumberAnimation {
                            target: errorMessage
                            property: "opacity"
                            to: 1
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }

                    }

                    SequentialAnimation {
                        id: errorSwapAnim

                        onFinished: errorFlashAnim.restart()

                        ParallelAnimation {
                            NumberAnimation {
                                target: errorMessage
                                property: "scale"
                                to: 0.7
                                duration: Appearance.animation.standard.duration
                                easing.type: Appearance.animation.standard.type
                                easing.bezierCurve: Appearance.animation.standard.bezierCurve
                            }

                            NumberAnimation {
                                target: errorMessage
                                property: "opacity"
                                to: 0
                                duration: Appearance.animation.standard.duration
                                easing.type: Appearance.animation.standard.type
                                easing.bezierCurve: Appearance.animation.standard.bezierCurve
                            }

                        }

                        ScriptAction {
                            script: {
                                errorMessage.text = errorMessage.pendingText;
                                errorMessage.pendingText = "";
                            }
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: errorMessage
                                property: "scale"
                                to: 1
                                duration: Appearance.animation.expressiveDefaultSpatial.duration
                                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                            }

                            NumberAnimation {
                                target: errorMessage
                                property: "opacity"
                                to: 1
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }

                        }

                    }

                    SequentialAnimation {
                        id: errorFlashAnim

                        loops: 2
                        onFinished: {
                            if (root.context && root.context.showFailure)
                                root.context.showFailure = false;

                        }

                        NumberAnimation {
                            target: errorMessage
                            property: "opacity"
                            to: 0.3
                            duration: Animations.durations.small
                            easing.type: Easing.Linear
                        }

                        NumberAnimation {
                            target: errorMessage
                            property: "opacity"
                            to: 1
                            duration: Animations.durations.small
                            easing.type: Easing.Linear
                        }

                    }

                    ParallelAnimation {
                        id: errorExitAnim

                        NumberAnimation {
                            target: errorMessage
                            property: "scale"
                            to: 0.7
                            duration: Appearance.animation.standardLarge.duration
                            easing.type: Appearance.animation.standardLarge.type
                            easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
                        }

                        NumberAnimation {
                            target: errorMessage
                            property: "opacity"
                            to: 0
                            duration: Appearance.animation.standardLarge.duration
                            easing.type: Appearance.animation.standardLarge.type
                            easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
                        }

                    }

                }

                Text {
                    id: stateMessage

                    property string msg: {
                        if (KeyboardLockState.capsLock && KeyboardLockState.numLock)
                            return qsTr("大写锁定和数字锁定已开启。");

                        if (KeyboardLockState.capsLock)
                            return qsTr("大写锁定已开启。");

                        if (KeyboardLockState.numLock)
                            return qsTr("数字锁定已开启。");

                        return "";
                    }
                    property bool blocked: errorMessage.msg.length > 0
                    property bool shouldBeVisible: false
                    property string pendingText: ""

                    function refresh() {
                        if (blocked || msg.length === 0) {
                            hideText();
                            return ;
                        }
                        showText(msg);
                    }

                    function showText(newText) {
                        shouldBeVisible = true;
                        stateExitAnim.stop();
                        if (newText === text && opacity > 0)
                            return ;

                        if (opacity > 0 && text.length > 0) {
                            pendingText = newText;
                            stateSwapAnim.restart();
                            return ;
                        }
                        text = newText;
                        stateEnterAnim.restart();
                    }

                    function hideText() {
                        shouldBeVisible = false;
                        pendingText = "";
                        stateEnterAnim.stop();
                        stateSwapAnim.stop();
                        stateExitAnim.restart();
                    }

                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: ""
                    opacity: 0
                    scale: 0.7
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Fonts.numeric
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    lineHeight: 1.2
                    onMsgChanged: {
                        refresh();
                    }
                    onBlockedChanged: refresh()

                    ParallelAnimation {
                        id: stateEnterAnim

                        NumberAnimation {
                            target: stateMessage
                            property: "scale"
                            to: 1
                            duration: Appearance.animation.expressiveDefaultSpatial.duration
                            easing.type: Appearance.animation.expressiveDefaultSpatial.type
                            easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                        }

                        NumberAnimation {
                            target: stateMessage
                            property: "opacity"
                            to: 1
                            duration: Appearance.animation.expressiveEffects.duration
                            easing.type: Appearance.animation.expressiveEffects.type
                            easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                        }

                    }

                    SequentialAnimation {
                        id: stateSwapAnim

                        ParallelAnimation {
                            NumberAnimation {
                                target: stateMessage
                                property: "scale"
                                to: 0.7
                                duration: Appearance.animation.standard.duration
                                easing.type: Appearance.animation.standard.type
                                easing.bezierCurve: Appearance.animation.standard.bezierCurve
                            }

                            NumberAnimation {
                                target: stateMessage
                                property: "opacity"
                                to: 0
                                duration: Appearance.animation.standard.duration
                                easing.type: Appearance.animation.standard.type
                                easing.bezierCurve: Appearance.animation.standard.bezierCurve
                            }

                        }

                        ScriptAction {
                            script: {
                                stateMessage.text = stateMessage.pendingText;
                                stateMessage.pendingText = "";
                            }
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: stateMessage
                                property: "scale"
                                to: 1
                                duration: Appearance.animation.expressiveDefaultSpatial.duration
                                easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                            }

                            NumberAnimation {
                                target: stateMessage
                                property: "opacity"
                                to: 1
                                duration: Appearance.animation.expressiveEffects.duration
                                easing.type: Appearance.animation.expressiveEffects.type
                                easing.bezierCurve: Appearance.animation.expressiveEffects.bezierCurve
                            }

                        }

                    }

                    ParallelAnimation {
                        id: stateExitAnim

                        onFinished: {
                            if (!stateMessage.shouldBeVisible)
                                stateMessage.text = "";

                        }

                        NumberAnimation {
                            target: stateMessage
                            property: "scale"
                            to: 0.7
                            duration: Appearance.animation.standardLarge.duration
                            easing.type: Appearance.animation.standardLarge.type
                            easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
                        }

                        NumberAnimation {
                            target: stateMessage
                            property: "opacity"
                            to: 0
                            duration: Appearance.animation.standardLarge.duration
                            easing.type: Appearance.animation.standardLarge.type
                            easing.bezierCurve: Appearance.animation.standardLarge.bezierCurve
                        }

                    }

                }

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Appearance.animation.standard.duration
                        easing.type: Appearance.animation.standard.type
                        easing.bezierCurve: Appearance.animation.standard.bezierCurve
                    }

                }

            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Metrics.lockCardGap

            SystemGrid {
                Layout.fillWidth: true
                radius: Metrics.lockCardRadiusSmall
                topRightRadius: Metrics.lockCardRadius
            }

            NotificationCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                compact: root.compact
                veryCompact: root.veryCompact
                radius: Metrics.lockCardRadiusSmall
                bottomRightRadius: Metrics.lockCardRadius
            }

        }

    }

    Timer {
        id: clockTimer

        property date now: new Date()

        interval: 1000
        running: true
        repeat: true
        onTriggered: now = new Date()
    }

}
