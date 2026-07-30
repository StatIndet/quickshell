import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common

StyledFlickable {
    id: root

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + 24

    readonly property real pageContentWidth: 600
    readonly property var systemMonitorMetrics: [
        ({ "id": "cpu", "title": qsTr("CPU 占用"),
           "icon": "memory" }),
        ({ "id": "temperature", "title": qsTr("CPU 温度"),
           "icon": "device_thermostat" }),
        ({ "id": "gpu", "title": qsTr("GPU 占用"),
           "icon": "developer_board" }),
        ({ "id": "power", "title": qsTr("实时功耗"),
           "icon": "bolt" }),
        ({ "id": "disk", "title": qsTr("硬盘占用"),
           "icon": "hard_drive" })
    ]
    readonly property var templatePrograms: [
        ({
            "id": "btop",
            "title": "btop",
            "icon": "monitoring"
        }),
        ({
            "id": "cava",
            "title": "Cava",
            "icon": "graphic_eq"
        }),
        ({
            "id": "kitty",
            "title": "Kitty",
            "icon": "terminal"
        }),
        ({
            "id": "fcitx5",
            "title": "Fcitx5",
            "icon": "keyboard"
        }),
        ({
            "id": "niri",
            "title": "Niri",
            "icon": "window"
        }),
        ({
            "id": "yazi",
            "title": "Yazi",
            "icon": "folder"
        }),
        ({
            "id": "zsh_prompt",
            "title": "Zsh prompt",
            "icon": "code"
        })
    ]

    ColumnLayout {
        id: contentColumn

        width: Math.min(root.pageContentWidth,
            Math.max(0, root.width - 48))
        x: Math.max(24, (root.width - width) / 2)
        y: 28
        spacing: Appearance.spacing.medium

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: ThemeService.generating
            message: qsTr("正在为已启用的程序生成 Matugen 配色…")
            iconName: "progress_activity"
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Shell 外观")
            supportingText: qsTr("控制 Clavis 顶栏、侧边栏、设置中心和弹出面板是否跟随主题的深浅色变化。")

            SettingsRow {
                Layout.fillWidth: true
                iconName: "contrast"
                title: qsTr("Clavis 界面跟随深浅色")
                supportingText: PersonalizationConfig.shellFollowThemeMode
                    ? qsTr("已跟随；日出日落自动模式也会同步改变 Shell 配色")
                    : qsTr("已关闭；应用仍会切换，Clavis 保持当前配色")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.shellFollowThemeMode
                    Accessible.name: qsTr("Clavis 界面跟随深浅色")
                    onToggled:
                        ThemeService.setShellFollowThemeMode(checked)
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("顶栏系统监控")
            supportingText: qsTr("选择鼠标悬停在右上角内存指标时展开显示的内容。内存用量始终作为折叠状态的主指标。")

            Repeater {
                model: root.systemMonitorMetrics

                SettingsRow {
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: modelData.icon
                    title: modelData.title
                    supportingText:
                        PersonalizationConfig
                            .isBarSystemMonitorMetricEnabled(modelData.id)
                        ? qsTr("悬停展开时显示")
                        : qsTr("已隐藏")

                    trailing: StyledSwitch {
                        checked:
                            PersonalizationConfig
                                .isBarSystemMonitorMetricEnabled(
                                    modelData.id)
                        Accessible.name:
                            qsTr("显示%1").arg(modelData.title)
                        onToggled:
                            PersonalizationConfig
                                .setBarSystemMonitorMetricEnabled(
                                    modelData.id, checked)
                    }
                }
            }
        }

        SettingsSection {
            Layout.fillWidth: true
            title: qsTr("Matugen 模板生成")
            supportingText: qsTr("壁纸或主题变化时，仅为已启用的程序生成模板。Quickshell 配色始终生成。关闭开关不会删除已有配色文件。")

            Repeater {
                model: root.templatePrograms

                SettingsRow {
                    required property var modelData

                    Layout.fillWidth: true
                    iconName: modelData.icon
                    title: modelData.title
                    supportingText:
                        PersonalizationConfig
                            .isMatugenTemplateEnabled(modelData.id)
                        ? qsTr("生成并更新 Matugen 配色")
                        : qsTr("已停止后续生成；现有配色文件会保留")

                    trailing: StyledSwitch {
                        enabled: !ThemeService.generating
                        checked: PersonalizationConfig
                            .isMatugenTemplateEnabled(modelData.id)
                        Accessible.name:
                            qsTr("启用 %1 Matugen 模板")
                                .arg(modelData.title)
                        onToggled:
                            ThemeService.setMatugenTemplateEnabled(
                                modelData.id, checked)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }
}
