import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + Metrics.pageMargin

    readonly property real pageContentWidth: 640

    component DefaultAppSettingRow: Item {
        id: settingRow

        required property string roleId
        required property string title
        required property string iconName

        readonly property var roleState:
            DefaultApplicationsService.stateFor(settingRow.roleId)
        readonly property var selectedOption: {
            const options = settingRow.roleState.candidates || [];
            return options.find(option =>
                option.value === settingRow.roleState.currentId) || null;
        }

        Layout.fillWidth: true
        Layout.preferredHeight: Metrics.controlHeightL

        RowLayout {
            id: rowColumn

            anchors.fill: parent
            spacing: Metrics.spacingS

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Metrics.iconM
                Layout.preferredHeight: Metrics.iconM
                text: settingRow.iconName
                iconSize: Metrics.iconM
                color: Appearance.colors.colOnSurfaceVariant

                // Keep the row icon as a glyph; only group headers use a
                // tonal icon container.
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: settingRow.title
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.bodyLarge.family
                    font.pixelSize: Typography.bodyLarge.pixelSize
                    font.weight: Typography.bodyLarge.weight
                    elide: Text.ElideRight
                }
            }

            Image {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Metrics.iconM
                Layout.preferredHeight: Metrics.iconM
                visible: settingRow.selectedOption !== null
                    && settingRow.selectedOption.icon !== ""
                source: settingRow.selectedOption
                    ? settingRow.selectedOption.icon : ""
                sourceSize.width: Metrics.iconM * 2
                sourceSize.height: Metrics.iconM * 2
                fillMode: Image.PreserveAspectFit
            }

            SearchSelectMenuField {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 220
                Layout.preferredHeight: Metrics.controlHeightM
                options: settingRow.roleState.candidates || []
                value: settingRow.roleState.currentId || ""
                placeholder: DefaultApplicationsService.loading
                    ? qsTr("正在加载…")
                    : settingRow.roleId === "terminal" && settingRow.roleState.currentId === ""
                        ? qsTr("系统默认") : qsTr("无可用应用")
                closeOnAccept: true
                enabled: !DefaultApplicationsService.loading
                    && !DefaultApplicationsService.busy
                    && (settingRow.roleState.candidates || []).length > 0
                Accessible.name: settingRow.title
                onAccepted: value =>
                    DefaultApplicationsService.setRole(settingRow.roleId, value)
            }
        }

        Text {
            anchors.left: rowColumn.left
            anchors.leftMargin: Metrics.controlHeightM + Metrics.spacingS
            anchors.right: rowColumn.right
            anchors.top: rowColumn.bottom
            visible: !DefaultApplicationsService.loading
                && (settingRow.roleState.candidates || []).length === 0
            text: qsTr("没有找到可用的系统应用")
            color: Appearance.colors.colError
            font.family: Typography.bodySmall.family
            font.pixelSize: Typography.bodySmall.pixelSize
        }
    }

    component DefaultAppsGroup: SettingsSection {
        property string groupTitle: ""
        property string groupIcon: "apps"

        flat: true
        flatIconContainer: true
        title: groupTitle
        iconName: groupIcon

        default property alias rows: body.data

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: Metrics.spacingXS
        }
    }

    Component.onCompleted: DefaultApplicationsService.refresh()

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth,
            Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        DefaultAppsGroup {
            Layout.fillWidth: true
            groupTitle: qsTr("互联网")
            groupIcon: "public"

            DefaultAppSettingRow {
                roleId: "browser"
                title: qsTr("网络浏览器")
                iconName: "language"
            }

            DefaultAppSettingRow {
                roleId: "mail"
                title: qsTr("邮件")
                iconName: "mail"
            }
        }

        DefaultAppsGroup {
            Layout.fillWidth: true
            groupTitle: qsTr("实用工具")
            groupIcon: "terminal"

            DefaultAppSettingRow {
                roleId: "file-manager"
                title: qsTr("文件管理器")
                iconName: "folder"
            }

            DefaultAppSettingRow {
                roleId: "terminal"
                title: qsTr("终端")
                iconName: "terminal"
            }
        }

        DefaultAppsGroup {
            Layout.fillWidth: true
            groupTitle: qsTr("文档")
            groupIcon: "description"

            DefaultAppSettingRow {
                roleId: "text-editor"
                title: qsTr("文本编辑器")
                iconName: "edit_note"
            }

            DefaultAppSettingRow {
                roleId: "pdf-reader"
                title: qsTr("PDF 阅读器")
                iconName: "picture_as_pdf"
            }
        }

        DefaultAppsGroup {
            Layout.fillWidth: true
            groupTitle: qsTr("多媒体")
            groupIcon: "movie"

            DefaultAppSettingRow {
                roleId: "image-viewer"
                title: qsTr("图像查看器")
                iconName: "image"
            }

            DefaultAppSettingRow {
                roleId: "video-player"
                title: qsTr("视频播放器")
                iconName: "smart_display"
            }

            DefaultAppSettingRow {
                roleId: "music-player"
                title: qsTr("音乐播放器")
                iconName: "music_note"
            }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: DefaultApplicationsService.lastError !== ""
            tone: "error"
            message: DefaultApplicationsService.lastError
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: DefaultApplicationsService.lastMessage !== ""
            tone: "info"
            message: DefaultApplicationsService.lastMessage
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: DefaultApplicationsService.loading
            iconName: "progress_activity"
            message: qsTr("正在读取系统默认应用…")
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.pageMargin
        }
    }
}
