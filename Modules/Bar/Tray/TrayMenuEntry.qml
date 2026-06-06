import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Components
import qs.Widgets.common

MaterialRippleButton {
    id: root

    required property var menuEntry
    property bool forceIconColumn: false
    property bool forceSpecialInteractionColumn: false
    readonly property bool isSeparator: root.menuEntry.isSeparator === true
    readonly property string entryIcon: root.menuEntry.icon || ""
    readonly property bool hasIcon: entryIcon.length > 0
    readonly property int entryButtonType: root.menuEntry.buttonType === undefined ? QsMenuButtonType.None : root.menuEntry.buttonType
    readonly property bool hasSpecialInteraction: entryButtonType !== QsMenuButtonType.None
    readonly property color entryForeground: root.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
    readonly property color entrySubtleForeground: root.pointerHovered ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant

    signal dismiss()
    signal openSubmenu(var handle)

    colBackground: isSeparator ? Appearance.m3colors.m3outlineVariant : Appearance.transparentize(Appearance.colors.colLayer0, 1)
    colBackgroundHover: Appearance.colors.colSecondaryContainer
    colRipple: Appearance.colors.colSecondaryContainerActive
    enabled: !isSeparator && root.menuEntry.enabled !== false
    opacity: isSeparator ? 1 : (enabled ? 1 : 0.4)
    rippleEnabled: false
    buttonRadius: 14

    implicitWidth: isSeparator ? 96 : contentRow.implicitWidth + 24
    implicitHeight: isSeparator ? 1 : 36
    Layout.topMargin: isSeparator ? 4 : 0
    Layout.bottomMargin: isSeparator ? 4 : 0
    Layout.fillWidth: true

    releaseAction: () => {
        if (root.menuEntry.hasChildren) {
            root.openSubmenu(root.menuEntry);
            return;
        }

        if (typeof root.menuEntry.triggered === "function")
            root.menuEntry.triggered();

        root.dismiss();
    }

    altAction: event => {
        event.accepted = false;
    }

    contentItem: RowLayout {
        id: contentRow

        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 8
        visible: !root.isSeparator

        Item {
            visible: root.hasSpecialInteraction || root.forceSpecialInteractionColumn
            implicitWidth: 20
            implicitHeight: 20
            Layout.alignment: Qt.AlignVCenter

            Loader {
                anchors.fill: parent
                active: root.entryButtonType === QsMenuButtonType.RadioButton

                sourceComponent: Item {
                    Rectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: Appearance.rounding.full
                        color: "transparent"
                        border.width: 2
                        border.color: root.menuEntry.checkState === Qt.Checked
                            ? Appearance.colors.colPrimary
                            : root.entrySubtleForeground

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.menuEntry.checkState === Qt.Checked ? 10 : 4
                            height: root.menuEntry.checkState === Qt.Checked ? 10 : 4
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colPrimary
                            opacity: root.menuEntry.checkState === Qt.Checked ? 1 : 0

                            Behavior on width {
                                NumberAnimation {
                                    duration: Appearance.animation.expressiveDefaultSpatial.duration
                                    easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                    easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                                }
                            }
                            Behavior on height {
                                NumberAnimation {
                                    duration: Appearance.animation.expressiveDefaultSpatial.duration
                                    easing.type: Appearance.animation.expressiveDefaultSpatial.type
                                    easing.bezierCurve: Appearance.animation.expressiveDefaultSpatial.bezierCurve
                                }
                            }
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
            }

            Loader {
                anchors.fill: parent
                active: root.entryButtonType === QsMenuButtonType.CheckBox && root.menuEntry.checkState !== Qt.Unchecked

                sourceComponent: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.menuEntry.checkState === Qt.PartiallyChecked ? "check_indeterminate_small" : "check"
                    iconSize: 20
                    color: root.entryForeground
                }
            }
        }

        Item {
            visible: root.hasIcon || root.forceIconColumn
            implicitWidth: 20
            implicitHeight: 20
            Layout.alignment: Qt.AlignVCenter

            Loader {
                anchors.centerIn: parent
                active: root.hasIcon

                sourceComponent: IconImage {
                    asynchronous: true
                    source: root.entryIcon
                    implicitSize: 20
                    width: 20
                    height: 20
                    mipmap: true
                }
            }
        }

        Text {
            text: root.menuEntry.text || ""
            color: root.entryForeground
            font.family: Sizes.fontFamily
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
        }

        Loader {
            active: root.menuEntry.hasChildren === true
            Layout.alignment: Qt.AlignVCenter

            sourceComponent: MaterialSymbol {
                text: "chevron_right"
                iconSize: 20
                color: root.entryForeground
            }
        }
    }
}
