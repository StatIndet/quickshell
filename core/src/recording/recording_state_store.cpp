#include "recording_state_store.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QProcessEnvironment>
#include <QSaveFile>

namespace Clavis::Recording {

QString RecordingStateStore::runtimeDirectory() const
{
    const QString base =
        QProcessEnvironment::systemEnvironment().value(QStringLiteral("XDG_RUNTIME_DIR"));
    if (base.isEmpty())
        return {};
    return QDir(base).filePath(QStringLiteral("clavis-shell/recording"));
}

QString RecordingStateStore::sessionPath() const
{
    return QDir(runtimeDirectory()).filePath(QStringLiteral("session.json"));
}

QString RecordingStateStore::lockPath() const
{
    return QDir(runtimeDirectory()).filePath(QStringLiteral("session.lock"));
}

QString RecordingStateStore::logPath() const
{
    return QDir(runtimeDirectory()).filePath(QStringLiteral("recorder.log"));
}

bool RecordingStateStore::ensureRuntimeDirectory(RecordingError *error) const
{
    const QString path = runtimeDirectory();
    if (path.isEmpty()) {
        if (error) {
            *error = makeError(QStringLiteral("runtime_directory_unavailable"),
                               QStringLiteral("XDG_RUNTIME_DIR is not set"));
        }
        return false;
    }

    QDir directory;
    if (!directory.mkpath(path)) {
        if (error) {
            *error = makeError(QStringLiteral("runtime_directory_unavailable"),
                               QStringLiteral("Unable to create the recording runtime directory"),
                               {{QStringLiteral("path"), path}});
        }
        return false;
    }

    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                   | QFileDevice::ExeOwner);
    const QFileInfo info(path);
    if (!info.isDir() || !info.isWritable()) {
        if (error) {
            *error = makeError(QStringLiteral("runtime_directory_unwritable"),
                               QStringLiteral("Recording runtime directory is not writable"),
                               {{QStringLiteral("path"), path}});
        }
        return false;
    }
    return true;
}

std::unique_ptr<QLockFile> RecordingStateStore::acquireLock(RecordingError *error,
                                                            int timeoutMs) const
{
    if (!ensureRuntimeDirectory(error))
        return {};

    auto lock = std::make_unique<QLockFile>(lockPath());
    lock->setStaleLockTime(30000);
    if (!lock->tryLock(timeoutMs)) {
        if (error) {
            *error = makeError(QStringLiteral("recording_busy"),
                               QStringLiteral("Another Clavis recording command is still running"),
                               {{QStringLiteral("lockPath"), lockPath()}});
        }
        return {};
    }
    return lock;
}

bool RecordingStateStore::read(RecordingSession *session, bool *exists,
                               RecordingError *error) const
{
    if (exists)
        *exists = false;
    if (!session)
        return false;

    QFile file(sessionPath());
    if (!file.exists()) {
        *session = idleSession();
        return true;
    }
    if (exists)
        *exists = true;
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) {
            *error = makeError(QStringLiteral("state_read_failed"),
                               QStringLiteral("Unable to read recording state"),
                               {{QStringLiteral("path"), sessionPath()},
                                {QStringLiteral("reason"), file.errorString()}});
        }
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_state_file"),
                               QStringLiteral("Recording state is not valid JSON"),
                               {{QStringLiteral("path"), sessionPath()},
                                {QStringLiteral("reason"), parseError.errorString()}});
        }
        return false;
    }
    return RecordingSession::fromJson(document.object(), session, error);
}

bool RecordingStateStore::write(RecordingSession session, RecordingError *error) const
{
    if (!ensureRuntimeDirectory(error))
        return false;

    session.schemaVersion = SchemaVersion;
    session.updatedAtMs = QDateTime::currentMSecsSinceEpoch();
    QSaveFile file(sessionPath());
    file.setDirectWriteFallback(false);
    if (!file.open(QIODevice::WriteOnly)) {
        if (error) {
            *error = makeError(QStringLiteral("state_write_failed"),
                               QStringLiteral("Unable to open recording state for writing"),
                               {{QStringLiteral("path"), sessionPath()},
                                {QStringLiteral("reason"), file.errorString()}});
        }
        return false;
    }

    const QByteArray json =
        QJsonDocument(session.toJson()).toJson(QJsonDocument::Indented);
    if (file.write(json) != json.size() || !file.commit()) {
        if (error) {
            *error = makeError(QStringLiteral("state_write_failed"),
                               QStringLiteral("Unable to atomically write recording state"),
                               {{QStringLiteral("path"), sessionPath()},
                                {QStringLiteral("reason"), file.errorString()}});
        }
        return false;
    }
    QFile::setPermissions(sessionPath(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return true;
}

ProcessIdentity RecordingStateStore::recorderIdentity(const RecordingSession &session) const
{
    ProcessIdentity identity;
    identity.pid = session.pid;
    identity.startTicks = session.processStartTicks;
    identity.executable = QStringLiteral("gpu-screen-recorder");
    identity.arguments = {session.temporaryPath};
    return identity;
}

ProcessIdentity RecordingStateStore::coordinatorIdentity(const RecordingSession &session) const
{
    ProcessIdentity identity;
    identity.pid = session.coordinatorPid;
    identity.startTicks = session.coordinatorStartTicks;
    identity.executable = QStringLiteral("key");
    return identity;
}

bool RecordingStateStore::recorderMatches(const RecordingSession &session) const
{
    return ProcessIdentityProbe::matches(recorderIdentity(session),
                                         QStringLiteral("gpu-screen-recorder"),
                                         session.temporaryPath);
}

bool RecordingStateStore::coordinatorMatches(const RecordingSession &session) const
{
    const ProcessIdentity expected = coordinatorIdentity(session);
    if (!expected.isValid() || !ProcessIdentityProbe::isAlive(expected.pid))
        return false;
    const ProcessIdentity current = ProcessIdentityProbe::capture(expected.pid);
    return current.isValid() && current.startTicks == expected.startTicks
        && QFileInfo(current.executable).fileName() == QStringLiteral("key");
}

} // namespace Clavis::Recording
