#include "runtime/backlight_reading.h"
#include "runtime/keyboard_led_state.h"
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

class DeviceStateTest : public QObject {
    Q_OBJECT
  private slots:
    void authoritativeLeds()
    {
        KeyboardLedState state;
        input_event event{};
        event.type = EV_KEY;
        event.code = KEY_CAPSLOCK;
        event.value = 1;
        QVERIFY(!state.consume(event));
        QVERIFY(!state.caps);
        event.type = EV_LED;
        event.code = LED_CAPSL;
        state.consume(event);
        QVERIFY(state.caps);
        event.code = LED_NUML;
        state.consume(event);
        QVERIFY(state.num);
        event.value = 0;
        event.code = LED_CAPSL;
        state.consume(event);
        QVERIFY(!state.caps);
        QVERIFY(state.num);
    }
    void droppedFrame()
    {
        KeyboardLedState state{true, false, false};
        input_event event{};
        event.type = EV_SYN;
        event.code = SYN_DROPPED;
        QVERIFY(!state.consume(event));
        event.type = EV_LED;
        event.code = LED_CAPSL;
        event.value = 0;
        QVERIFY(!state.consume(event));
        QVERIFY(state.caps);
        event.type = EV_SYN;
        event.code = SYN_REPORT;
        QVERIFY(state.consume(event));
        // The snapshot replaces all bits, including clearing the dropped flag.
        state = {false, true, false};
        event.type = EV_LED;
        event.code = LED_NUML;
        state.consume(event);
        QVERIFY(!state.num);
    }
    void backlightSnapshot()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const auto write = [&dir](const QString &name, const QByteArray &value) {
            QFile file(dir.filePath(name));
            if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
                return false;
            return file.write(value) == value.size();
        };
        QVERIFY(!BacklightReading::read(dir.path()));
        QVERIFY(write("brightness", "80\n"));
        QVERIFY(write("actual_brightness", "25\n"));
        QVERIFY(write("max_brightness", "100\n"));
        auto reading = BacklightReading::read(dir.path());
        QVERIFY(reading);
        QCOMPARE(reading->fraction(), 0.25);
        QVERIFY(write("actual_brightness", "0\n"));
        QCOMPARE(BacklightReading::read(dir.path())->fraction(), 0.0);
        QVERIFY(write("actual_brightness", "invalid\n"));
        QVERIFY(!BacklightReading::read(dir.path()));
        QVERIFY(write("actual_brightness", "101\n"));
        QVERIFY(!BacklightReading::read(dir.path()));
        QVERIFY(write("actual_brightness", "50\n"));
        QVERIFY(write("max_brightness", "0\n"));
        QVERIFY(!BacklightReading::read(dir.path()));
        QVERIFY(QFile::remove(dir.filePath("actual_brightness")));
        QVERIFY(!BacklightReading::read(dir.path()));
    }
};
QTEST_GUILESS_MAIN(DeviceStateTest)
#include "device_state_test.moc"
