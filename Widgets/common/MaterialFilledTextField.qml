import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common

// Reusable Material 3 filled text field. Qt's Material style owns the filled
// container and FloatingPlaceholderText, including its native label motion.
TextField {
    id: root

    property bool error: false
    property string labelText: ""
    property color containerColor: Appearance.colors.colLayer2
    property Component leadingContent
    property Component trailingContent
    property real leadingContentWidth: Metrics.iconM
    property real trailingContentWidth: Metrics.touchTarget
    readonly property bool hasLeadingContent: root.leadingContent !== null && root.leadingContent !== undefined
    readonly property bool hasTrailingContent: root.trailingContent !== null && root.trailingContent !== undefined
    readonly property color effectiveAccent: root.error ? Appearance.colors.colError : Appearance.colors.colPrimary

    implicitHeight: Metrics.controlHeightXL
    Material.theme: Appearance.m3colors.darkmode ? Material.Dark : Material.Light
    Material.accent: root.effectiveAccent
    Material.primary: root.effectiveAccent
    Material.background: root.containerColor
    Material.foreground: Appearance.colors.colOnSurface
    Material.containerStyle: Material.Filled
    renderType: Text.QtRendering
    selectByMouse: true
    wrapMode: TextInput.NoWrap
    activeFocusOnTab: true
    hoverEnabled: true
    color: root.enabled ? Appearance.colors.colOnSurface : Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)
    selectedTextColor: Appearance.colors.colOnSecondaryContainer
    selectionColor: Appearance.colors.colSecondaryContainer
    leftPadding: Metrics.spacingL + (root.hasLeadingContent ? root.leadingContentWidth + Metrics.spacingXS : 0)
    rightPadding: Metrics.spacingL + (root.hasTrailingContent ? root.trailingContentWidth + Metrics.spacingXS : 0)

    font {
        family: Typography.bodyLarge.family
        pixelSize: Typography.bodyLarge.pixelSize
        weight: Typography.bodyLarge.weight
        hintingPreference: Font.PreferFullHinting
    }

    // Match MaterialTextField's API: labelText supplies the Material label,
    // while callers may still set placeholderText directly when it is empty.
    Binding {
        target: root
        property: "placeholderText"
        value: root.labelText
        when: root.labelText.length > 0
        restoreMode: Binding.RestoreBindingOrValue
    }

    Loader {
        anchors.left: parent.left
        anchors.leftMargin: Metrics.spacingL
        anchors.verticalCenter: parent.verticalCenter
        width: root.hasLeadingContent ? root.leadingContentWidth : 0
        height: root.hasLeadingContent ? Math.min(root.height, Metrics.touchTarget) : 0
        sourceComponent: root.leadingContent
        z: 1
    }

    Loader {
        anchors.right: parent.right
        anchors.rightMargin: Metrics.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        width: root.hasTrailingContent ? root.trailingContentWidth : 0
        height: root.hasTrailingContent ? Math.min(root.height, Metrics.touchTarget) : 0
        sourceComponent: root.trailingContent
        z: 1
    }

    HoverHandler {
        cursorShape: Qt.IBeamCursor
    }

    // Qt's Material TextField continues to own the floating placeholder.
    // This replacement only supplies the shell's dynamic surface token, which
    // the stock Material dark palette otherwise ignores for filled fields.
    background: Rectangle {
        color: root.enabled ? root.containerColor : Appearance.colors.colLayer2Disabled

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.activeFocus || root.error ? 2 : 1
            opacity: root.enabled ? 1 : 0.38
            color: root.error ? Appearance.colors.colError : root.activeFocus ? root.effectiveAccent : root.hovered ? Appearance.colors.colOutline : Appearance.colors.colOutlineVariant
        }

    }

}
