import QtQuick
import QtQuick.Layouts
import QtQml.Models
import qs.Services

Item {
    id: root

    required property var screen
    required property var axis
    property bool vertical: false
    property string popupEdge: axis.edge
    // These implicit extents are independent of the shortened visual band.
    readonly property real minimumLength: (vertical ? leadingSection.implicitHeight
                                                      + trailingSection.implicitHeight :
                                                      leadingSection.implicitWidth
                                                      + trailingSection.implicitWidth) + 2
                                          * PersonalizationConfig.barInsetPadding
                                          + leadingSection.columnSpacing
    readonly property Item leadingInputRegionItem: leadingSection
    readonly property Item trailingInputRegionItem: trailingSection
    BarSection {
        id: leadingSection

        vertical: root.vertical
        compact: (root.vertical ? root.screen.height : root.screen.width) < 1000
        componentCount: PersonalizationConfig.barLeadingComponents.length

        anchors {
            left: root.vertical ? undefined : parent.left
            top: root.vertical ? parent.top : undefined
            leftMargin: root.vertical ? 0 : PersonalizationConfig.barInsetPadding
            topMargin: root.vertical ? PersonalizationConfig.barInsetPadding : 0
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        }
    }

    BarSection {
        id: trailingSection

        vertical: root.vertical
        compact: (root.vertical ? root.screen.height : root.screen.width) < 1000
        componentCount: PersonalizationConfig.barTrailingComponents.length

        anchors {
            right: root.vertical ? undefined : parent.right
            bottom: root.vertical ? parent.bottom : undefined
            rightMargin: root.vertical ? 0 : PersonalizationConfig.barInsetPadding
            bottomMargin: root.vertical ? PersonalizationConfig.barInsetPadding : 0
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        }
    }

    Instantiator {
        id: componentInstantiator

        model: PersonalizationConfig.barComponentIds

        delegate: BarComponentLoader {
            id: componentLoader

            required property string modelData
            readonly property int leadingIndex: PersonalizationConfig.barLeadingComponents.indexOf(modelData)
            readonly property int trailingIndex: PersonalizationConfig.barTrailingComponents.indexOf(
                                                     modelData)
            readonly property int zoneIndex: leadingIndex >= 0 ? leadingIndex : trailingIndex

            componentId: modelData
            screen: root.screen
            axis: root.axis
            barVisualItem: root
            vertical: root.vertical
            active: zoneIndex >= 0
            visible: active
            parent: leadingIndex >= 0 ? leadingSection : trailingSection
            Layout.row: root.vertical ? Math.max(0, zoneIndex) : 0
            Layout.column: root.vertical ? 0 : Math.max(0, zoneIndex)
            Layout.alignment: Qt.AlignCenter
        }
    }
}
