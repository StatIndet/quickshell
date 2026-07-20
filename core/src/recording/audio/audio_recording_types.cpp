#include "audio_recording_types.h"

#include <QDateTime>
#include <QJsonValue>

namespace Clavis::Recording {

bool AudioSourceInfo::isValid() const
{
    return !name.isEmpty() && !nodeName.isEmpty();
}

QJsonObject AudioSourceInfo::toJson() const
{
    return {
        {QStringLiteral("type"), audioSourceTypeName(type)},
        {QStringLiteral("name"), name},
        {QStringLiteral("nodeName"), nodeName},
        {QStringLiteral("description"), description},
        {QStringLiteral("captureSink"), captureSink},
    };
}

bool AudioSourceInfo::fromJson(const QJsonObject &object, AudioSourceInfo *source)
{
    if (!source)
        return false;

    AudioSourceType type;
    if (!parseAudioSourceType(object.value(QStringLiteral("type")).toString(), &type))
        return false;

    AudioSourceInfo parsed;
    parsed.type = type;
    parsed.name = object.value(QStringLiteral("name")).toString();
    parsed.nodeName = object.value(QStringLiteral("nodeName")).toString();
    parsed.description = object.value(QStringLiteral("description")).toString();
    parsed.captureSink = object.value(QStringLiteral("captureSink")).toBool(false);
    if (!parsed.isValid())
        return false;
    *source = parsed;
    return true;
}

bool AudioRecordingSession::isActive() const
{
    return state == AudioRecordingState::Starting
        || state == AudioRecordingState::Recording
        || state == AudioRecordingState::Stopping
        || state == AudioRecordingState::Finalizing;
}

QJsonObject AudioRecordingSession::toJson() const
{
    return {
        {QStringLiteral("schemaVersion"), schemaVersion},
        {QStringLiteral("state"), audioRecordingStateName(state)},
        {QStringLiteral("sessionId"),
         sessionId.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(sessionId)},
        {QStringLiteral("pid"), pid > 0 ? QJsonValue(pid) : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("processStartTicks"),
         processStartTicks > 0 ? QJsonValue(QString::number(processStartTicks))
                               : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("processStartedAtMs"),
         processStartedAtMs > 0 ? QJsonValue(processStartedAtMs)
                                : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("coordinatorPid"),
         coordinatorPid > 0 ? QJsonValue(coordinatorPid) : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("coordinatorStartTicks"),
         coordinatorStartTicks > 0 ? QJsonValue(QString::number(coordinatorStartTicks))
                                   : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("startedAtMs"),
         startedAtMs > 0 ? QJsonValue(startedAtMs) : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("completedAtMs"),
         completedAtMs > 0 ? QJsonValue(completedAtMs) : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("updatedAtMs"),
         updatedAtMs > 0 ? QJsonValue(updatedAtMs) : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("source"),
         source.isValid() ? QJsonValue(source.toJson()) : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("temporaryPath"),
         temporaryPath.isEmpty() ? QJsonValue(QJsonValue::Null)
                                 : QJsonValue(temporaryPath)},
        {QStringLiteral("outputPath"),
         outputPath.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(outputPath)},
        {QStringLiteral("error"),
         error.isNull() ? QJsonValue(QJsonValue::Null) : QJsonValue(error.toJson())},
    };
}

bool AudioRecordingSession::fromJson(const QJsonObject &object,
                                     AudioRecordingSession *session,
                                     RecordingError *error)
{
    if (!session)
        return false;

    const int schemaVersion = object.value(QStringLiteral("schemaVersion")).toInt(-1);
    if (schemaVersion != SchemaVersion) {
        if (error) {
            *error = makeError(QStringLiteral("unsupported_schema"),
                               QStringLiteral("Unsupported audio recording state schema"),
                               {{QStringLiteral("schemaVersion"), schemaVersion}});
        }
        return false;
    }

    AudioRecordingState state;
    if (!parseAudioRecordingState(object.value(QStringLiteral("state")).toString(), &state)) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_state"),
                               QStringLiteral("Audio recording state file has an invalid state"));
        }
        return false;
    }

    AudioRecordingSession parsed;
    parsed.schemaVersion = schemaVersion;
    parsed.sessionId = object.value(QStringLiteral("sessionId")).toString();
    parsed.state = state;
    parsed.pid = object.value(QStringLiteral("pid")).toInteger();
    parsed.processStartTicks =
        object.value(QStringLiteral("processStartTicks")).toString().toULongLong();
    parsed.processStartedAtMs =
        object.value(QStringLiteral("processStartedAtMs")).toInteger();
    parsed.coordinatorPid = object.value(QStringLiteral("coordinatorPid")).toInteger();
    parsed.coordinatorStartTicks =
        object.value(QStringLiteral("coordinatorStartTicks")).toString().toULongLong();
    parsed.startedAtMs = object.value(QStringLiteral("startedAtMs")).toInteger();
    parsed.completedAtMs = object.value(QStringLiteral("completedAtMs")).toInteger();
    parsed.updatedAtMs = object.value(QStringLiteral("updatedAtMs")).toInteger();
    parsed.temporaryPath = object.value(QStringLiteral("temporaryPath")).toString();
    parsed.outputPath = object.value(QStringLiteral("outputPath")).toString();
    parsed.error = RecordingError::fromJson(object.value(QStringLiteral("error")));

    const QJsonValue sourceValue = object.value(QStringLiteral("source"));
    if (!sourceValue.isNull()
        && !AudioSourceInfo::fromJson(sourceValue.toObject(), &parsed.source)) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_audio_source"),
                               QStringLiteral("Audio recording state has an invalid source"));
        }
        return false;
    }

    *session = parsed;
    return true;
}

