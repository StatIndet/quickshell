#include "runtime/backlight_reading.h"
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

class DeviceStateTest : public QObject {
    Q_OBJECT
  private slots:
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
