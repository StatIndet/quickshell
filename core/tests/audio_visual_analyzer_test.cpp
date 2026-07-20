#include "audio_visual_analyzer.h"

#include <QTest>

class AudioVisualAnalyzerTest : public QObject {
    Q_OBJECT

private slots:
    void appliesMicrophoneNoiseGate();
    void microphoneSilenceHasNoReleaseTail();
    void preservesSystemTransients();
    void usesStableSystemScale();
};

void AudioVisualAnalyzerTest::appliesMicrophoneNoiseGate()
{
    AudioVisualAnalyzer analyzer(AudioVisualSource::Microphone);
    for (int index = 0; index < 5; ++index)
        analyzer.addSample(0.001, 0.002);
    QCOMPARE(analyzer.commit(160), 0.0);

    for (int index = 0; index < 5; ++index)
        analyzer.addSample(0.03, 0.10);
    QVERIFY(analyzer.commit(320) > 0.2);
}

void AudioVisualAnalyzerTest::microphoneSilenceHasNoReleaseTail()
{
    AudioVisualAnalyzer analyzer(AudioVisualSource::Microphone);
    for (int index = 0; index < 5; ++index)
        analyzer.addSample(0.04, 0.12);
    QVERIFY(analyzer.commit(160) > 0.0);

    for (int index = 0; index < 5; ++index)
        analyzer.addSample(0.0, 0.0);
    QCOMPARE(analyzer.commit(320), 0.0);
}

void AudioVisualAnalyzerTest::preservesSystemTransients()
{
    AudioVisualAnalyzer steady(AudioVisualSource::System);
    for (int index = 0; index < 5; ++index)
        steady.addSample(0.04, 0.08);
    const double steadyLevel = steady.commit(160);

    AudioVisualAnalyzer transient(AudioVisualSource::System);
    for (int index = 0; index < 4; ++index)
        transient.addSample(0.04, 0.08);
    transient.addSample(0.15, 0.80);
    const double transientLevel = transient.commit(160);
    QVERIFY(transientLevel > steadyLevel + 0.08);
}

void AudioVisualAnalyzerTest::usesStableSystemScale()
{
    AudioVisualAnalyzer analyzer(AudioVisualSource::System);
    for (int sample = 0; sample < 5; ++sample)
        analyzer.addSample(0.07, 0.18);
    const double first = analyzer.commit(160);

    for (int window = 0; window < 20; ++window) {
        for (int sample = 0; sample < 5; ++sample)
            analyzer.addSample(0.18, 0.72);
        analyzer.commit(320 + window * 160);
    }

    for (int sample = 0; sample < 5; ++sample)
        analyzer.addSample(0.07, 0.18);
    const double afterLoudHistory = analyzer.commit(3520);
    QCOMPARE(afterLoudHistory, first);
}

QTEST_MAIN(AudioVisualAnalyzerTest)
#include "audio_visual_analyzer_test.moc"