QJsonObject AudioOperationResult::toJson(const QString &command) const
{
    QJsonObject object = session.toJson();
    const RecordingError effectiveError = error.isNull() ? session.error : error;
    object.insert(QStringLiteral("command"), command);
    object.insert(QStringLiteral("ok"), ok);
    object.insert(QStringLiteral("error"),
                  effectiveError.isNull() ? QJsonValue(QJsonValue::Null)
                                          : QJsonValue(effectiveError.toJson()));
    return object;
}

QString audioRecordingStateName(AudioRecordingState state)
{
    switch (state) {
    case AudioRecordingState::Idle:
        return QStringLiteral("idle");
    case AudioRecordingState::Starting:
        return QStringLiteral("starting");
    case AudioRecordingState::Recording:
        return QStringLiteral("recording");
    case AudioRecordingState::Stopping:
        return QStringLiteral("stopping");
    case AudioRecordingState::Finalizing:
        return QStringLiteral("finalizing");
    case AudioRecordingState::Error:
        return QStringLiteral("error");
    }
    return QStringLiteral("idle");
}

bool parseAudioRecordingState(const QString &name, AudioRecordingState *state)
{
    if (!state)
        return false;
    if (name == QStringLiteral("idle"))
        *state = AudioRecordingState::Idle;
    else if (name == QStringLiteral("starting"))
        *state = AudioRecordingState::Starting;
    else if (name == QStringLiteral("recording"))
        *state = AudioRecordingState::Recording;
    else if (name == QStringLiteral("stopping"))
        *state = AudioRecordingState::Stopping;
    else if (name == QStringLiteral("finalizing"))
        *state = AudioRecordingState::Finalizing;
    else if (name == QStringLiteral("error"))
        *state = AudioRecordingState::Error;
    else
        return false;
    return true;
}

QString audioSourceTypeName(AudioSourceType type)
{
    return type == AudioSourceType::System ? QStringLiteral("system")
                                          : QStringLiteral("mic");
}

bool parseAudioSourceType(const QString &name, AudioSourceType *type)
{
    if (!type)
        return false;
    if (name == QStringLiteral("mic"))
        *type = AudioSourceType::Microphone;
    else if (name == QStringLiteral("system"))
        *type = AudioSourceType::System;
    else
        return false;
    return true;
}

AudioRecordingSession idleAudioSession()
{
    AudioRecordingSession session;
    session.state = AudioRecordingState::Idle;
    session.updatedAtMs = QDateTime::currentMSecsSinceEpoch();
    return session;
}

} // namespace Clavis::Recording
