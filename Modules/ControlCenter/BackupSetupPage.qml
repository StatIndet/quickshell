import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Widgets.common

Item {
    id: root

    property var folderModel: []
    property var folderInfo: function(entry) {
        return ({
            "label": String(entry && entry.path || ""),
            "icon": "folder"
        });
    }
    property bool taskActive: false
    property bool canStart: false

    signal closeRequested()
    signal chooseFolderRequested()
    signal updateFolderRequested(int index, bool enabled)
    signal removeFolderRequested(int index)
    signal startRequested()
    signal viewTaskRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.spacingXL
        spacing: Metrics.spacingM

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingM

            Rectangle {
                Layout.preferredWidth: Metrics.controlHeightL
                Layout.preferredHeight: Metrics.controlHeightL
                radius: Appearance.rounding.normal
                color: Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "backup"
                    iconSize: Metrics.iconM
                    fill: 1
                    color: Appearance.colors.colOnPrimaryContainer
                }

            }

            Text {
                Layout.fillWidth: true
                text: qsTr("电脑备份")
                color: Appearance.colors.colOnSurface
                font.family: Typography.headlineSmall.family
                font.pixelSize: Typography.headlineSmall.pixelSize
                font.weight: Typography.headlineSmall.weight
            }

            IconButton {
                iconName: "close"
                accessibleName: qsTr("关闭")
                onClicked: root.closeRequested()
            }

        }

        Text {
            Layout.fillWidth: true
            text: qsTr("所选文件夹会同步到云端；被替换或删除的文件将保留在带时间戳的历史版本中。")
            color: Appearance.colors.colOnSurfaceVariant
            font.family: Typography.bodyMedium.family
            font.pixelSize: Typography.bodyMedium.pixelSize
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: activeTaskRow.implicitHeight + Metrics.spacingM * 2
            visible: root.taskActive
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSecondaryContainer

            RowLayout {
                id: activeTaskRow

                anchors.fill: parent
                anchors.margins: Metrics.spacingM
                spacing: Metrics.spacingM

                MaterialLoadingIndicator {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    contained: false
                    indicatorColor: Appearance.colors.colOnSecondaryContainer
                    accessibleName: qsTr("备份正在进行")
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("备份正在进行，文件夹设置暂时不可修改。")
                    color: Appearance.colors.colOnSecondaryContainer
                    font.family: Typography.bodyMedium.family
                    font.pixelSize: Typography.bodyMedium.pixelSize
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                }

                ActionButton {
                    text: qsTr("查看详情")
                    iconName: "arrow_forward"
                    onClicked: root.viewTaskRequested()
                }

            }

        }

        ListView {
            id: folderList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Metrics.spacingXS
            model: root.folderModel

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width, 320)
                visible: folderList.count === 0
                spacing: Metrics.spacingM

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 88
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colSecondaryContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "folder_off"
                        iconSize: 48
                        fill: 1
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("尚未添加备份文件夹")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.family: Typography.titleMedium.family
                    font.pixelSize: Typography.titleMedium.pixelSize
                    font.weight: Typography.titleMedium.weight
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

            }

            delegate: Rectangle {
                id: folderRow

                required property var modelData
                required property int index
                readonly property var info: root.folderInfo(folderRow.modelData)

                width: ListView.view ? ListView.view.width : 0
                height: 64
                radius: Appearance.rounding.normal
                color: Appearance.colors.colSurfaceContainerHighest

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.spacingM
                    anchors.rightMargin: Metrics.spacingXS
                    spacing: Metrics.spacingS

                    MaterialSymbol {
                        text: folderRow.info.icon
                        iconSize: Metrics.iconM
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: folderRow.info.label
                            color: Appearance.colors.colOnSurface
                            font.family: Typography.bodyMedium.family
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: folderRow.modelData.path
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Typography.bodySmall.family
                            font.pixelSize: Typography.bodySmall.pixelSize
                            elide: Text.ElideMiddle
                        }

                    }

                    StyledSwitch {
                        id: folderSwitch

                        checked: folderRow.modelData.enabled
                        enabled: !root.taskActive
                        Accessible.name: qsTr("备份 %1").arg(folderRow.info.label)
                        onToggled: root.updateFolderRequested(folderRow.index, folderSwitch.checked)
                    }

                    IconButton {
                        iconName: "close"
                        iconSize: Metrics.iconS
                        enabled: !root.taskActive
                        accessibleName: qsTr("移除 %1").arg(folderRow.info.label)
                        onClicked: root.removeFolderRequested(folderRow.index)
                    }

                }

            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingS

            ActionButton {
                text: qsTr("添加其他路径")
                iconName: "create_new_folder"
                enabled: !root.taskActive
                onClicked: root.chooseFolderRequested()
            }

            Item {
                Layout.fillWidth: true
            }

            ActionButton {
                text: qsTr("关闭")
                onClicked: root.closeRequested()
            }

            ActionButton {
                text: qsTr("开始备份")
                iconName: "backup"
                filled: true
                enabled: root.canStart && !root.taskActive
                onClicked: root.startRequested()
            }

        }

    }

}
