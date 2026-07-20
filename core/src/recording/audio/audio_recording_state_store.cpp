#include "audio_recording_state_store.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QProcessEnvironment>
#include <QSaveFile>

namespace Clavis::Recording {

QString AudioRecordingStateStore::runtimeDirectory() const
{
    const QString base =
        QProcessEnvironment::systemEnvironment().value(QStringLiteral("XDG_RUNTIME_DIR"));
    if (base.isEmpty())
        return {};
    return QDir(base).filePath(QStringLiteral("clavis-shell/audio-recording"));
}

QString AudioRecordingStateStore::sessionPath() const
{
    return QDir(runtimeDirectory()).filePath(QStringLiteral("session.json"));
}

QString AudioRecordingStateStore::lockPath() const
{
    return QDir(runtimeDirectory()).filePath(QStringLiteral("session.lock"));
}

QString AudioRecordingStateStore::logPath() const
{
    return QDir(runtimeDirectory()).filePath(QStringLiteral("ffmpeg.log"));
}

bool AudioRecordingStateStore::ensureRuntimeDirectory(RecordingError *error) const
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
            *error = makeError(
                QStringLiteral("runtime_directory_unavailable"),
                QStringLiteral("Unable to create the audio recording runtime directory"),
                {{QStringLiteral("path"), path}});
        }
        return false;
    }

    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                   | QFileDevice::ExeOwner);
    const QFileInfo info(path);
    if (!info.isDir() || !info.isWritable()) {
        if (error) {
            *error = makeError(
                QStringLiteral("runtime_directory_unwritable"),
                QStringLiteral("Audio recording runtime directory is not writable"),
                {{QStringLiteral("path"), path}});
        }
        return false;
    }
    return true;
}

std::unique_ptr<QLockFile>
AudioRecordingStateStore::acquireLock(RecordingError *error, int timeoutMs) const
{
    if (!ensureRuntimeDirectory(error))
        return {};

    auto lock = std::make_unique<QLockFile>(lockPath());
    lock->setStaleLockTime(30000);
    if (!lock->tryLock(timeoutMs)) {
        if (error) {
            *error = makeError(
                QStringLiteral("recording_busy"),
                QStringLiteral("Another Clavis audio recording command is still running"),
                {{QStringLiteral("lockPath"), lockPath()}});
        }
        return {};
    }
    return lock;
}

bool AudioRecordingStateStore::read(AudioRecordingSession *session, bool *exists,
                                    RecordingError *error) const
{
    if (exists)
        *exists = false;
    if (!session)
        return false;

    QFile file(sessionPath());
    if (!file.exists()) {
        *session = idleAudioSession();
        return true;
    }
    if (exists)
        *exists = true;
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) {
            *error = makeError(QStringLiteral("state_read_failed"),
                               QStringLiteral("Unable to read audio recording state"),
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
                               QStringLiteral("Audio recording state is not valid JSON"),
                               {{QStringLiteral("path"), sessionPath()},
                                {QStringLiteral("reason"), parseError.errorString()}});
        }
        return false;
    }
    return AudioRecordingSession::fromJson(document.object(), session, error);
}

bool AudioRecordingStateStore::write(AudioRecordingSession session,
                                     RecordingError *error) const
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
                               QStringLiteral("Unable to open audio recording state"),
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
                               QStringLiteral("Unable to atomically write audio recording state"),
                               {{QStringLiteral("path"), sessionPath()},
                                {QStringLiteral("reason"), file.errorString()}});
        }
        return false;
    }
    QFile::setPermissions(sessionPath(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return true;
}

ProcessIdentity AudioRecordingStateStore::recorderIdentity(
    const AudioRecordingSession &session) const
{
    ProcessIdentity identity;
    identity.pid = session.pid;
    identity.startTicks = session.processStartTicks;
    identity.executable = QStringLiteral("ffmpeg");
    identity.arguments = {session.temporaryPath};
    return identity;
}

ProcessIdentity AudioRecordingStateStore::coordinatorIdentity(
    const AudioRecordingSession &session) const
{
    ProcessIdentity identity;
    identity.pid = session.coordinatorPid;
    identity.startTicks = session.coordinatorStartTicks;
    identity.executable = QStringLiteral("key");
    return identity;
}

bool AudioRecordingStateStore::recorderMatches(
    const AudioRecordingSession &session) const
{
    return ProcessIdentityProbe::matches(recorderIdentity(session),
                                         QStringLiteral("ffmpeg"),
                                         session.temporaryPath);
}

bool AudioRecordingStateStore::coordinatorMatches(
    const AudioRecordingSession &session) const
{
    const ProcessIdentity expected = coordinatorIdentity(session);
    if (!expected.isValid() || !ProcessIdentityProbe::isAlive(expected.pid))
        return false;
    const ProcessIdentity current = ProcessIdentityProbe::capture(expected.pid);
    return current.isValid() && current.startTicks == expected.startTicks
        && QFileInfo(current.executable).fileName() == QStringLiteral("key");
}

} // namespace Clavis::Recording
