import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common

// Reusable Material 3 filled text field. The existing MaterialTextField keeps
// its outlined contract; this component owns the filled surface and indicator.
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
    color: root.enabled ? Appearance.colors.colOnSurface : Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38)
    selectedTextColor: Appearance.colors.colOnPrimaryContainer
    selectionColor: Appearance.colors.colPrimaryContainer
    placeholderTextColor: !root.enabled ? Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.38) : root.activeFocus ? root.effectiveAccent : Appearance.colors.colOnSurfaceVariant
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
        id: hoverHandler

        cursorShape: Qt.IBeamCursor
    }

    background: Rectangle {
        color: root.enabled ? root.containerColor : Appearance.applyAlpha(root.containerColor, 0.62)
        topLeftRadius: Metrics.cornerXS
        topRightRadius: Metrics.cornerXS

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.activeFocus || root.error ? 2 : 1
            opacity: root.enabled ? 1 : 0.38
            color: {
                if (root.error)
                    return Appearance.colors.colError;

                if (root.activeFocus)
                    return Appearance.colors.colPrimary;

                if (hoverHandler.hovered)
                    return Appearance.colors.colOutline;

                return Appearance.colors.colOutlineVariant;
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }

            }

            Behavior on height {
                NumberAnimation {
                    duration: Appearance.animation.expressiveFastEffects.duration
                    easing.type: Appearance.animation.expressiveFastEffects.type
                    easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
                }

            }

        }

    }

}
