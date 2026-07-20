#include "audio_level_provider.h"

#include <QDateTime>

AudioLevelProvider::AudioLevelProvider(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(33);
    m_timer.setTimerType(Qt::PreciseTimer);
    connect(&m_timer, &QTimer::timeout, this, &AudioLevelProvider::poll);
    m_visualTimer.setInterval(160);
    m_visualTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_visualTimer, &QTimer::timeout,
            this, &AudioLevelProvider::commitVisualSample);
}

AudioLevelProvider::~AudioLevelProvider()
{
    m_timer.stop();
    m_visualTimer.stop();
    m_collector.stop();
}

bool AudioLevelProvider::active() const
{
    return m_active;
}

void AudioLevelProvider::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    emit activeChanged();
    restart();
}

QString AudioLevelProvider::sourceNodeName() const
{
    return m_sourceNodeName;
}

void AudioLevelProvider::setSourceNodeName(const QString &sourceNodeName)
{
    if (m_sourceNodeName == sourceNodeName)
        return;
    m_sourceNodeName = sourceNodeName;
    emit sourceNodeNameChanged();
    restart();
}

bool AudioLevelProvider::captureSink() const
{
    return m_captureSink;
}

void AudioLevelProvider::setCaptureSink(bool captureSink)
{
    if (m_captureSink == captureSink)
        return;
    m_captureSink = captureSink;
    emit captureSinkChanged();
    restart();
}

bool AudioLevelProvider::available() const
{
    return m_snapshot.available;
}

qint64 AudioLevelProvider::timestampMs() const
{
    return m_snapshot.timestampMs;
}

double AudioLevelProvider::rms() const
{
    return m_snapshot.rms;
}

double AudioLevelProvider::peak() const
{
    return m_snapshot.peak;
}

double AudioLevelProvider::normalizedAmplitude() const
{
    return m_snapshot.normalizedAmplitude;
}

qint64 AudioLevelProvider::visualTimestampMs() const
{
    return m_visualTimestampMs;
}

double AudioLevelProvider::visualAmplitude() const
{
    return m_visualAmplitude;
}

QString AudioLevelProvider::errorString() const
{
    return QString::fromStdString(m_snapshot.error);
}

void AudioLevelProvider::poll()
{
    const AudioLevelSnapshot next = m_collector.snapshot();
    if (next.timestampMs == m_snapshot.timestampMs
        && next.available == m_snapshot.available
        && next.error == m_snapshot.error) {
        return;
    }
    m_snapshot = next;
    if (next.available)
        m_visualAnalyzer.addSample(next.rms, next.peak);
    emit valuesChanged();
}

void AudioLevelProvider::commitVisualSample()
{
    m_visualTimestampMs = QDateTime::currentMSecsSinceEpoch();
    m_visualAmplitude = m_visualAnalyzer.commit(m_visualTimestampMs);
    emit visualSampleChanged();
}

void AudioLevelProvider::restart()
{
    m_timer.stop();
    m_visualTimer.stop();
    m_collector.stop();
    m_snapshot = {};
    m_visualAnalyzer.reset(
        m_captureSink ? AudioVisualSource::System
                      : AudioVisualSource::Microphone);
    m_visualTimestampMs = 0;
    m_visualAmplitude = 0.0;
    emit valuesChanged();
    emit visualSampleChanged();

    if (!m_active || m_sourceNodeName.isEmpty())
        return;
    m_collector.start(m_sourceNodeName.toStdString(), m_captureSink);
    m_timer.start();
    m_visualTimer.start();
    poll();
}
