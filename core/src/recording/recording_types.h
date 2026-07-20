#pragma once

#include <QJsonObject>
#include <QString>

namespace Clavis::Recording {

inline constexpr int SchemaVersion = 1;

enum ExitCode {
    Success = 0,
    GeneralFailure = 1,
    UsageError = 2,
    DependencyFailure = 3,
    SessionConflict = 4,
    StateFailure = 5,
    RecorderStartFailure = 6,
    RecorderStopFailure = 7,
    PostprocessFailure = 8,
    NiriUnavailable = 11,
};

enum class RecordingState {
    Idle,
    Selecting,
    Starting,
    Recording,
    Finalizing,
    Completed,
};

enum class RecordingType {
    Video,
    Gif,
};

struct RecordingError {
    QString code;
    QString message;
    QJsonObject details;

    bool isNull() const;
    QJsonObject toJson() const;
    static RecordingError fromJson(const QJsonValue &value);
};

struct RecordingSession {
    int schemaVersion = SchemaVersion;
    QString sessionId;
    RecordingState state = RecordingState::Idle;
    qint64 pid = 0;
    quint64 processStartTicks = 0;
    qint64 processStartedAtMs = 0;
    qint64 coordinatorPid = 0;
    quint64 coordinatorStartTicks = 0;
    qint64 startedAtMs = 0;
    qint64 completedAtMs = 0;
    qint64 updatedAtMs = 0;
    RecordingType type = RecordingType::Video;
    QString targetType = QStringLiteral("region");
    QString geometry;
    int fps = 60;
    QString audio = QStringLiteral("none");
    QString temporaryPath;
    QString outputPath;
    RecordingError error;

    bool isActive() const;
    QJsonObject toJson() const;
    static bool fromJson(const QJsonObject &object, RecordingSession *session, RecordingError *error);
};

struct StartOptions {
    RecordingType type = RecordingType::Video;
    QString target = QStringLiteral("region");
    QString geometry;
    QString audio = QStringLiteral("none");
    int fps = 60;
    QString outputDirectory;
};

struct OperationResult {
    bool ok = false;
    bool cancelled = false;
    int exitCode = 1;
    RecordingSession session;
    RecordingError error;

    QJsonObject toJson(const QString &command) const;
};

QString recordingStateName(RecordingState state);
bool parseRecordingState(const QString &name, RecordingState *state);
QString recordingTypeName(RecordingType type);
bool parseRecordingType(const QString &name, RecordingType *type);
bool normalizeRegionGeometry(const QString &value, QString *normalized = nullptr);
RecordingSession idleSession();
RecordingError makeError(const QString &code, const QString &message,
                         const QJsonObject &details = {});

} // namespace Clavis::Recording
