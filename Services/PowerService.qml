pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool ready: device !== null && device.ready
    readonly property bool present: ready && device.isPresent
    readonly property bool onBattery: UPower.onBattery
    readonly property real percentage: present ? device.percentage : NaN
    readonly property int state: ready ? device.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool discharging: state === UPowerDeviceState.Discharging
    readonly property bool powerConnected: !onBattery
    readonly property real timeToEmpty: present && device.timeToEmpty > 0 ? device.timeToEmpty : NaN
    readonly property real timeToFull: present && device.timeToFull > 0 ? device.timeToFull : NaN
    readonly property real changeRate: present && isFinite(device.changeRate) ? device.changeRate : NaN
    readonly property real healthPercentage: present ? root.physicalBatteryHealth() : NaN

    function physicalBatteryHealth() {
        if (root.device && root.device.healthSupported && isFinite(root.device.healthPercentage) && root.device.healthPercentage > 0)
            return root.device.healthPercentage;

        const devices = UPower.devices.values;
        let total = 0;
        let count = 0;
        for (let index = 0; index < devices.length; index += 1) {
            const candidate = devices[index];
            if (!candidate || !candidate.ready || !candidate.isPresent || !candidate.healthSupported || !isFinite(candidate.healthPercentage) || candidate.healthPercentage <= 0)
                continue;

            const physicalBattery = candidate.isLaptopBattery || (candidate.powerSupply && candidate.type === UPowerDeviceType.Battery);
            if (!physicalBattery)
                continue;

            total += candidate.healthPercentage;
            count += 1;
        }
        return count > 0 ? total / count : NaN;
    }

}
