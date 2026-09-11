import QtQuick
import QtTest
import "../../Common/functions/DisplaySchedule.js" as Schedule
import "../../Common/functions/DisplayConfiguration.js" as Config

TestCase {
    name: "DisplayMath"
    function test_schedule() {
        const p = Schedule.normalize({
                                         nightEnabled: true,
                                         mode: "time",
                                         start: 1200,
                                         end: 420,
                                         transition: 0
                                     });
        compare(Schedule.evaluate(p, new Date(2026, 8, 11, 23, 0).getTime()).temperature, 4000);
        compare(Schedule.evaluate(p, new Date(2026, 8, 12, 3, 0).getTime()).temperature, 4000);
        compare(Schedule.evaluate(p, new Date(2026, 8, 12, 7, 0).getTime()).temperature, 6500);
        p.start = 120;
        p.end = 600;
        compare(Schedule.evaluate(p, new Date(2026, 8, 12, 1, 0).getTime()).temperature, 6500);
        compare(Schedule.evaluate(p, new Date(2026, 8, 12, 3, 0).getTime()).temperature, 4000);
        p.transition = 60;
        compare(Schedule.evaluate(p, new Date(2026, 8, 12, 2, 30).getTime()).temperature, 5250);
        p.nightEnabled = false;
        p.gamma = 1.5;
        compare(Schedule.evaluate(p, Date.now()).temperature, 6500);
        compare(Schedule.normalize(p).gamma, 1.5);
    }
    function test_location() {
        const p = Schedule.normalize({
                                         nightEnabled: true,
                                         mode: "location",
                                         latitude: 0,
                                         longitude: 0
                                     });
        compare(p.latitude, 0);
        compare(p.longitude, 0);
        const result = Schedule.evaluate(p, new Date(2026, 2, 20, 12).getTime());
        compare(result.condition, "normal");
        verify(result.sunset > result.sunrise);
        verify(result.sunset - result.sunrise > 11 * 3600000);
        p.latitude = 89;
        compare(Schedule.evaluate(p, new Date(2026, 5, 21, 12).getTime()).condition, "polar-day");
        compare(Schedule.evaluate(p, new Date(2026, 11, 21, 12).getTime()).condition, "polar-night");
        p.latitude = null;
        compare(Schedule.evaluate(p, Date.now()).condition, "missing-location");
    }
    function test_identityAndGeometry() {
        const a = {
            name: "DP-1",
            make: "A",
            model: "B",
            serial: "S"
        };
        const b = {
            name: "DP-2",
            make: "A",
            model: "B",
            serial: "S"
        };
        verify(Config.stableKey(a, [a, b]) !== Config.stableKey(b, [a, b]));
        compare(Config.stableKey(a, [a]), Config.stableKey(b, [b]));
        verify(Config.stableKey(a, [a], [Config.identity(a)]).indexOf("connector:") === 0);
        a.serial = "";
        b.serial = "";
        verify(Config.stableKey(a, [a]) !== Config.stableKey(b, [b]));
        compare(Config.modeString({
                                      width: 1920,
                                      height: 1080,
                                      refreshMilliHz: 59951
                                  }), "1920x1080@59.951");
        const row = {
            settings: {
                mode: "1920x1080@59.951",
                scale: 1.3333,
                transform: "90"
            },
            live: null
        };
        compare(Config.size(row).width, 810);
        compare(Config.size(row).height, 1440);
    }
}
