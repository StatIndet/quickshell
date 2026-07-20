#include "ffmpeg_audio_backend.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QThread>

#include <cerrno>
#include <csignal>

namespace Clavis::Recording {

AudioBackendStartResult FfmpegAudioBackend::start(
    const AudioRecordingSession &session, const QString &logPath) const
{
    const QString program = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
    if (program.isEmpty()) {
        return {
            false,
            {},
            0,
            {},
            makeError(QStringLiteral("dependency_missing"),
                      QStringLiteral("ffmpeg is not installed or not available in PATH"),
                      {{QStringLiteral("dependency"), QStringLiteral("ffmpeg")}}),
        };
    }

    QFile log(logPath);
    if (log.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        log.write("Clavis Shell audio recording session\n");
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
            makeError(QStringLiteral("audio_recorder_start_failed"),
                      QStringLiteral("Unable to start ffmpeg audio recording"),
                      {{QStringLiteral("reason"), process.errorString()},
                       {QStringLiteral("logPath"), logPath}}),
        };
    }

    ProcessIdentity identity;
    for (int attempt = 0; attempt < 15; ++attempt) {
        QThread::msleep(100);
        identity = ProcessIdentityProbe::capture(pid);
        const ProcessIdentity expected{pid, identity.startTicks, program, arguments};
        if (ProcessIdentityProbe::matches(expected, QStringLiteral("ffmpeg"),
                                          session.temporaryPath)) {
            // Keep a short confirmation window so a missing Pulse source does
            // not look like a successful recording start.
            if (attempt >= 5)
                break;
        } else if (attempt >= 2 && !ProcessIdentityProbe::isAlive(pid)) {
            break;
        }
    }

    const ProcessIdentity expected{pid, identity.startTicks, program, arguments};
    if (!ProcessIdentityProbe::matches(expected, QStringLiteral("ffmpeg"),
                                       session.temporaryPath)) {
        return {
            false,
            identity,
            0,
            arguments,
            makeError(
                QStringLiteral("audio_recorder_start_failed"),
                QStringLiteral("ffmpeg exited before audio recording startup was confirmed"),
                {{QStringLiteral("pid"), pid},
                 {QStringLiteral("logPath"), logPath},
                 {QStringLiteral("log"), logTail(logPath)}}),
        };
    }

    return {true, identity, QDateTime::currentMSecsSinceEpoch(), arguments, {}};
}

AudioBackendStopResult FfmpegAudioBackend::stop(
    const ProcessIdentity &identity, const QString &temporaryPath,
    int interruptTimeoutMs, int terminateTimeoutMs, int killTimeoutMs) const
{
    if (!ProcessIdentityProbe::matches(identity, QStringLiteral("ffmpeg"),
                                       temporaryPath)) {
        return {
            false,
            false,
            makeError(QStringLiteral("audio_recorder_identity_mismatch"),
                      QStringLiteral("Refusing to stop an unverified ffmpeg process"),
                      {{QStringLiteral("pid"), identity.pid}}),
        };
    }

    if (::kill(static_cast<pid_t>(identity.pid), SIGINT) != 0) {
        return {
            false,
            false,
            makeError(QStringLiteral("audio_recorder_stop_failed"),
                      QStringLiteral("Unable to interrupt ffmpeg"),
                      {{QStringLiteral("pid"), identity.pid},
                       {QStringLiteral("errno"), errno}}),
        };
    }
    if (waitForExit(identity, interruptTimeoutMs))
        return {true, false, {}};

    if (::kill(static_cast<pid_t>(identity.pid), SIGTERM) == 0
        && waitForExit(identity, terminateTimeoutMs)) {
        return {true, true, {}};
    }

    if (ProcessIdentityProbe::matches(identity, QStringLiteral("ffmpeg"),
                                      temporaryPath)) {
        if (::kill(static_cast<pid_t>(identity.pid), SIGKILL) != 0) {
            return {
                false,
                true,
                makeError(QStringLiteral("audio_recorder_stop_failed"),
                          QStringLiteral("Unable to terminate ffmpeg"),
                          {{QStringLiteral("pid"), identity.pid},
                           {QStringLiteral("errno"), errno}}),
            };
        }
    }
    if (waitForExit(identity, killTimeoutMs))
        return {true, true, {}};

    return {
        false,
        true,
        makeError(QStringLiteral("audio_recorder_stop_timeout"),
                  QStringLiteral("Timed out waiting for ffmpeg to stop"),
                  {{QStringLiteral("pid"), identity.pid}}),
    };
}

QStringList FfmpegAudioBackend::buildArguments(
    const AudioRecordingSession &session) const
{
    return {
        QStringLiteral("-hide_banner"),
        QStringLiteral("-nostdin"),
        QStringLiteral("-loglevel"),
        QStringLiteral("warning"),
        QStringLiteral("-f"),
        QStringLiteral("pulse"),
        QStringLiteral("-i"),
        session.source.name,
        QStringLiteral("-vn"),
        QStringLiteral("-c:a"),
        QStringLiteral("aac"),
        QStringLiteral("-b:a"),
        QStringLiteral("192k"),
        QStringLiteral("-movflags"),
        QStringLiteral("+faststart"),
        QStringLiteral("-y"),
        session.temporaryPath,
    };
}

QString FfmpegAudioBackend::logTail(const QString &logPath, qsizetype maximumBytes)
{
    QFile file(logPath);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    if (file.size() > maximumBytes)
        file.seek(file.size() - maximumBytes);
    return QString::fromLocal8Bit(file.readAll()).trimmed();
}

bool FfmpegAudioBackend::waitForExit(const ProcessIdentity &identity, int timeoutMs)
{
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < timeoutMs) {
        if (!ProcessIdentityProbe::isAlive(identity.pid))
            return true;
        const ProcessIdentity current = ProcessIdentityProbe::capture(identity.pid);
        if (!current.isValid() || current.startTicks != identity.startTicks)
            return true;
        QThread::msleep(50);
    }
    return false;
}

} // namespace Clavis::Recording
