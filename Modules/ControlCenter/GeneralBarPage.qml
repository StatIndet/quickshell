import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    readonly property bool horizontalBar: PersonalizationConfig.barPosition === "top"
                                          || PersonalizationConfig.barPosition === "bottom"

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingL

        SettingsSection {
            id: searchSection0
            Layout.fillWidth: true
            flat: true
            title: searchAnchor0.title
            SettingsSearchAnchor {
                id: searchAnchor0
                target: searchSection0
                declaration:
                    '{"id":"general.bar.section.position","route":"general.bar","title":"Position","context":"GeneralBarPage","icon":"dock_to_bottom","aliases":[]}'
            }
            iconName: "dock_to_bottom"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Show bar")
                trailing: StyledSwitch {
                    checked: PersonalizationConfig.barEnabled
                    Accessible.name: qsTr("Show bar")
                    onToggled: PersonalizationConfig.setValue("barEnabled", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Floating")
                trailing: StyledSwitch {
                    checked: PersonalizationConfig.barOverlay
                    Accessible.name: qsTr("Floating")
                    onToggled: PersonalizationConfig.setValue("barOverlay", checked)
                }
            }

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Screen edge")

                trailing: EdgePositionSelector {
                    position: PersonalizationConfig.barPosition
                    onPositionSelected: position => {
                        return PersonalizationConfig.setBarPosition(position);
                    }
                }
            }
        }

        SettingsSection {
            id: dimensionsSection
            Layout.fillWidth: true
            flat: true
            title: dimensionsSearchAnchor.title
            iconName: "space_bar"
            SettingsSearchAnchor {
                id: dimensionsSearchAnchor
                target: dimensionsSection
                declaration:
                    '{"id":"general.bar.section.size-spacing","route":"general.bar","title":"Size and spacing","context":"GeneralBarPage","icon":"space_bar","aliases":[]}'
            }

            GeneralSliderSetting {
                title: qsTr("Edge spacing")
                value: PersonalizationConfig.barEdgeSpacing
                from: PersonalizationConfig.barDimensionLimits.edgeSpacing[1]
                to: PersonalizationConfig.barDimensionLimits.edgeSpacing[2]
                suffix: qsTr(" px")
                onMoved: value => PersonalizationConfig.setPanelDimension("bar", "edgeSpacing", value)
            }

            GeneralSliderSetting {
                title: qsTr("Exclusive zone offset")
                value: PersonalizationConfig.barExclusiveZoneOffset
                from: PersonalizationConfig.barDimensionLimits.exclusiveZoneOffset[1]
                to: PersonalizationConfig.barDimensionLimits.exclusiveZoneOffset[2]
                suffix: qsTr(" px")
                enabled: !PersonalizationConfig.barOverlay
                onMoved: value => PersonalizationConfig.setPanelDimension("bar", "exclusiveZoneOffset", value)
            }

            GeneralSliderSetting {
                title: qsTr("Size")
                value: PersonalizationConfig.barThickness
                from: PersonalizationConfig.barDimensionLimits.thickness[1]
                to: PersonalizationConfig.barDimensionLimits.thickness[2]
                suffix: qsTr(" px")
                onMoved: value => PersonalizationConfig.setPanelDimension("bar", "thickness", value)
            }

            GeneralSliderSetting {
                title: qsTr("Inner padding")
                value: PersonalizationConfig.barInnerPadding
                from: PersonalizationConfig.barDimensionLimits.innerPadding[1]
                to: PersonalizationConfig.barDimensionLimits.innerPadding[2]
                suffix: qsTr(" px")
                onMoved: value => PersonalizationConfig.setPanelDimension("bar", "innerPadding", value)
            }

            GeneralSliderSetting {
                title: qsTr("Inset padding")
                value: PersonalizationConfig.barInsetPadding
                from: PersonalizationConfig.barDimensionLimits.insetPadding[1]
                to: PersonalizationConfig.barDimensionLimits.insetPadding[2]
                suffix: qsTr(" px")
                onMoved: value => PersonalizationConfig.setPanelDimension("bar", "insetPadding", value)
            }

            GeneralSliderSetting {
                title: qsTr("Bar length padding")
                description: qsTr("Limited by the space required by visible modules.")
                value: PersonalizationConfig.barLengthPadding
                from: PersonalizationConfig.barDimensionLimits.lengthPadding[1]
                to: PersonalizationConfig.barDimensionLimits.lengthPadding[2]
                suffix: qsTr(" px")
                onMoved: value => PersonalizationConfig.setPanelDimension("bar", "lengthPadding", value)
            }
        }

        SettingsSection {
            id: searchSection1
            Layout.fillWidth: true
            flat: true
            title: searchAnchor1.title
            SettingsSearchAnchor {
                id: searchAnchor1
                target: searchSection1
                declaration:
                    '{"id":"general.bar.section.components","route":"general.bar","title":"Components","context":"GeneralBarPage","icon":"dock_to_bottom","aliases":[]}'
            }
            iconName: "view_agenda"

            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Show device names")
                trailing: StyledSwitch {
                    checked: PersonalizationConfig.barShowNames
                    Accessible.name: qsTr("Show device names")
                    onToggled: PersonalizationConfig.setBarShowNames(checked)
                }
            }
            SettingsRow {
                Layout.fillWidth: true
                title: qsTr("Show numeric values")
                trailing: StyledSwitch {
                    checked: PersonalizationConfig.barShowValues
                    Accessible.name: qsTr("Show numeric values")
                    onToggled: PersonalizationConfig.setBarShowValues(checked)
                }
            }
            supportingText: qsTr("Drag components to reorder them or move them to the other side.")

            SettingsRow {
                id: leadingFieldRow
                Layout.fillWidth: true
                title: root.horizontalBar ? qsTr("Left") : qsTr("Top")

                trailing: SortableMultiSelectField {
                    id: leadingField

                    Layout.minimumWidth: 0
                    Layout.preferredWidth: Math.max(0, leadingFieldRow.width - 96 - 3 * Metrics.spacingS)
                    values: PersonalizationConfig.barLeadingComponents
                    options: PersonalizationConfig.barComponentOptions
                    zone: "leading"
                    dragCoordinator: dragCoordinator
                    onToggled: componentId => {
                        return PersonalizationConfig.toggleBarComponent(componentId, zone);
                    }
                    onRemoved: componentId => {
                        return PersonalizationConfig.removeBarComponent(componentId);
                    }
                }
            }

            SettingsRow {
                id: trailingFieldRow
                Layout.fillWidth: true
                title: root.horizontalBar ? qsTr("Right") : qsTr("Bottom")

                trailing: SortableMultiSelectField {
                    id: trailingField

                    Layout.minimumWidth: 0
                    Layout.preferredWidth: Math.max(0, trailingFieldRow.width - 96 - 3 * Metrics.spacingS)
                    values: PersonalizationConfig.barTrailingComponents
                    options: PersonalizationConfig.barComponentOptions
                    zone: "trailing"
                    dragCoordinator: dragCoordinator
                    onToggled: componentId => {
                        return PersonalizationConfig.toggleBarComponent(componentId, zone);
                    }
                    onRemoved: componentId => {
                        return PersonalizationConfig.removeBarComponent(componentId);
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Metrics.spacingS
                Layout.rightMargin: Metrics.spacingS
                spacing: Metrics.spacingS

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Quick settings widgets")
                    color: Appearance.colors.colOnSurface
                    font.family: Fonts.ui
                    font.pixelSize: Typography.bodyLarge.pixelSize
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                SortableMultiSelectField {
                    id: quickSettingsField

                    Layout.fillWidth: true
                    values: PersonalizationConfig.quickSettingsComponents
                    options: PersonalizationConfig.quickSettingsComponentOptions
                    zone: "quickSettings"
                    dragCoordinator: quickSettingsDragCoordinator
                    onToggled: componentId => {
                        return PersonalizationConfig.toggleQuickSettingsComponent(componentId);
                    }
                    onRemoved: componentId => {
                        return PersonalizationConfig.removeQuickSettingsComponent(componentId);
                    }
                }
            }
        }
    }

    BarLayoutDragCoordinator {
        id: dragCoordinator

        anchors.fill: parent
        z: 1000
        fields: [leadingField, trailingField]
        onDropped: (componentId, targetZone, targetIndex) => {
            return PersonalizationConfig.moveBarComponent(componentId, targetZone, targetIndex);
        }
    }

    BarLayoutDragCoordinator {
        id: quickSettingsDragCoordinator

        anchors.fill: parent
        z: 1001
        fields: [quickSettingsField]
        onDropped: (componentId, targetZone, targetIndex) => {
            return PersonalizationConfig.moveQuickSettingsComponent(componentId, targetIndex);
        }
    }
}
