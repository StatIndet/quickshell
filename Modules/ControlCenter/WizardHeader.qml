import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets.common

RowLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool showBack: false
    property bool closeEnabled: true

    signal backRequested()
    signal closeRequested()

    spacing: Metrics.spacingS

    IconButton {
        visible: root.showBack
        enabled: root.closeEnabled
        iconName: "arrow_back"
        accessibleName: qsTr("返回")
        onClicked: root.backRequested()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Metrics.spacingXXS

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Appearance.colors.colOnSurface
            font.family: Typography.headlineSmall.family
            font.pixelSize: Typography.headlineSmall.pixelSize
            font.weight: Typography.headlineSmall.weight
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Typography.bodyMedium.family
            font.pixelSize: Typography.bodyMedium.pixelSize
            font.weight: Typography.bodyMedium.weight
            elide: Text.ElideRight
        }
    }

    IconButton {
        enabled: root.closeEnabled
        iconName: "close"
        accessibleName: qsTr("关闭")
        onClicked: root.closeRequested()
    }
}
