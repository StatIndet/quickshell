import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

Item {
    id: root

    property string iconName: ""
    property string primaryText: ""
    property string supportingText: ""
    property real iconSize: 20
    property real spacing: Appearance.spacing.small
    property real maximumTextWidth: 1000000
    property real iconFill: 0
    property color iconColor: Appearance.colors.colOnSurface
    property color primaryColor: Appearance.colors.colOnSurface
    property color supportingColor: Appearance.colors.colOnSurfaceVariant
    property int primaryPixelSize: Typography.labelLarge.pixelSize
    property int supportingPixelSize: Typography.labelSmall.pixelSize
    property int primaryWeight: Font.Medium

    implicitWidth: contentRow.implicitWidth
    implicitHeight: contentRow.implicitHeight

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: root.spacing

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            visible: root.iconName.length > 0
            text: root.iconName
            iconSize: root.iconSize
            fill: root.iconFill
            color: root.iconColor
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.maximumTextWidth
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.primaryText
                color: root.primaryColor
                font.family: Fonts.ui
                font.pixelSize: root.primaryPixelSize
                font.weight: root.primaryWeight
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.supportingText.length > 0
                text: root.supportingText
                color: root.supportingColor
                font.family: Fonts.ui
                font.pixelSize: root.supportingPixelSize
                elide: Text.ElideRight
            }
        }
    }
}
