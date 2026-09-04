import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property string message: qsTr("地图暂时不可用")
    property bool loading: false

    signal retryRequested()

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colSurfaceContainerHigh
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Metrics.spacingL * 2, 300)
        spacing: Metrics.spacingM

        MaterialLoadingIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: root.loading
            running: visible
        }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.loading
            text: "map"
            iconSize: 44
            color: Appearance.colors.colOnSurfaceVariant
        }

        Text {
            Layout.fillWidth: true
            visible: !root.loading
            text: root.message
            color: Appearance.colors.colOnSurface
            font.family: Typography.bodyLarge.family
            font.pixelSize: Typography.bodyLarge.pixelSize
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        ActionButton {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.loading
            text: qsTr("重试")
            iconName: "refresh"
            filled: true
            onClicked: root.retryRequested()
        }

    }

}
