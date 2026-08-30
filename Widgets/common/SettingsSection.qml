import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string title: ""
    property string iconName: ""
    property string supportingText: ""
    property real contentSpacing: Metrics.spacingXS
    // General subpages use the same semantic grouping without the overview
    // page's card containment. Keep the default so first-level pages retain
    // their existing visual language.
    property bool flat: false
    // Flat sections normally render title glyphs without containment. A small
    // number of overview-like pages keep their original tonal title icon.
    property bool flatIconContainer: false
    readonly property bool hasIconContainer: !root.flat || root.flatIconContainer
    default property alias content: body.data

    implicitHeight: sectionLayout.implicitHeight + (flat ? 0 : Metrics.cardPadding * 2)
    radius: flat ? 0 : Metrics.cornerL
    color: flat ? "transparent" : Appearance.colors.colLayer1

    ColumnLayout {
        id: sectionLayout

        spacing: Metrics.spacingS

        anchors {
            fill: parent
            margins: root.flat ? 0 : Metrics.cardPadding
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.title.length > 0 || root.iconName.length > 0
            spacing: Metrics.spacingS

            Rectangle {
                visible: root.iconName.length > 0
                Layout.preferredWidth: root.hasIconContainer ? Metrics.controlHeightM : Metrics.iconM
                Layout.preferredHeight: root.hasIconContainer ? Metrics.controlHeightM : Metrics.iconM
                radius: root.hasIconContainer ? Appearance.rounding.normal : 0
                color: root.hasIconContainer ? Appearance.colors.colSecondaryContainer : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.iconName
                    iconSize: Metrics.iconM
                    fill: root.hasIconContainer ? 1 : 0
                    color: root.hasIconContainer ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                }

            }

            Text {
                Layout.fillWidth: true
                visible: root.title.length > 0
                text: root.title
                color: root.flat ? Appearance.colors.colOnSurface : Appearance.colors.colOnLayer2
                font.family: Typography.titleMedium.family
                font.pixelSize: Typography.titleMedium.pixelSize
                font.weight: Typography.titleMedium.weight
                elide: Text.ElideRight
            }

        }

        Text {
            Layout.fillWidth: true
            visible: root.supportingText.length > 0
            text: root.supportingText
            color: root.flat ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnLayer1
            font.family: Fonts.ui
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: root.contentSpacing
        }

    }

    Behavior on implicitHeight {
        enabled: !root.flat

        ElementMoveAnimation {
        }

    }

}
