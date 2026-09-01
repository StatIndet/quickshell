import QtQuick
import qs.Common
import qs.Services
import "../../../Common/functions/DateFormat.js" as DateFormat

Item {
    id: root

    property var player
    property string edge: "top"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool hideDate: PersonalizationConfig.keystoneHideDate
    property string dateStr: ""
    property var verticalDateParts: []
    readonly property string clockFamily: Fonts.systemClock
    readonly property var horizontalClockAxes: root.safeHorizontalClockAxes(PersonalizationConfig.horizontalClockAxes)
    readonly property var verticalClockAxes: Fonts.familyAvailable(Fonts.systemClock) ? ({
        "wght": 900,
        "wdth": 85,
        "opsz": 24,
        "GRAD": 75,
        "ROND": 25,
        "slnt": 0
    }) : ({
    })
    readonly property real horizontalFontSize: root.boundedNumber(PersonalizationConfig.horizontalClockFontSize, 22, 16, 28)
    // 【核心变化1】把时间拆分成 4 个独立的整数型变量，绑定动画目标值
    property int h0: 0
    property int h1: 0
    property int m0: 0
    property int m1: 0
    property string periodLead: "A"

    function boundedNumber(value, fallback, minimum, maximum) {
        const numberValue = Number(value);
        if (!isFinite(numberValue))
            return fallback;

        return Math.max(minimum, Math.min(maximum, numberValue));
    }

    function safeHorizontalClockAxes(source) {
        const defaults = PersonalizationConfig.horizontalClockAxisDefaults;
        const minimums = PersonalizationConfig.horizontalClockAxisMinimums;
        const maximums = PersonalizationConfig.horizontalClockAxisMaximums;
        const result = {
        };
        const names = ["wght", "wdth", "opsz", "GRAD", "ROND", "slnt"];
        const values = source && typeof source === "object" ? source : {
        };
        for (let i = 0; i < names.length; i += 1) {
            const name = names[i];
            result[name] = root.boundedNumber(values[name], defaults[name], minimums[name], maximums[name]);
        }
        return result;
    }

    function horizontalDigitValue(id, field) {
        const defaults = PersonalizationConfig.horizontalClockDigitDefaults;
        const configured = PersonalizationConfig.horizontalClockDigits;
        const fallback = defaults[id] || {
        };
        const candidate = configured && configured[id] ? configured[id] : {
        };
        const limits = field === "x" ? [-8, 8] : field === "y" ? [-6, 6] : [-12, 12];
        return root.boundedNumber(candidate[field], fallback[field] || 0, limits[0], limits[1]);
    }

    function horizontalDigitColor(id) {
        const defaults = PersonalizationConfig.horizontalClockDigitDefaults;
        const configured = PersonalizationConfig.horizontalClockDigits;
        const fallback = defaults[id] || {
        };
        const candidate = configured && configured[id] ? configured[id] : fallback;
        if (candidate.colorRole === "custom" && /^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(String(candidate.customColor || "")))
            return candidate.customColor;

        return candidate.colorRole === "inversePrimary" ? Appearance.colors.colInversePrimary : Appearance.colors.colPrimary;
    }

    function formatDate(date) {
        if (DateFormat.isChinese(I18nService.language))
            return String(date.getMonth() + 1).padStart(2, "0") + "月" + String(date.getDate()).padStart(2, "0") + "日" + DateFormat.shortWeekdays(I18nService.language)[date.getDay()];

        return DateFormat.compactDate(date, I18nService.language, Qt.locale(I18nService.language), "ddd dd MMM");
    }

    // Side Keystone uses short horizontal rows: up to three Latin letters,
    // two digits, or one Han character per row. This keeps every glyph
    // upright while preserving the existing narrow pill geometry.
    function sideDateParts(date) {
        if (DateFormat.isChinese(I18nService.language)) {
            const weekday = DateFormat.shortWeekdays(I18nService.language)[date.getDay()];
            return [String(date.getMonth() + 1).padStart(2, "0"), "月", String(date.getDate()).padStart(2, "0"), "日", weekday.slice(0, 1), weekday.slice(1, 2)];
        }
        const locale = Qt.locale(I18nService.language);
        return [date.toLocaleDateString(locale, "ddd").slice(0, 3), String(date.getDate()).padStart(2, "0"), date.toLocaleDateString(locale, "MMM").slice(0, 3)];
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let d = new Date();
            root.dateStr = root.formatDate(d);
            root.verticalDateParts = root.sideDateParts(d);
            const hour24 = d.getHours();
            const displayHour = UiPreferences.useTwelveHourClock ? ((hour24 + 11) % 12) + 1 : hour24;
            let hStr = displayHour.toString().padStart(2, '0');
            let mStr = d.getMinutes().toString().padStart(2, '0');
            root.periodLead = hour24 >= 12 ? "P" : "A";
            // 转换为整数，驱动数字翻页动画
            root.h0 = parseInt(hStr[0]);
            root.h1 = parseInt(hStr[1]);
            root.m0 = parseInt(mStr[0]);
            root.m1 = parseInt(mStr[1]);
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.hideDate ? 0 : 10
        visible: !root.vertical

        // --- 左侧日期部分 ---
        Text {
            text: root.dateStr
            visible: !root.hideDate
            width: root.hideDate ? 0 : implicitWidth
            color: Appearance.colors.colPrimary
            font.family: Fonts.ui
            font.pixelSize: 13
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            visible: !root.hideDate
            width: root.hideDate ? 0 : 8
            height: root.horizontalFontSize + 2
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 2
                height: 14
                radius: width / 2
                color: Appearance.colors.colOutlineVariant
            }

        }

        // --- 右侧 Standby 滚动时钟 ---
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            // 小时部分
            Row {
                spacing: -1

                RollingDigit {
                    digitId: "h0"
                    targetDigit: root.h0
                    digitColor: root.horizontalDigitColor("h0")
                }

                RollingDigit {
                    digitId: "h1"
                    targetDigit: root.h1
                    digitColor: root.horizontalDigitColor("h1")
                }

            }

            // 冒号
            Column {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: Appearance.colors.colOutlineVariant
                }

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: Appearance.colors.colOutlineVariant
                }

            }

            // 分钟部分
            Row {
                spacing: 1

                RollingDigit {
                    digitId: "m0"
                    targetDigit: root.m0
                    digitColor: root.horizontalDigitColor("m0")
                }

                RollingDigit {
                    digitId: "m1"
                    targetDigit: root.m1
                    digitColor: root.horizontalDigitColor("m1")
                }

            }

            Row {
                visible: UiPreferences.useTwelveHourClock
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                ClockLetter {
                    letterId: "ap"
                    value: root.periodLead
                }

                ClockLetter {
                    letterId: "periodM"
                    value: "M"
                }

            }

        }

    }

    Column {
        id: verticalClockLayout

        anchors.centerIn: parent
        spacing: 4
        visible: root.vertical

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            visible: !root.hideDate

            Repeater {
                model: root.verticalDateParts

                Text {
                    required property string modelData

                    width: 28
                    height: 15
                    text: modelData
                    color: Appearance.colors.colPrimary
                    font.family: Fonts.ui
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

            }

        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 28
            height: 10
            visible: !root.hideDate

            Rectangle {
                anchors.centerIn: parent
                width: 12
                height: 2
                radius: height / 2
                color: Appearance.colors.colOutlineVariant
            }

        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -1

            Text {
                width: 28
                height: 20
                text: String(root.h0) + String(root.h1)
                color: Appearance.colors.colPrimary
                font.family: root.clockFamily
                font.pixelSize: 20
                font.weight: Font.Black
                font.letterSpacing: -1.5
                font.variableAxes: root.verticalClockAxes
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Item {
                width: 28
                height: 10

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: 2

                        Rectangle {
                            required property int index

                            width: 3
                            height: 3
                            radius: width / 2
                            color: Appearance.colors.colOutlineVariant
                        }

                    }

                }

            }

            Text {
                width: 28
                height: 20
                text: String(root.m0) + String(root.m1)
                color: Appearance.colors.colPrimary
                font.family: root.clockFamily
                font.pixelSize: 20
                font.weight: Font.Black
                font.letterSpacing: -1.5
                font.variableAxes: root.verticalClockAxes
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                visible: UiPreferences.useTwelveHourClock
                width: 28
                height: 15
                text: root.periodLead + "M"
                color: Appearance.colors.colPrimary
                font.family: root.clockFamily
                font.pixelSize: 14
                font.weight: Font.Black
                font.letterSpacing: -2
                font.variableAxes: root.verticalClockAxes
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

        }

    }

    // ============================================================
    // 【核心变化2】定义可复用的滚动数字组件 (Qt 6 内联组件)
    // ============================================================
    component RollingDigit: Item {
        id: digitContainer

        property string digitId: "h0"
        property int targetDigit: 0
        property color digitColor: "white"
        readonly property real digitXOffset: root.horizontalDigitValue(digitId, "x")
        readonly property real digitYOffset: root.horizontalDigitValue(digitId, "y")
        readonly property real digitRotation: root.horizontalDigitValue(digitId, "rotation")
        readonly property real lineHeight: Math.max(18, root.horizontalFontSize + 2)

        width: digitText.implicitWidth
        height: lineHeight
        clip: true
        anchors.verticalCenter: parent.verticalCenter
        transform: [
            Translate {
                x: digitContainer.digitXOffset
                y: digitContainer.digitYOffset
            },
            Rotation {
                angle: digitContainer.digitRotation
                origin.x: digitContainer.width / 2
                origin.y: digitContainer.height / 2
            }
        ]

        Text {
            id: digitText

            // 一次性渲染 0-9，通过改变 y 坐标来实现滚动
            text: "0\n1\n2\n3\n4\n5\n6\n7\n8\n9"
            color: digitContainer.digitColor
            font.family: root.clockFamily
            font.variableAxes: root.horizontalClockAxes
            font.pixelSize: root.horizontalFontSize
            lineHeight: digitContainer.lineHeight
            lineHeightMode: Text.FixedHeight
            // 计算 y 轴偏移量
            y: -digitContainer.targetDigit * digitContainer.lineHeight

            // 弹性动画，带来带有惯性回弹的机械翻页感
            Behavior on y {
                SpringAnimation {
                    spring: 3.5
                    damping: 0.75
                    mass: 1
                }

            }

        }

    }

    component ClockLetter: Item {
        id: letterContainer

        required property string letterId
        required property string value
        readonly property real letterXOffset: root.horizontalDigitValue(letterId, "x")
        readonly property real letterYOffset: root.horizontalDigitValue(letterId, "y")
        readonly property real letterRotation: root.horizontalDigitValue(letterId, "rotation")
        readonly property real lineHeight: Math.max(18, root.horizontalFontSize + 2)

        width: letterText.implicitWidth
        height: lineHeight
        anchors.verticalCenter: parent.verticalCenter
        transform: [
            Translate {
                x: letterContainer.letterXOffset
                y: letterContainer.letterYOffset
            },
            Rotation {
                angle: letterContainer.letterRotation
                origin.x: letterContainer.width / 2
                origin.y: letterContainer.height / 2
            }
        ]

        Text {
            id: letterText

            text: letterContainer.value
            color: root.horizontalDigitColor(letterContainer.letterId)
            font.family: root.clockFamily
            font.variableAxes: root.horizontalClockAxes
            font.pixelSize: root.horizontalFontSize
            lineHeight: letterContainer.lineHeight
            lineHeightMode: Text.FixedHeight
        }

    }

}
