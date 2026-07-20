import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Clavis.Keyboard 1.0
import qs.Common
import qs.Services
import "Cards"

Item {
    id: root

    property var context: null
    property real screenHeight: height

    readonly property real centerScale: Math.min(1, root.screenHeight / 1440)
    readonly property real centerWidth: Sizes.lockCenterWidth * centerScale

    function forceAuthFocus() {
        authCard.forceActiveFocus();
    }

    RowLayout {
        anchors.fill: parent
        spacing: Sizes.lockColumnGap

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Sizes.lockCardGap

            WeatherCard {
                Layout.fillWidth: true
                radius: Sizes.lockCardRadiusSmall
                topLeftRadius: Sizes.lockCardRadiusLarge
                rootHeight: root.screenHeight
            }

            LockFetchCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Sizes.lockCardRadiusSmall
            }

            MediaCard {
                Layout.fillWidth: true
                radius: Sizes.lockCardRadiusSmall
                bottomLeftRadius: Sizes.lockCardRadiusLarge
            }
        }

        ColumnLayout {
            Layout.preferredWidth: root.centerWidth
            Layout.fillHeight: true
            Layout.fillWidth: false
            spacing: Sizes.lockColumnGap

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Math.round(7 * 4 / 3)

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Qt.formatTime(clockTimer.now, "hh")
                    color: Appearance.colors.colSecondary
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Math.floor(Sizes.lockTimeFontSize * root.centerScale)
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: ":"
                    color: Appearance.colors.colPrimary
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Math.floor(Sizes.lockTimeFontSize * root.centerScale)
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Qt.formatTime(clockTimer.now, "mm")
                    color: Appearance.colors.colSecondary
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Math.floor(Sizes.lockTimeFontSize * root.centerScale)
                    font.bold: true
                }

                Text {
                    Layout.leftMargin: Math.round(7 * 4 / 3)
                    Layout.alignment: Qt.AlignVCenter
                    text: Qt.formatTime(clockTimer.now, "AP")
                    color: Appearance.colors.colPrimary
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Math.floor(Sizes.lockTimeSuffixFontSize * root.centerScale)
                    font.bold: true
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -Sizes.lockOuterPadding * 2
                text: Qt.formatDate(clockTimer.now, "dddd, d MMMM yyyy")
                color: Appearance.colors.colTertiary
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Math.floor(Sizes.lockDateFontSize * root.centerScale)
                font.bold: true
            }

            Item {
                Layout.preferredWidth: root.centerWidth / 2
                Layout.preferredHeight: root.centerWidth / 2
                Layout.topMargin: Sizes.lockColumnGap
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
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: parent.width * 0.45
                }
            }

            AuthCard {
                id: authCard
                Layout.preferredWidth: root.centerWidth * 0.8
                Layout.preferredHeight: Sizes.lockAuthHeight
                Layout.alignment: Qt.AlignHCenter
                context: root.context

                onRequestUnlock: {
                    if (root.context)
                        root.context.tryUnlock();
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.topMargin: -Math.round(20 * 4 / 3)
                implicitHeight: Math.max(errorMessage.implicitHeight, stateMessage.implicitHeight, 18)

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Appearance.animation.standard.duration
                        easing.type: Appearance.animation.standard.type
                        easing.bezierCurve: Appearance.animation.standard.bezierCurve
                    }
                }

                Text {
                    id: errorMessage

                    property string msg: root.context && root.context.showFailure ? "Incorrect password. Please try again." : ""
                    property string pendingText: ""

                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: ""
                    opacity: 0
                    scale: 0.7
                    color: Appearance.colors.colError
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    lineHeight: 1.2

                    function showText(newText) {
                        if (newText === text && opacity > 0) {
                            errorExitAnim.stop();
                            if (scale < 1)
                                errorAppearAnim.restart();
                            else
                                errorFlashAnim.restart();
                            return;
                        }

                        errorExitAnim.stop();
                        errorFlashAnim.stop();

                        if (opacity > 0 && text.length > 0) {
                            pendingText = newText;
                            errorSwapAnim.restart();
                            return;
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

                        onFinished: errorFlashAnim.restart()
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
                            return "Caps lock and Num lock are ON.";
                        if (KeyboardLockState.capsLock)
                            return "Caps lock is ON.";
                        if (KeyboardLockState.numLock)
                            return "Num lock is ON.";
                        return "";
                    }
                    property bool blocked: errorMessage.msg.length > 0
                    property bool shouldBeVisible: false
                    property string pendingText: ""

                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: ""
                    opacity: 0
                    scale: 0.7
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Math.floor(12 * Sizes.lockReferenceScale)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    lineHeight: 1.2

                    function refresh() {
                        if (blocked || msg.length === 0) {
                            hideText();
                            return;
                        }

                        showText(msg);
                    }

                    function showText(newText) {
                        shouldBeVisible = true;
                        stateExitAnim.stop();

                        if (newText === text && opacity > 0)
                            return;

                        if (opacity > 0 && text.length > 0) {
                            pendingText = newText;
                            stateSwapAnim.restart();
                            return;
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

                        onFinished: {
                            if (!stateMessage.shouldBeVisible)
                                stateMessage.text = "";
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Sizes.lockCardGap

            SystemGrid {
                Layout.fillWidth: true
                Layout.preferredHeight: Sizes.lockSystemGridHeight
                radius: Sizes.lockCardRadiusSmall
                topRightRadius: Sizes.lockCardRadiusLarge
            }

            NotificationCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Sizes.lockCardRadiusSmall
                bottomRightRadius: Sizes.lockCardRadiusLarge
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
