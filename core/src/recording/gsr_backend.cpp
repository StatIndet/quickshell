#include "gsr_backend.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QThread>

#include <cerrno>
#include <csignal>

namespace Clavis::Recording {

GsrStartResult GsrBackend::start(const RecordingSession &session, const QString &logPath) const
{
    const QString program =
        QStandardPaths::findExecutable(QStringLiteral("gpu-screen-recorder"));
    if (program.isEmpty()) {
        return {
            false,
            {},
            0,
            {},
            makeError(QStringLiteral("dependency_missing"),
                      QStringLiteral("gpu-screen-recorder is not installed or not available in PATH"),
                      {{QStringLiteral("dependency"),
                        QStringLiteral("gpu-screen-recorder")}}),
        };
    }

    QFile log(logPath);
    if (log.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        log.write("Clavis Shell recording session\n");
        log.close();
    }

    QProcess process;
    const QStringList arguments = buildArguments(session);
    process.setProgram(program);
    process.setArguments(arguments);
    process.setStandardOutputFile(logPath, QIODevice::Append);
    process.setStandardErrorFile(logPath, QIODevice::Append);

    qint64 pid = 0;
    if (!process.startDetached(&pid) || pid <= 0) {
        return {
            false,
            {},
            0,
            arguments,
            makeError(QStringLiteral("recorder_start_failed"),
                      QStringLiteral("Unable to start gpu-screen-recorder"),
                      {{QStringLiteral("reason"), process.errorString()},
                       {QStringLiteral("logPath"), logPath}}),
        };
    }

    ProcessIdentity identity;
    for (int attempt = 0; attempt < 10; ++attempt) {
        QThread::msleep(100);
        identity = ProcessIdentityProbe::capture(pid);
        if (identity.isValid())
            break;
    }

    const ProcessIdentity expected{pid, identity.startTicks, program, arguments};
    if (!ProcessIdentityProbe::matches(expected, QStringLiteral("gpu-screen-recorder"),
                                       session.temporaryPath)) {
        return {
            false,
            identity,
            0,
            arguments,
            makeError(QStringLiteral("recorder_start_failed"),
                      QStringLiteral("gpu-screen-recorder exited before startup was confirmed"),
                      {{QStringLiteral("pid"), pid},
                       {QStringLiteral("logPath"), logPath},
                       {QStringLiteral("log"), logTail(logPath)}}),
        };
    }

    return {true, identity, QDateTime::currentMSecsSinceEpoch(), arguments, {}};
}

bool GsrBackend::stop(const ProcessIdentity &identity, const QString &temporaryPath,
                      RecordingError *error, int timeoutMs) const
{
    if (!ProcessIdentityProbe::matches(identity, QStringLiteral("gpu-screen-recorder"),
                                       temporaryPath)) {
        if (error) {
            *error = makeError(QStringLiteral("recorder_identity_mismatch"),
                               QStringLiteral("Refusing to stop an unverified recorder process"),
                               {{QStringLiteral("pid"), identity.pid}});
        }
        return false;
    }

    if (::kill(static_cast<pid_t>(identity.pid), SIGINT) != 0) {
        if (error) {
            *error = makeError(QStringLiteral("recorder_stop_failed"),
                               QStringLiteral("Unable to signal gpu-screen-recorder"),
                               {{QStringLiteral("pid"), identity.pid},
                                {QStringLiteral("errno"), errno}});
        }
        return false;
    }

    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < timeoutMs) {
        if (!ProcessIdentityProbe::isAlive(identity.pid))
            return true;
        const ProcessIdentity current = ProcessIdentityProbe::capture(identity.pid);
        if (!current.isValid() || current.startTicks != identity.startTicks)
            return true;
        QThread::msleep(100);
    }

    if (error) {
        *error = makeError(QStringLiteral("recorder_stop_timeout"),
                           QStringLiteral("Timed out waiting for gpu-screen-recorder to stop"),
                           {{QStringLiteral("pid"), identity.pid}});
    }
    return false;
}

QStringList GsrBackend::buildArguments(const RecordingSession &session) const
{
    QStringList arguments{
        QStringLiteral("-w"),
        QStringLiteral("region"),
        QStringLiteral("-region"),
        session.geometry,
        QStringLiteral("-f"),
        QString::number(session.fps),
        QStringLiteral("-k"),
        QStringLiteral("h264"),
    };
    if (session.audio == QStringLiteral("system")) {
        arguments << QStringLiteral("-a") << QStringLiteral("default_output")
                  << QStringLiteral("-ac") << QStringLiteral("aac");
    }
    arguments << QStringLiteral("-o") << session.temporaryPath;
    return arguments;
}

QString GsrBackend::logTail(const QString &logPath, qsizetype maximumBytes)
{
    QFile file(logPath);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    if (file.size() > maximumBytes)
        file.seek(file.size() - maximumBytes);
    return QString::fromUtf8(file.readAll()).trimmed();
}

} // namespace Clavis::Recording
