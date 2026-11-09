import QtQuick
import QtQuick.Layouts
import qs.Common

RowLayout {
    id: root

    readonly property real playPauseCenterX: playButton.x + playButton.width / 2

    property bool isPlaying: false
    property bool shuffleActive: false
    property int loopMode: 0                  // 0 none, 1 playlist, 2 track
    property bool shuffleEnabled: true
    property bool previousEnabled: true
    property bool playPauseEnabled: true
    property bool nextEnabled: true
    property bool loopEnabled: true

    // === 控制按钮颜色 ===
    property color activeColor: Appearance.colors.colPrimary
    property color inactiveColor: Appearance.colors.colOnSurface
    property real inactiveOpacity: 0.7
    property real disabledOpacity: 0.35
    property real iconSize: 26
    property real skipIconSize: 32
    property string iconFontFamily: Fonts.materialSymbolsOutlined
    property string shuffleIconName: "shuffle"
    property string previousIconName: "skip_previous"
    property string nextIconName: "skip_next"
    property string repeatIconName: "repeat"
    property string repeatOneIconName: "repeat_one"
    property real controlHitMargin: 10
    property real controlPressedScale: 0.8
    property real controlHoverScale: 1.1
    property int controlScaleDuration: 150

    // === PlayPauseButton 颜色 ===
    property color playingBg: Appearance.colors.colPrimary
    property color playingFg: Appearance.colors.colOnPrimary
    property color pausedBg: Appearance.colors.colSecondaryContainer
    property color pausedFg: Appearance.colors.colOnSecondaryContainer

    // === PlayPauseButton 尺寸与形变 ===
    property real playButtonSize: 54
    property real playIconSize: 34
    property real playPressedScale: 1.0
    property real playHoverScale: 1.0
    property bool morphEnabled: true
    property string playIconName: "play_arrow"
    property string pauseIconName: "pause"

    signal shuffleClicked
    signal previousClicked
    signal playPauseClicked
    signal nextClicked
    signal loopClicked

    spacing: 40

    // --- 内部控制按钮组件 ---
    component CtrlBtn: Text {
        property bool active: false
        font.family: root.iconFontFamily
        font.pixelSize: root.iconSize
        color: active ? root.activeColor : root.inactiveColor
        opacity: !enabled ? root.disabledOpacity : (active ? 1.0 : root.inactiveOpacity)
        scale: enabled ? (ma.pressed ? root.controlPressedScale : (ma.containsMouse ? root.controlHoverScale :
                                                                                      1.0)) : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: root.controlScaleDuration
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -root.controlHitMargin
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: parent.enabled
            onClicked: parent.triggered()
        }
        signal triggered
    }

    // Shuffle
    CtrlBtn {
        text: root.shuffleIconName
        enabled: root.shuffleEnabled
        active: root.shuffleActive
        onTriggered: root.shuffleClicked()
    }

    // Previous
    CtrlBtn {
        text: root.previousIconName
        enabled: root.previousEnabled
        font.pixelSize: root.skipIconSize
        onTriggered: root.previousClicked()
    }

    // Play/Pause
    PlayPauseButton {
        id: playButton
        enabled: root.playPauseEnabled
        isPlaying: root.isPlaying
        playingBg: root.playingBg
        playingFg: root.playingFg
        pausedBg: root.pausedBg
        pausedFg: root.pausedFg
        buttonSize: root.playButtonSize
        iconSize: root.playIconSize
        pressedScale: root.playPressedScale
        hoverScale: root.playHoverScale
        iconFontFamily: root.iconFontFamily
        playIconName: root.playIconName
        pauseIconName: root.pauseIconName
        morphEnabled: root.morphEnabled
        opacity: enabled ? 1.0 : root.disabledOpacity
        onClicked: root.playPauseClicked()
    }

    // Next
    CtrlBtn {
        text: root.nextIconName
        enabled: root.nextEnabled
        font.pixelSize: root.skipIconSize
        onTriggered: root.nextClicked()
    }

    // Loop
    CtrlBtn {
        enabled: root.loopEnabled
        active: root.loopMode !== 0
        text: root.loopMode === 2 ? root.repeatOneIconName : root.repeatIconName
        onTriggered: root.loopClicked()
    }
}
