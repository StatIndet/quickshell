#include "recording_types.h"

#include <QDateTime>
#include <QJsonValue>
#include <QRegularExpression>

namespace Clavis::Recording {

bool RecordingError::isNull() const
{
    return code.isEmpty() && message.isEmpty();
}

QJsonObject RecordingError::toJson() const
{
    QJsonObject object{
        {QStringLiteral("code"), code},
        {QStringLiteral("message"), message},
    };
    if (!details.isEmpty())
        object.insert(QStringLiteral("details"), details);
    return object;
}

RecordingError RecordingError::fromJson(const QJsonValue &value)
{
    if (!value.isObject())
        return {};

    const QJsonObject object = value.toObject();
    return {
        object.value(QStringLiteral("code")).toString(),
        object.value(QStringLiteral("message")).toString(),
        object.value(QStringLiteral("details")).toObject(),
    };
}

bool RecordingSession::isActive() const
{
    return state == RecordingState::Selecting
        || state == RecordingState::Starting
        || state == RecordingState::Recording
        || state == RecordingState::Finalizing;
}

QJsonObject RecordingSession::toJson() const
{
    QJsonObject target{
        {QStringLiteral("type"), targetType},
        {QStringLiteral("geometry"), geometry.isEmpty() ? QJsonValue(QJsonValue::Null)
                                                        : QJsonValue(geometry)},
    };

    QJsonObject object{
        {QStringLiteral("schemaVersion"), schemaVersion},
        {QStringLiteral("state"), recordingStateName(state)},
        {QStringLiteral("sessionId"), sessionId.isEmpty() ? QJsonValue(QJsonValue::Null)
                                                          : QJsonValue(sessionId)},
        {QStringLiteral("pid"), pid > 0 ? QJsonValue(pid) : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("processStartTicks"),
         processStartTicks > 0 ? QJsonValue(QString::number(processStartTicks))
                               : QJsonValue(QJsonValue::Null)},
        {QStringLiteral("processStartedAtMs"),
         processStartedAtMs > 0 ? QJsonValue(processStartedAtMs) : QJsonValue(QJsonValue::Null)},
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
        {QStringLiteral("type"), recordingTypeName(type)},
        {QStringLiteral("target"), target},
        {QStringLiteral("fps"), fps},
        {QStringLiteral("audio"), audio},
        {QStringLiteral("temporaryPath"),
         temporaryPath.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(temporaryPath)},
        {QStringLiteral("outputPath"),
         outputPath.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(outputPath)},
        {QStringLiteral("error"),
         error.isNull() ? QJsonValue(QJsonValue::Null) : QJsonValue(error.toJson())},
    };
    return object;
}

bool RecordingSession::fromJson(const QJsonObject &object, RecordingSession *session,
                                RecordingError *error)
{
    if (!session)
        return false;

    const int schemaVersion = object.value(QStringLiteral("schemaVersion")).toInt(-1);
    if (schemaVersion != SchemaVersion) {
        if (error) {
            *error = makeError(QStringLiteral("unsupported_schema"),
                               QStringLiteral("Unsupported recording state schema"),
                               {{QStringLiteral("schemaVersion"), schemaVersion}});
        }
        return false;
    }

    RecordingState parsedState;
    if (!parseRecordingState(object.value(QStringLiteral("state")).toString(), &parsedState)) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_state"),
                               QStringLiteral("Recording state file contains an invalid state"));
        }
        return false;
    }

    RecordingType parsedType;
    if (!parseRecordingType(object.value(QStringLiteral("type")).toString(), &parsedType)) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_recording_type"),
                               QStringLiteral("Recording state file contains an invalid type"));
        }
        return false;
    }

    RecordingSession parsed;
    parsed.schemaVersion = schemaVersion;
    parsed.sessionId = object.value(QStringLiteral("sessionId")).toString();
    parsed.state = parsedState;
    parsed.pid = object.value(QStringLiteral("pid")).toInteger();
    parsed.processStartTicks =
        object.value(QStringLiteral("processStartTicks")).toString().toULongLong();
    parsed.processStartedAtMs = object.value(QStringLiteral("processStartedAtMs")).toInteger();
    parsed.coordinatorPid = object.value(QStringLiteral("coordinatorPid")).toInteger();
    parsed.coordinatorStartTicks =
        object.value(QStringLiteral("coordinatorStartTicks")).toString().toULongLong();
    parsed.startedAtMs = object.value(QStringLiteral("startedAtMs")).toInteger();
    parsed.completedAtMs = object.value(QStringLiteral("completedAtMs")).toInteger();
    parsed.updatedAtMs = object.value(QStringLiteral("updatedAtMs")).toInteger();
    parsed.type = parsedType;
    const QJsonObject target = object.value(QStringLiteral("target")).toObject();
    parsed.targetType = target.value(QStringLiteral("type")).toString(QStringLiteral("region"));
    parsed.geometry = target.value(QStringLiteral("geometry")).toString();
    parsed.fps = object.value(QStringLiteral("fps")).toInt(60);
    parsed.audio = object.value(QStringLiteral("audio")).toString(QStringLiteral("none"));
    parsed.temporaryPath = object.value(QStringLiteral("temporaryPath")).toString();
    parsed.outputPath = object.value(QStringLiteral("outputPath")).toString();
    parsed.error = RecordingError::fromJson(object.value(QStringLiteral("error")));
    *session = parsed;
    return true;
}

