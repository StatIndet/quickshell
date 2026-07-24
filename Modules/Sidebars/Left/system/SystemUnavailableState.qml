import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string title: "系统监测服务不可用"
    property string message: "请确认 key 已构建并可从当前环境运行。"
    property bool reconnecting: false
    signal retryRequested

    implicitHeight: unavailableLayout.implicitHeight
        + Appearance.spacing.large * 2
    radius: Appearance.rounding.small
    color: reconnecting
        ? Appearance.colors.colTertiaryContainer
        : Appearance.colors.colErrorContainer
    readonly property color foregroundColor: reconnecting
        ? Appearance.colors.colOnTertiaryContainer
        : Appearance.colors.colOnErrorContainer

    ColumnLayout {
        id: unavailableLayout

        anchors {
            fill: parent
            margins: Appearance.spacing.large
        }
        spacing: Appearance.spacing.medium

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: root.reconnecting ? "sync" : "monitor_heart"
            iconSize: 32
            color: root.foregroundColor
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: root.foregroundColor
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeTitleMedium
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            text: root.message
            color: root.foregroundColor
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.typeBodyMedium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        ProgressBar {
            Layout.fillWidth: true
            visible: root.reconnecting
            indeterminate: true
            Material.accent: root.foregroundColor
            Accessible.name: "正在重新连接系统监测服务"
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumHeight: 48
            visible: !root.reconnecting
            text: "重试"
            highlighted: true
            Material.accent: Appearance.colors.colOnErrorContainer
            Material.foreground: Appearance.colors.colErrorContainer
            Accessible.name: "重试系统监测连接"
            onClicked: root.retryRequested()
        }
    }
}
