import QtQuick
import qs.Common

QtObject {
    id: root

    property real targetValue: NaN
    property bool enabled: false
    property bool active: true
    property int initialDuration: 1000
    property int updateDuration: 500

    readonly property bool valid: !isNaN(targetValue) && isFinite(targetValue)
    property real currentValue: valid && !enabled ? targetValue : (valid ? 0 : NaN)
    property bool hasAnimated: false

    property NumberAnimation valueAnimation: NumberAnimation {
        target: root
        property: "currentValue"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Animations.curves.emphasizedDecel
    }

    function animateToTarget(duration) {
        if (!valid)
            return

        valueAnimation.stop()
        valueAnimation.from = isNaN(currentValue) ? 0 : currentValue
        valueAnimation.to = targetValue
        valueAnimation.duration = duration
        valueAnimation.restart()
    }

    function syncValue() {
        if (!valid) {
            valueAnimation.stop()
            currentValue = NaN
            return
        }

        if (!enabled) {
            valueAnimation.stop()
            currentValue = targetValue
            hasAnimated = false
            return
        }

        if (!active) {
            // Inactive means the card is offscreen or the sidebar is moving.
            // Freeze the last rendered value instead of rewinding to zero;
            // reopening can continue toward the current target.
            valueAnimation.stop()
            return
        }

        if (!hasAnimated) {
            currentValue = 0
            hasAnimated = true
            animateToTarget(initialDuration)
        } else {
            animateToTarget(updateDuration)
        }
    }

    onTargetValueChanged: syncValue()
    onEnabledChanged: syncValue()
    onActiveChanged: syncValue()
    Component.onCompleted: syncValue()
}
