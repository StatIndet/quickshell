#pragma once

#include "recording/recording_types.h"

#include <QJsonObject>
#include <QString>

namespace Clavis::Recording {

enum class AudioRecordingState {
    Idle,
    Starting,
    Recording,
    Stopping,
    Finalizing,
    Error,
};

enum class AudioSourceType {
    Microphone,
    System,
};

struct AudioSourceInfo {
    AudioSourceType type = AudioSourceType::Microphone;
    QString name;
    QString nodeName;
    QString description;
    bool captureSink = false;

    bool isValid() const;
    QJsonObject toJson() const;
    static bool fromJson(const QJsonObject &object, AudioSourceInfo *source);
};

struct AudioRecordingSession {
    int schemaVersion = SchemaVersion;
    QString sessionId;
    AudioRecordingState state = AudioRecordingState::Idle;
    qint64 pid = 0;
    quint64 processStartTicks = 0;
    qint64 processStartedAtMs = 0;
    qint64 coordinatorPid = 0;
    quint64 coordinatorStartTicks = 0;
    qint64 startedAtMs = 0;
    qint64 completedAtMs = 0;
    qint64 updatedAtMs = 0;
    AudioSourceInfo source;
    QString temporaryPath;
    QString outputPath;
    RecordingError error;

    bool isActive() const;
    QJsonObject toJson() const;
    static bool fromJson(const QJsonObject &object, AudioRecordingSession *session,
                         RecordingError *error = nullptr);
};

struct AudioStartOptions {
    AudioSourceType source = AudioSourceType::Microphone;
    QString outputDirectory;
};

struct AudioOperationResult {
    bool ok = false;
    int exitCode = GeneralFailure;
    AudioRecordingSession session;
    RecordingError error;

    QJsonObject toJson(const QString &command) const;
};

QString audioRecordingStateName(AudioRecordingState state);
bool parseAudioRecordingState(const QString &name, AudioRecordingState *state);
QString audioSourceTypeName(AudioSourceType type);
bool parseAudioSourceType(const QString &name, AudioSourceType *type);
AudioRecordingSession idleAudioSession();

} // namespace Clavis::Recording
