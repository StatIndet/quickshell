import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components

Rectangle {
    id: root

    property string iconName: ""
    property string title: ""
    property string supportingText: ""
    property bool interactive: false
    property bool highlighted: false
    property real iconFill: highlighted ? 1 : 0
    property Component leading
    property alias trailing: trailingSlot.data

    signal clicked()

    implicitHeight: Math.max(Metrics.controlHeightXL, rowLayout.implicitHeight + Metrics.spacingS * 2)
    radius: Metrics.cornerM
    color: {
        if (root.highlighted)
            return Appearance.colors.colLayer3;

        if (!root.interactive)
            return "transparent";

        if (pointer.pressed)
            return Appearance.colors.colLayer2Active;

        if (pointer.containsMouse)
            return Appearance.colors.colLayer2Hover;

        return "transparent";
    }
    opacity: enabled ? 1 : 0.45

    RowLayout {
        id: rowLayout

        z: 1
        spacing: Metrics.spacingS

        anchors {
            fill: parent
            leftMargin: Metrics.spacingS
            rightMargin: Metrics.spacingS
            topMargin: Metrics.spacingS
            bottomMargin: Metrics.spacingS
        }

        Loader {
            visible: root.leading !== null
            active: visible
            Layout.preferredWidth: visible ? Metrics.controlHeightM : 0
            Layout.preferredHeight: visible ? Metrics.controlHeightM : 0
            sourceComponent: root.leading
        }

        Rectangle {
            visible: root.leading === null && root.iconName.length > 0
            Layout.preferredWidth: Metrics.controlHeightM
            Layout.preferredHeight: Metrics.controlHeightM
            radius: Appearance.rounding.full
            color: root.highlighted ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

            MaterialSymbol {
                anchors.centerIn: parent
                text: root.iconName
                iconSize: Metrics.iconM - Metrics.spacingXXS
                fill: root.iconFill
                color: root.highlighted ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Metrics.dividerWidth

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Appearance.colors.colOnSurface
                font.family: Fonts.ui
                font.pixelSize: root.supportingText.length > 0 ? Typography.bodyMedium.pixelSize : Typography.bodyLarge.pixelSize
                font.weight: root.supportingText.length > 0 ? Typography.bodyMedium.weight : Font.Medium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.supportingText.length > 0
                text: root.supportingText
                color: Appearance.colors.colOnLayer1
                font.family: Fonts.ui
                font.pixelSize: 12
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }

        }

        RowLayout {
            id: trailingSlot

            Layout.alignment: Qt.AlignVCenter
            spacing: Metrics.spacingXS
        }

    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.enabled && root.interactive
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Appearance.animation.expressiveFastEffects.duration
            easing.type: Appearance.animation.expressiveFastEffects.type
            easing.bezierCurve: Appearance.animation.expressiveFastEffects.bezierCurve
        }

    }

}
