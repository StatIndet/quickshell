import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Common
import qs.Components

Item {
    id: root
    property string iconName: ""
    property string label: ""
    property string tooltipText: ""
    property bool showLabel: false
    property bool vertical: false
    property bool selected: false
    readonly property bool hasLabel: showLabel && label !== ""
    signal clicked
    implicitWidth: pointer.implicitWidth
    implicitHeight: pointer.implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText
    Accessible.onPressAction: root.clicked()
    opacity: enabled ? 1 : 0.4
    BarActionButton {
        id: pointer
        anchors.fill: parent
        vertical: root.vertical
        expandedContent: root.hasLabel
        Accessible.name: root.tooltipText
        onClicked: root.clicked()
        contentItem: Item {
            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight
            GridLayout {
                id: content
                anchors.centerIn: parent
                columns: root.vertical ? 1 : 2
                rowSpacing: Sizes.barLabelSpacing
                columnSpacing: Sizes.barLabelSpacing
                MaterialSymbol {
                    Layout.preferredWidth: Sizes.barIconSize
                    Layout.preferredHeight: Sizes.barIconSize
                    Layout.alignment: Qt.AlignCenter
                    text: root.iconName
                    iconSize: Sizes.barIconSize
                    color: root.selected || pointer.visualFocus || pointer.pointerHovered
                           ? BarColors.selected : BarColors.foreground
                }
                Item {
                    visible: root.hasLabel
                    readonly property real extent: Math.min(120, labelText.implicitWidth)
                    implicitWidth: root.vertical ? labelText.implicitHeight : extent
                    implicitHeight: root.vertical ? extent : labelText.implicitHeight
                    Layout.alignment: Qt.AlignCenter
                    Text {
                        id: labelText
                        anchors.centerIn: parent
                        width: parent.extent
                        rotation: root.vertical ? (PersonalizationConfig.barPosition === "right" ? 90 : -90) :
                                                  0
                        text: root.label
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        color: BarColors.foreground
                    }
                }
            }
        }
    }
    PopupToolTip {
        extraVisibleCondition: pointer.pointerHovered
        text: root.tooltipText
    }
}
