import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string title: ""
    property string iconName: "settings"
    property string backAccessibleName: qsTr("Back to General settings")
    signal backRequested

    implicitHeight: 56

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingL
        anchors.rightMargin: Metrics.spacingL
        spacing: Metrics.spacingS

        IconButton {
            iconName: "arrow_back"
            iconColor: Appearance.colors.colOnSurface
            accessibleName: root.backAccessibleName
            hoverStateLayerColor: Appearance.colors.colLayer2Hover
            pressedStateLayerColor: Appearance.colors.colLayer2Active
            onClicked: root.backRequested()
        }

        MaterialSymbol {
            visible: root.iconName !== ""
            Layout.preferredWidth: visible ? Metrics.iconM : 0
            Layout.preferredHeight: Metrics.iconM
            text: root.iconName
            iconSize: Metrics.iconM
            color: Appearance.colors.colOnSurfaceVariant
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Appearance.colors.colOnSurface
            font.family: Typography.titleLarge.family
            font.pixelSize: Typography.titleLarge.pixelSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
}