QJsonObject OperationResult::toJson(const QString &command) const
{
    QJsonObject object = session.toJson();
    const RecordingError effectiveError = error.isNull() ? session.error : error;
    object.insert(QStringLiteral("command"), command);
    object.insert(QStringLiteral("ok"), ok);
    object.insert(QStringLiteral("cancelled"), cancelled);
    object.insert(QStringLiteral("error"),
                  effectiveError.isNull() ? QJsonValue(QJsonValue::Null)
                                          : QJsonValue(effectiveError.toJson()));
    return object;
}

QString recordingStateName(RecordingState state)
{
    switch (state) {
    case RecordingState::Idle:
        return QStringLiteral("idle");
    case RecordingState::Selecting:
        return QStringLiteral("selecting");
    case RecordingState::Starting:
        return QStringLiteral("starting");
    case RecordingState::Recording:
        return QStringLiteral("recording");
    case RecordingState::Finalizing:
        return QStringLiteral("finalizing");
    case RecordingState::Completed:
        return QStringLiteral("completed");
    }
    return QStringLiteral("idle");
}

bool parseRecordingState(const QString &name, RecordingState *state)
{
    if (!state)
        return false;
    if (name == QStringLiteral("idle"))
        *state = RecordingState::Idle;
    else if (name == QStringLiteral("selecting"))
        *state = RecordingState::Selecting;
    else if (name == QStringLiteral("starting"))
        *state = RecordingState::Starting;
    else if (name == QStringLiteral("recording"))
        *state = RecordingState::Recording;
    else if (name == QStringLiteral("finalizing"))
        *state = RecordingState::Finalizing;
    else if (name == QStringLiteral("completed"))
        *state = RecordingState::Completed;
    else
        return false;
    return true;
}

QString recordingTypeName(RecordingType type)
{
    return type == RecordingType::Gif ? QStringLiteral("gif") : QStringLiteral("video");
}

bool parseRecordingType(const QString &name, RecordingType *type)
{
    if (!type)
        return false;
    if (name == QStringLiteral("video"))
        *type = RecordingType::Video;
    else if (name == QStringLiteral("gif"))
        *type = RecordingType::Gif;
    else
        return false;
    return true;
}

bool normalizeRegionGeometry(const QString &value, QString *normalized)
{
    static const QRegularExpression expression(
        QStringLiteral(R"(^\s*(\d+)x(\d+)\+(-?\d+)\+(-?\d+)\s*$)"));
    const QRegularExpressionMatch match = expression.match(value);
    if (!match.hasMatch())
        return false;

    bool widthOk = false;
    bool heightOk = false;
    const int width = match.captured(1).toInt(&widthOk);
    const int height = match.captured(2).toInt(&heightOk);
    if (!widthOk || !heightOk || width <= 0 || height <= 0)
        return false;

    if (normalized) {
        *normalized = QStringLiteral("%1x%2+%3+%4")
                          .arg(width)
                          .arg(height)
                          .arg(match.captured(3).toInt())
                          .arg(match.captured(4).toInt());
    }
    return true;
}

RecordingSession idleSession()
{
    RecordingSession session;
    session.state = RecordingState::Idle;
    session.updatedAtMs = QDateTime::currentMSecsSinceEpoch();
    return session;
}

RecordingError makeError(const QString &code, const QString &message, const QJsonObject &details)
{
    return {code, message, details};
}

} // namespace Clavis::Recording
