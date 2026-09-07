import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property alias headerTools: headerToolsLayout.data
    default property alias content: contentLayout.data
    property var closeAction: () => {}
    property bool showBackButton: false
    property var backAction: closeAction

    // 剥离背景色与边框，让底部固定的液态遮罩透出来！
    color: "transparent"
    border.color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.spacing.panelPadding
        spacing: 16

        RowLayout {
            Layout.fillWidth: true

            IconButton {
                visible: root.showBackButton
                iconName: "arrow_back"
                iconSize: 22
                iconColor: Appearance.colors.colOnLayer2
                accessibleName: qsTr("Back to Quick Settings")
                hoverStateLayerColor: Appearance.colors.colLayer2Hover
                pressedStateLayerColor: Appearance.colors.colLayer2Active
                onClicked: root.backAction()
            }

            MaterialSymbol {
                visible: !root.showBackButton
                text: root.icon
                iconSize: 22
                color: Appearance.colors.colPrimary
                Layout.preferredWidth: 22
                Layout.preferredHeight: 40
            }

            Text {
                text: root.title
                font.family: Fonts.ui
                font.bold: true
                font.pixelSize: 18
                color: Appearance.colors.colOnLayer2
                Layout.fillWidth: true
                Layout.leftMargin: root.showBackButton ? 0 : 10
                elide: Text.ElideRight
            }

            RowLayout {
                id: headerToolsLayout
                spacing: 12
            }
        }

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
