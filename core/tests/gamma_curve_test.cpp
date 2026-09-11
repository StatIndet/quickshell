#include "gamma_curve.h"
#include <QtTest>
#include <limits>
class GammaCurveTest : public QObject {
    Q_OBJECT
  private slots:
    void identity()
    {
        const auto ramp = GammaCurve::generate(256, {});
        QCOMPARE(ramp.size(), 768);
        for (int i = 0; i < 256; ++i)
            for (int channel = 0; channel < 3; ++channel)
                QCOMPARE(ramp[channel * 256 + i], quint16(i * 257));
        QVERIFY(GammaCurve::Parameters{}.neutral());
    }
    void invalid()
    {
        QVERIFY(GammaCurve::generate(0, {}).isEmpty());
        QVERIFY(GammaCurve::generate(1, {}).isEmpty());
        QVERIFY(GammaCurve::generate(65537, {}).isEmpty());
        for (double invalid : {0.0, -1.0, 3.0, std::numeric_limits<double>::infinity(),
                               std::numeric_limits<double>::quiet_NaN()}) {
            GammaCurve::Parameters p;
            p.gamma = invalid;
            QVERIFY(GammaCurve::generate(256, p).isEmpty());
        }
    }
    void channelsAndClipping()
    {
        GammaCurve::Parameters p;
        p.temperature = 4000;
        const auto warm = GammaCurve::generate(256, p);
        QVERIFY(warm[255] > warm[511]);
        QVERIFY(warm[511] > warm[767]);
        p.temperature = 1000;
        const auto low = GammaCurve::generate(256, p);
        p.temperature = 1600;
        QVERIFY(low != GammaCurve::generate(256, p));
        p.temperature = 6500;
        p.contrast = 2;
        const auto contrast = GammaCurve::generate(256, p);
        QCOMPARE(contrast[50], quint16(0));
        QCOMPARE(contrast[210], quint16(65535));
        p.contrast = 1;
        p.dimming = 0.5;
        QCOMPARE(GammaCurve::generate(256, p)[255], quint16(32768));
        QVERIFY(!p.neutral());
        for (int temperature : {1000, 1667, 2222, 4000, 6499, 6500, 6501, 10000}) {
            p.temperature = temperature;
            const auto ramp = GammaCurve::generate(1024, p);
            QCOMPARE(ramp.size(), 3072);
            for (int channel = 0; channel < 3; ++channel)
                for (int i = 1; i < 1024; ++i)
                    QVERIFY(ramp[channel * 1024 + i] >= ramp[channel * 1024 + i - 1]);
        }
    }
};
QTEST_GUILESS_MAIN(GammaCurveTest)
#include "gamma_curve_test.moc"
