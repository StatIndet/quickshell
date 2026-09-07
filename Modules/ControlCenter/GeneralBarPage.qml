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
            Layout.fillWidth: true
            flat: true
            title: qsTr("Position")
            iconName: "dock_to_bottom"

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
            Layout.fillWidth: true
            flat: true
            title: qsTr("Components")
            iconName: "view_agenda"
            supportingText: qsTr("Drag components to reorder them or move them to the other side.")

            SettingsRow {
                Layout.fillWidth: true
                title: root.horizontalBar ? qsTr("Left") : qsTr("Top")

                trailing: SortableMultiSelectField {
                    id: leadingField

                    Layout.preferredWidth: 380
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
                Layout.fillWidth: true
                title: root.horizontalBar ? qsTr("Right") : qsTr("Bottom")

                trailing: SortableMultiSelectField {
                    id: trailingField

                    Layout.preferredWidth: 380
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
