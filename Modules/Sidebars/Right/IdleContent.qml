import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

WidgetPanel {
    id: panelRoot

    title: "空闲管理"
    icon: "schedule"
    showBackButton: true
    backAction: () => WidgetState.qsView = "settings"

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "idle"
    property string expandedStage: ""
    property real pendingDimFraction: IdleService.dimFraction
    readonly property var timeoutPresetSeconds: [60, 120, 300, 600, 900, 1800, 3600, 7200]

    function formatTimeout(seconds) {
        const value = Math.max(0, Number(seconds || 0));
        if (value < 60)
            return Math.round(value) + " 秒";
        const minutes = value / 60;
        return (Math.abs(minutes - Math.round(minutes)) < 0.001
            ? Math.round(minutes)
            : minutes.toFixed(1)) + " 分钟";
    }

    function timeoutOptions(currentSeconds) {
        const values = timeoutPresetSeconds.slice();
        const current = Math.max(0, Number(currentSeconds || 0));
        if (current > 0 && values.indexOf(current) === -1)
            values.push(current);
        values.sort((a, b) => a - b);
        return values.map(value => ({
            "seconds": value,
            "label": panelRoot.formatTimeout(value)
        }));
    }

    function stageActive(name) {
        const stage = IdleService.stages.find(candidate => candidate.name === name);
        return stage ? !!stage.active : false;
    }

    function policySummary() {
        if (!IdleService.policyEnabled)
            return "已暂停";
        const enabledCount = IdleService.stages.filter(stage => stage.enabled).length;
        return enabledCount + " 项开启";
    }

    onIsActiveChanged: {
        if (!isActive)
            expandedStage = "";
    }

    Timer {
        id: dimFractionCommitTimer
        interval: 250
        repeat: false
        onTriggered: IdleService.setDimFraction(panelRoot.pendingDimFraction)
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.spacing.small

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: (!IdleService.policyReady || IdleService.busy) ? 4 : 0
            opacity: (!IdleService.policyReady || IdleService.busy) ? 1 : 0
            indeterminate: true
            Material.accent: Appearance.colors.colPrimary

            Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
            Behavior on opacity { ElementMoveAnimation {} }
        }

        InlineStatusBanner {
            Layout.fillWidth: true
            visible: IdleService.lastError.length > 0
            tone: "error"
            message: IdleService.lastError
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: idleContent.implicitHeight

            ColumnLayout {
                id: idleContent

                width: parent.width - Appearance.spacing.small
                spacing: Appearance.spacing.small

                SettingsSection {
                    Layout.fillWidth: true

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "coffee"
                        title: "保持唤醒"
                        highlighted: IdleService.inhibited

                        trailing: StyledSwitch {
                            scale: 0.78
                            checked: IdleService.inhibited
                            enabled: !IdleService.busy
                            Accessible.name: "保持唤醒"
                            onToggled: IdleService.setInhibited(checked)
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "schedule"
                        title: "自动空闲"
                        supportingText: panelRoot.policySummary()
                        highlighted: IdleService.policyEnabled

                        trailing: StyledSwitch {
                            scale: 0.78
                            checked: IdleService.policyEnabled
                            enabled: IdleService.policyReady
                            Accessible.name: "自动空闲"
                            onToggled: IdleService.setPolicyEnabled(checked)
                        }
                    }
                }

                SettingsSection {
                    Layout.fillWidth: true
                    title: "空闲动作"

                    StageEditor {
                        Layout.fillWidth: true
                        stageName: "dim"
                        stageTitle: "调暗屏幕"
                        stageIcon: "brightness_4"
                        showDimFraction: true
                    }

                    StageEditor {
                        Layout.fillWidth: true
                        stageName: "lock"
                        stageTitle: "锁定会话"
                        stageIcon: "lock"
                    }

                    StageEditor {
                        Layout.fillWidth: true
                        stageName: "displayOff"
                        stageTitle: "关闭显示器"
                        stageIcon: "display_settings"
                    }

                    StageEditor {
                        Layout.fillWidth: true
                        stageName: "suspend"
                        stageTitle: "挂起系统"
                        stageIcon: "mode_standby"
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Appearance.spacing.small
                }
            }
        }
    }

    component StageEditor: Item {
        id: stageEditor

        required property string stageName
        required property string stageTitle
        required property string stageIcon
        property bool showDimFraction: false
        readonly property bool expanded: panelRoot.expandedStage === stageName
        readonly property bool stageEnabled: !!IdleService[stageName + "Enabled"]
        readonly property real stageTimeout: Number(IdleService[stageName + "Timeout"] || 0)
        readonly property bool respectInhibitors: !!IdleService[stageName + "RespectInhibitors"]

        implicitHeight: stageLayout.implicitHeight

        ColumnLayout {
            id: stageLayout

            width: parent.width
            spacing: Appearance.spacing.xSmall

            SettingsRow {
                Layout.fillWidth: true
                iconName: stageEditor.stageIcon
                title: stageEditor.stageTitle
                supportingText: (stageEditor.stageEnabled
                    ? panelRoot.formatTimeout(stageEditor.stageTimeout)
                    : "已关闭")
                    + (panelRoot.stageActive(stageEditor.stageName) ? " · 已触发" : "")
                interactive: true
                highlighted: stageEditor.stageEnabled && IdleService.policyEnabled
                onClicked: panelRoot.expandedStage = stageEditor.expanded
                    ? ""
                    : stageEditor.stageName

                trailing: RowLayout {
                    spacing: Appearance.spacing.xSmall

                    MaterialSymbol {
                        text: "expand_more"
                        iconSize: 20
                        color: Appearance.colors.colOnLayer1
                        rotation: stageEditor.expanded ? 180 : 0

                        Behavior on rotation { ElementMoveAnimation {} }
                    }

                    StyledSwitch {
                        scale: 0.72
                        checked: stageEditor.stageEnabled
                        enabled: IdleService.policyReady
                        Accessible.name: stageEditor.stageTitle
                        onToggled: IdleService.configureStage(
                            stageEditor.stageName,
                            checked,
                            stageEditor.stageTimeout,
                            stageEditor.respectInhibitors
                        )
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: stageEditor.expanded
                    ? stageDetails.implicitHeight + Appearance.spacing.medium * 2
                    : 0
                opacity: stageEditor.expanded ? 1 : 0
                enabled: stageEditor.expanded
                clip: true
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                Behavior on Layout.preferredHeight { ElementMoveAnimation {} }
                Behavior on opacity { ElementMoveAnimation {} }

                ColumnLayout {
                    id: stageDetails

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Appearance.spacing.medium
                    }
                    spacing: Appearance.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Text {
                            Layout.fillWidth: true
                            text: "等待时间"
                            color: Appearance.colors.colOnLayer2
                            font.family: Sizes.fontFamily
                            font.pixelSize: 13
                        }

                        SearchSelectMenuField {
                            Layout.preferredWidth: 144
                            Layout.preferredHeight: 40
                            options: panelRoot.timeoutOptions(stageEditor.stageTimeout)
                            value: String(stageEditor.stageTimeout)
                            textRole: "label"
                            valueRole: "seconds"
                            maxVisibleItems: 5
                            popupBoundsItem: panelRoot
                            closeOnAccept: true
                            Accessible.name: stageEditor.stageTitle + "等待时间"
                            onAccepted: value => IdleService.configureStage(
                                stageEditor.stageName,
                                stageEditor.stageEnabled,
                                Number(value),
                                stageEditor.respectInhibitors
                            )
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: stageEditor.showDimFraction
                        spacing: Appearance.spacing.small

                        Text {
                            text: "调暗比例"
                            color: Appearance.colors.colOnLayer2
                            font.family: Sizes.fontFamily
                            font.pixelSize: 13
                        }

                        MaterialSplitSlider {
                            id: dimFractionSlider

                            Layout.fillWidth: true
                            Layout.minimumWidth: 148
                            configuration: MaterialSplitSlider.Configuration.XS
                            from: 0.1
                            to: 0.8
                            stepSize: 0.05
                            stopIndicatorValues: []
                            showTooltipOnHover: true
                            usePercentTooltip: false
                            tooltipContent: Math.round(value * 100) + "%"
                            Accessible.name: "屏幕调暗比例"

                            Binding {
                                target: dimFractionSlider
                                property: "value"
                                value: IdleService.dimFraction
                                when: !dimFractionSlider.pressed
                            }

                            onMoved: {
                                panelRoot.pendingDimFraction = value;
                                dimFractionCommitTimer.restart();
                            }
                        }
                    }

                    SettingsRow {
                        Layout.fillWidth: true
                        iconName: "coffee"
                        title: "保持唤醒时跳过"

                        trailing: StyledSwitch {
                            scale: 0.68
                            checked: stageEditor.respectInhibitors
                            enabled: IdleService.policyReady
                            Accessible.name: stageEditor.stageTitle + "遵循保持唤醒"
                            onToggled: IdleService.configureStage(
                                stageEditor.stageName,
                                stageEditor.stageEnabled,
                                stageEditor.stageTimeout,
                                checked
                            )
                        }
                    }
                }
            }
        }
    }
}
