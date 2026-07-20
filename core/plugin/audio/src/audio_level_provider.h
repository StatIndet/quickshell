#pragma once

#include "audio_level_collector.h"
#include "audio_visual_analyzer.h"

#include <QObject>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class AudioLevelProvider : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString sourceNodeName READ sourceNodeName WRITE setSourceNodeName
                   NOTIFY sourceNodeNameChanged)
    Q_PROPERTY(bool captureSink READ captureSink WRITE setCaptureSink
                   NOTIFY captureSinkChanged)
    Q_PROPERTY(bool available READ available NOTIFY valuesChanged)
    Q_PROPERTY(qint64 timestampMs READ timestampMs NOTIFY valuesChanged)
    Q_PROPERTY(double rms READ rms NOTIFY valuesChanged)
    Q_PROPERTY(double peak READ peak NOTIFY valuesChanged)
    Q_PROPERTY(double normalizedAmplitude READ normalizedAmplitude
                   NOTIFY valuesChanged)
    Q_PROPERTY(qint64 visualTimestampMs READ visualTimestampMs
                   NOTIFY visualSampleChanged)
    Q_PROPERTY(double visualAmplitude READ visualAmplitude
                   NOTIFY visualSampleChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY valuesChanged)

public:
    explicit AudioLevelProvider(QObject *parent = nullptr);
    ~AudioLevelProvider() override;

    bool active() const;
    void setActive(bool active);
    QString sourceNodeName() const;
    void setSourceNodeName(const QString &sourceNodeName);
    bool captureSink() const;
    void setCaptureSink(bool captureSink);

    bool available() const;
    qint64 timestampMs() const;
    double rms() const;
    double peak() const;
    double normalizedAmplitude() const;
    qint64 visualTimestampMs() const;
    double visualAmplitude() const;
    QString errorString() const;

signals:
    void activeChanged();
    void sourceNodeNameChanged();
    void captureSinkChanged();
    void valuesChanged();
    void visualSampleChanged();

private slots:
    void poll();
    void commitVisualSample();

private:
    bool m_active = false;
    QString m_sourceNodeName;
    bool m_captureSink = false;
    AudioLevelSnapshot m_snapshot;
    AudioLevelCollector m_collector;
    AudioVisualAnalyzer m_visualAnalyzer;
    QTimer m_timer;
    QTimer m_visualTimer;
    qint64 m_visualTimestampMs = 0;
    double m_visualAmplitude = 0.0;

    void restart();
};
