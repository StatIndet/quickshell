#include "capture_session_guard.h"

#include "process_identity.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QProcessEnvironment>

namespace Clavis::Recording {

QJsonObject CaptureConflict::toJson() const
{
    return {
        {QStringLiteral("kind"), kind},
        {QStringLiteral("state"), state},
        {QStringLiteral("sessionId"), sessionId},
    };
}

QString CaptureSessionGuard::baseDirectory() const
{
    const QString runtime =
        QProcessEnvironment::systemEnvironment().value(QStringLiteral("XDG_RUNTIME_DIR"));
    return runtime.isEmpty()
        ? QString()
        : QDir(runtime).filePath(QStringLiteral("clavis-shell"));
}

QString CaptureSessionGuard::lockPath() const
{
    return QDir(baseDirectory()).filePath(QStringLiteral("capture.lock"));
}

std::unique_ptr<QLockFile> CaptureSessionGuard::acquire(RecordingError *error,
                                                        int timeoutMs) const
{
    const QString directory = baseDirectory();
    if (directory.isEmpty() || !QDir().mkpath(directory)) {
        if (error) {
            *error = makeError(QStringLiteral("runtime_directory_unavailable"),
                               QStringLiteral("Unable to prepare the Clavis runtime directory"),
                               {{QStringLiteral("path"), directory}});
        }
        return {};
    }

    auto lock = std::make_unique<QLockFile>(lockPath());
    lock->setStaleLockTime(30000);
    if (!lock->tryLock(timeoutMs)) {
        if (error) {
            *error = makeError(
                QStringLiteral("capture_busy"),
                QStringLiteral("Another Clavis capture command is still starting"),
                {{QStringLiteral("lockPath"), lockPath()}});
        }
        return {};
    }
    return lock;
}

CaptureConflict CaptureSessionGuard::conflictExcluding(const QString &kind) const
{
    const QString base = baseDirectory();
    if (kind != QStringLiteral("screen")) {
        const CaptureConflict screen =
            inspect(QStringLiteral("screen"),
                    QDir(base).filePath(QStringLiteral("recording/session.json")));
        if (screen.active)
            return screen;
    }
    if (kind != QStringLiteral("audio")) {
        const CaptureConflict audio =
            inspect(QStringLiteral("audio"),
                    QDir(base).filePath(
                        QStringLiteral("audio-recording/session.json")));
        if (audio.active)
            return audio;
    }
    return {};
}

CaptureConflict CaptureSessionGuard::inspect(const QString &kind,
                                             const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    if (!document.isObject())
        return {};

    const QJsonObject object = document.object();
    const QString state = object.value(QStringLiteral("state")).toString();
    if (state == QStringLiteral("idle") || state == QStringLiteral("completed")
        || state == QStringLiteral("error") || state.isEmpty()) {
        return {};
    }

    const qint64 pid = object.value(QStringLiteral("pid")).toInteger();
    const quint64 ticks =
        object.value(QStringLiteral("processStartTicks")).toString().toULongLong();
    const qint64 coordinatorPid =
        object.value(QStringLiteral("coordinatorPid")).toInteger();
    const quint64 coordinatorTicks =
        object.value(QStringLiteral("coordinatorStartTicks")).toString().toULongLong();
    const QString temporaryPath =
        object.value(QStringLiteral("temporaryPath")).toString();

    bool live = false;
    if (state == QStringLiteral("recording")) {
        ProcessIdentity expected;
        expected.pid = pid;
        expected.startTicks = ticks;
        const QString executable = kind == QStringLiteral("audio")
            ? QStringLiteral("ffmpeg")
            : QStringLiteral("gpu-screen-recorder");
        expected.executable = executable;
        live = ProcessIdentityProbe::matches(expected, executable, temporaryPath);
    } else if (state == QStringLiteral("selecting")
               || state == QStringLiteral("starting")
               || state == QStringLiteral("stopping")) {
        ProcessIdentity expected;
        expected.pid = coordinatorPid;
        expected.startTicks = coordinatorTicks;
        expected.executable = QStringLiteral("key");
        live = ProcessIdentityProbe::matches(expected, QStringLiteral("key"));
    } else if (state == QStringLiteral("finalizing")) {
        // Finalization owns the session even when the capture process has
        // already exited, because its output has not been published yet.
        live = true;
    }

    if (!live)
        return {};
    return {
        true,
        kind,
        state,
        object.value(QStringLiteral("sessionId")).toString(),
    };
}

} // namespace Clavis::Recording
