import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services

Rectangle {
    id: root

    property string title: qsTr("System monitor service unavailable")
    property string message: qsTr("Confirm that key is built and can run in the current environment.")
    property bool reconnecting: false
    signal retryRequested

    implicitHeight: unavailableLayout.implicitHeight + Appearance.spacing.large * 2
    radius: Appearance.rounding.small
    color: BlurService.solidBackgroundColor(Appearance.m3colors.m3surfaceContainer)
    readonly property color foregroundColor: reconnecting ? Appearance.colors.colOnSurface :
                                                            Appearance.colors.colOnSurface

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
            font.family: Fonts.ui
            font.pixelSize: Typography.titleMedium.pixelSize
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            text: root.message
            color: root.foregroundColor
            font.family: Fonts.ui
            font.pixelSize: Typography.bodyMedium.pixelSize
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        ProgressBar {
            Layout.fillWidth: true
            visible: root.reconnecting
            indeterminate: true
            Material.accent: root.foregroundColor
            Accessible.name: qsTr("Reconnecting to the system monitor service")
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumHeight: 48
            visible: !root.reconnecting
            text: qsTr("Retry")
            highlighted: true
            Material.accent: Appearance.colors.colPrimary
            Accessible.name: qsTr("Retry the system monitor connection")
            onClicked: root.retryRequested()
        }
    }
}
