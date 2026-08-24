import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets.common
import qs.Modules.SystemCards

StyledFlickable {
    id: root

    property bool presentationActive: false

    onPresentationActiveChanged: SystemMonitorService.setConsumerModules("general-sidebar-settings", root.presentationActive ? ["gpu"] : [])
    Component.onCompleted: SystemMonitorService.setConsumerModules("general-sidebar-settings", root.presentationActive ? ["gpu"] : [])
    Component.onDestruction: SystemMonitorService.clearConsumer("general-sidebar-settings")

    readonly property bool cookieClockActive: UiPreferences.sidebarClockStyle === "cookie"
    readonly property var gpuOptions: buildGpuOptions()

    function gpuPciLabel(gpu) {
        const pciId = String(gpu.pciId || "");
        if (pciId !== "")
            return pciId;

        const id = String(gpu.id || "");
        return id.indexOf("pci:") === 0 ? id.slice(4) : id;
    }

    function buildGpuOptions() {
        const options = [{
            "value": "auto",
            "label": qsTr("自动")
        }];
        const names = ({
        });
        for (let index = 0; index < SystemMonitorService.gpus.length; index += 1) {
            const name = String(SystemMonitorService.gpus[index].name || qsTr("图形设备"));
            names[name] = Number(names[name] || 0) + 1;
        }
        for (let index = 0; index < SystemMonitorService.gpus.length; index += 1) {
            const gpu = SystemMonitorService.gpus[index];
            const id = String(gpu.id || "");
            if (id === "")
                continue;

            const name = String(gpu.name || qsTr("图形设备"));
            options.push({
                "value": id,
                "label": names[name] > 1 ? name + " · " + root.gpuPciLabel(gpu) : name
            });
        }
        const preferred = UiPreferences.systemMonitorGpuId;
        if (preferred !== "auto") {
            let found = false;
            for (let index = 1; index < options.length; index += 1) {
                if (options[index].value === preferred) {
                    found = true;
                    break;
                }
            }
            if (!found)
                options.push({
                "value": preferred,
                "label": preferred + " · " + qsTr("当前不可用")
            });

        }
        return options;
    }

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + Metrics.pageMargin * 2

    ColumnLayout {
        id: contentColumn

        width: Math.min(640, Math.max(0, root.width - Metrics.pageMargin * 2))
        x: Math.max(Metrics.pageMargin, (root.width - width) / 2)
        y: Metrics.pageMargin
        spacing: Metrics.spacingXL

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("桌面卡片")
            iconName: "dashboard_customize"

            SettingsRow {
                Layout.fillWidth: true
                iconName: "side_navigation"
                title: qsTr("保持侧边栏已加载")
                supportingText: qsTr("再次打开更快，但会增加内存占用")

                trailing: StyledSwitch {
                    checked: PersonalizationConfig.keepSidebarsLoaded
                    Accessible.name: qsTr("保持侧边栏已加载")
                    onToggled: PersonalizationConfig.setKeepSidebarsLoaded(checked)
                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("桌面卡片布局")
            iconName: "dashboard_customize"

            StyledButtonGroup {
                Layout.fillWidth: true
                model: [{
                    "value": "free",
                    "label": qsTr("自由拖拽")
                }, {
                    "value": "leastBusy",
                    "label": qsTr("最空旷处")
                }, {
                    "value": "mostBusy",
                    "label": qsTr("最密集处")
                }]
                currentValue: SystemCardService.globalDesktopLayoutMode
                onValueSelected: (value) => {
                    return SystemCardService.setGlobalDesktopLayoutMode(value);
                }
            }

            StyledButtonGroup {
                Layout.fillWidth: true
                model: [{
                    "value": "screenTopLeft",
                    "label": qsTr("左上")
                }, {
                    "value": "screenTopRight",
                    "label": qsTr("右上")
                }, {
                    "value": "screenBottomLeft",
                    "label": qsTr("左下")
                }, {
                    "value": "screenBottomRight",
                    "label": qsTr("右下")
                }, {
                    "value": "screenCenter",
                    "label": qsTr("居中")
                }]
                currentValue: SystemCardService.globalDesktopLayoutMode
                buttonMinWidth: 0
                onValueSelected: (value) => {
                    return SystemCardService.setGlobalDesktopLayoutMode(value);
                }
            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("时钟样式")
            iconName: "schedule"

            StyledButtonGroup {
                Layout.fillWidth: true
                model: [{
                    "value": "digital",
                    "label": qsTr("数字"),
                    "icon": "timer_10"
                }, {
                    "value": "cookie",
                    "label": qsTr("曲奇"),
                    "icon": "cookie"
                }]
                currentValue: UiPreferences.sidebarClockStyle
                buttonMinWidth: 120
                onValueSelected: (value) => {
                    return UiPreferences.setSidebarClockStyle(value);
                }
            }

            ColumnLayout {
                id: cookieSettings

                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacingM
                spacing: Metrics.spacingS
                enabled: root.cookieClockActive
                opacity: root.cookieClockActive ? 1 : 0.42

                SettingsRow {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    iconName: "add_triangle"
                    title: qsTr("边数")
                    supportingText: qsTr("0 或 1 为圆形，最多 40 边")

                    trailing: MaterialStepper {
                        enabled: root.cookieClockActive
                        value: UiPreferences.sidebarCookieSides
                        from: 0
                        to: 40
                        stepSize: 1
                        onValueModified: (value) => {
                            return UiPreferences.setSidebarCookieSides(value);
                        }
                    }

                }

                SettingsRow {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    iconName: "autoplay"
                    title: qsTr("持续旋转")
                    supportingText: qsTr("让曲奇轮廓匀速旋转")

                    trailing: StyledSwitch {
                        enabled: root.cookieClockActive
                        checked: UiPreferences.sidebarCookieConstantlyRotate
                        Accessible.name: qsTr("持续旋转")
                        onToggled: UiPreferences.setSidebarCookieConstantlyRotate(checked)
                    }

                }

                SettingsRow {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive && (UiPreferences.sidebarCookieDialStyle === "dots" || UiPreferences.sidebarCookieDialStyle === "full")
                    iconName: "brightness_7"
                    title: qsTr("时标")
                    supportingText: qsTr("仅适用于圆点或完整表盘")

                    trailing: StyledSwitch {
                        checked: UiPreferences.sidebarCookieHourMarks
                        Accessible.name: qsTr("时标")
                        onToggled: UiPreferences.setSidebarCookieHourMarks(checked)
                    }

                }

                SettingsRow {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive && UiPreferences.sidebarCookieDialStyle !== "numbers"
                    iconName: "timer_10"
                    title: qsTr("在中心显示数字")
                    supportingText: qsTr("数字表盘下不可用")

                    trailing: StyledSwitch {
                        checked: UiPreferences.sidebarCookieTimeIndicators
                        Accessible.name: qsTr("在中心显示数字")
                        onToggled: UiPreferences.setSidebarCookieTimeIndicators(checked)
                    }

                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("表盘样式")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [{
                        "value": "none",
                        "label": qsTr("无"),
                        "icon": "block"
                    }, {
                        "value": "dots",
                        "label": qsTr("圆点"),
                        "icon": "graph_6"
                    }, {
                        "value": "full",
                        "label": qsTr("完整"),
                        "icon": "history_toggle_off"
                    }, {
                        "value": "numbers",
                        "label": qsTr("数字"),
                        "icon": "counter_1"
                    }]
                    currentValue: UiPreferences.sidebarCookieDialStyle
                    horizontalPadding: Metrics.spacingXL
                    onValueSelected: (value) => {
                        return UiPreferences.setSidebarCookieDialStyle(value);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("时针")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [{
                        "value": "hide",
                        "label": qsTr("无"),
                        "icon": "block"
                    }, {
                        "value": "classic",
                        "label": qsTr("经典"),
                        "icon": "radio"
                    }, {
                        "value": "hollow",
                        "label": qsTr("镂空"),
                        "icon": "circle"
                    }, {
                        "value": "fill",
                        "label": qsTr("填充"),
                        "icon": "eraser_size_5"
                    }]
                    currentValue: UiPreferences.sidebarCookieHourHandStyle
                    horizontalPadding: Metrics.spacingXL
                    onValueSelected: (value) => {
                        return UiPreferences.setSidebarCookieHourHandStyle(value);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("分针")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [{
                        "value": "hide",
                        "label": qsTr("无"),
                        "icon": "block"
                    }, {
                        "value": "classic",
                        "label": qsTr("经典"),
                        "icon": "radio"
                    }, {
                        "value": "thin",
                        "label": qsTr("细"),
                        "icon": "line_end"
                    }, {
                        "value": "medium",
                        "label": qsTr("中等"),
                        "icon": "eraser_size_2"
                    }, {
                        "value": "bold",
                        "label": qsTr("粗"),
                        "icon": "eraser_size_4"
                    }]
                    currentValue: UiPreferences.sidebarCookieMinuteHandStyle
                    horizontalPadding: Metrics.spacingM * 2
                    contentSpacing: Metrics.spacingXS
                    onValueSelected: (value) => {
                        return UiPreferences.setSidebarCookieMinuteHandStyle(value);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("秒针")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [{
                        "value": "hide",
                        "label": qsTr("无"),
                        "icon": "block"
                    }, {
                        "value": "classic",
                        "label": qsTr("经典"),
                        "icon": "radio"
                    }, {
                        "value": "line",
                        "label": qsTr("线条"),
                        "icon": "line_end"
                    }, {
                        "value": "dot",
                        "label": qsTr("圆点"),
                        "icon": "adjust"
                    }]
                    currentValue: UiPreferences.sidebarCookieSecondHandStyle
                    horizontalPadding: Metrics.spacingXL
                    onValueSelected: (value) => {
                        return UiPreferences.setSidebarCookieSecondHandStyle(value);
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: Metrics.spacingXS
                    text: qsTr("日期样式")
                    color: Appearance.colors.colOnSurface
                    font.family: Typography.labelLarge.family
                    font.pixelSize: Typography.labelLarge.pixelSize
                    font.weight: Typography.labelLarge.weight
                }

                StyledButtonGroup {
                    Layout.fillWidth: true
                    enabled: root.cookieClockActive
                    model: [{
                        "value": "hide",
                        "label": qsTr("无"),
                        "icon": "block"
                    }, {
                        "value": "bubble",
                        "label": qsTr("气泡"),
                        "icon": "bubble_chart"
                    }, {
                        "value": "border",
                        "label": qsTr("边缘"),
                        "icon": "rotate_right"
                    }, {
                        "value": "rect",
                        "label": qsTr("矩形"),
                        "icon": "rectangle"
                    }]
                    currentValue: UiPreferences.sidebarCookieDateStyle
                    horizontalPadding: Metrics.spacingXL
                    onValueSelected: (value) => {
                        return UiPreferences.setSidebarCookieDateStyle(value);
                    }
                }

            }

        }

        SettingsSection {
            Layout.fillWidth: true
            flat: true
            title: qsTr("系统卡片")
            iconName: "widgets"

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Metrics.spacingS
                rowSpacing: Metrics.spacingS

                Repeater {
                    model: SystemCardService.cardIds

                    delegate: SettingsRow {
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        iconName: SystemCardService.cardIcon(modelData)
                        title: SystemCardService.cardName(modelData)
                        supportingText: {
                            const cards = SystemCardService.cards;
                            const state = cards ? cards[modelData] : null;
                            return state && state.container === "desktop" ? qsTr("桌面") : qsTr("侧边栏");
                        }

                        trailing: StyledSwitch {
                            checked: {
                                const cards = SystemCardService.cards;
                                const state = cards ? cards[modelData] : null;
                                return state ? state.enabled : true;
                            }
                            Accessible.name: SystemCardService.cardName(modelData)
                            onToggled: SystemCardService.setCardEnabled(modelData, checked)
                        }

                    }

                }

            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "developer_board"
                title: qsTr("GPU")
                supportingText: qsTr("选择 GPU 卡片显示的图形设备")

                trailing: SearchSelectMenuField {
                    Layout.preferredWidth: 220
                    options: root.gpuOptions
                    value: UiPreferences.systemMonitorGpuId
                    placeholder: qsTr("自动")
                    closeOnAccept: true
                    onAccepted: (value) => {
                        return UiPreferences.setSystemMonitorGpuId(value);
                    }
                }

            }

            SettingsRow {
                Layout.fillWidth: true
                iconName: "speed"
                title: qsTr("系统监测快照间隔")
                supportingText: qsTr("较短的间隔会提高实时性，同时增加资源占用")

                trailing: MaterialFilledTextField {
                    id: intervalField

                    Layout.preferredWidth: 150
                    text: String(UiPreferences.systemMonitorIntervalMs)
                    error: text.length === 0 || !acceptableInput
                    horizontalAlignment: TextInput.AlignRight
                    inputMethodHints: Qt.ImhDigitsOnly
                    trailingContentWidth: 40
                    onEditingFinished: {
                        UiPreferences.setSystemMonitorIntervalMs(text);
                        text = String(UiPreferences.systemMonitorIntervalMs);
                    }

                    validator: IntValidator {
                        bottom: 100
                        top: 60000
                    }

                    trailingContent: Component {
                        Text {
                            anchors.fill: parent
                            text: qsTr("ms")
                            color: Appearance.colors.colOnSurfaceVariant
                            font.family: Typography.bodyMedium.family
                            font.pixelSize: Typography.bodyMedium.pixelSize
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }

                }

            }

        }

    }

}
