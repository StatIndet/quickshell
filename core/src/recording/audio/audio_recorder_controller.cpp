#include "audio_recorder_controller.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUuid>

namespace Clavis::Recording {

AudioOperationResult AudioRecorderController::start(
    const AudioStartOptions &options)
{
    RecordingError error;
    std::unique_ptr<QLockFile> captureLock = m_captureGuard.acquire(&error);
    if (!captureLock) {
        return failure(error.code == QStringLiteral("capture_busy")
                           ? SessionConflict
                           : DependencyFailure,
                       error);
    }

    std::unique_ptr<QLockFile> stateLock = m_store.acquireLock(&error);
    if (!stateLock) {
        return failure(error.code == QStringLiteral("recording_busy")
                           ? SessionConflict
                           : DependencyFailure,
                       error);
    }

    AudioRecordingSession current;
    bool exists = false;
    if (!m_store.read(&current, &exists, &error))
        return failure(StateFailure, error);

    if (current.state == AudioRecordingState::Starting
        && !m_store.coordinatorMatches(current)) {
        QFile::remove(current.temporaryPath);
        current.state = AudioRecordingState::Error;
        current.error = makeError(
            QStringLiteral("orphaned_audio_start"),
            QStringLiteral("Recovered an interrupted audio recording start"));
        clearProcess(&current);
        persist(&current, nullptr);
    } else if (current.state == AudioRecordingState::Recording
               && !m_store.recorderMatches(current)) {
        recoverInterrupted(&current);
        persist(&current, nullptr);
    }

    if (current.isActive()) {
        return failure(
            SessionConflict,
            makeError(QStringLiteral("audio_recording_already_active"),
                      QStringLiteral("A Clavis audio recording session is already active"),
                      {{QStringLiteral("state"),
                        audioRecordingStateName(current.state)},
                       {QStringLiteral("sessionId"), current.sessionId}}),
            current);
    }

    const CaptureConflict conflict =
        m_captureGuard.conflictExcluding(QStringLiteral("audio"));
    if (conflict.active) {
        return failure(
            SessionConflict,
            makeError(QStringLiteral("capture_session_conflict"),
                      QStringLiteral("Another Clavis capture session is already active"),
                      {{QStringLiteral("conflict"), conflict.toJson()}}),
            current);
    }

    if (!dependenciesAvailable(&error))
        return failure(DependencyFailure, error, current);

    const AudioSourceResolution resolution =
        m_sourceResolver.resolve(options.source);
    if (!resolution.ok)
        return failure(DependencyFailure, resolution.error, current);

    AudioRecordingSession session;
    session.sessionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    session.source = resolution.source;
    const ProcessIdentity coordinator =
        ProcessIdentityProbe::capture(QCoreApplication::applicationPid());
    session.coordinatorPid = coordinator.pid;
    session.coordinatorStartTicks = coordinator.startTicks;

    if (!prepareOutput(options, &session, &error))
        return failure(DependencyFailure, error, session);

    session.state = AudioRecordingState::Starting;
    if (!persist(&session, &error))
        return failure(StateFailure, error, session);

    const AudioBackendStartResult started =
        m_backend.start(session, m_store.logPath());
    if (!started.ok) {
        QFile::remove(session.temporaryPath);
        session.state = AudioRecordingState::Error;
        session.error = started.error;
        clearProcess(&session);
        persist(&session, nullptr);
        return failure(RecorderStartFailure, started.error, session);
    }

    session.state = AudioRecordingState::Recording;
    session.pid = started.identity.pid;
    session.processStartTicks = started.identity.startTicks;
    session.processStartedAtMs = started.startedAtMs;
    session.startedAtMs = started.startedAtMs;
    session.coordinatorPid = 0;
    session.coordinatorStartTicks = 0;
    session.error = {};
    if (!persist(&session, &error)) {
        m_backend.stop(started.identity, session.temporaryPath);
        QFile::remove(session.temporaryPath);
        return failure(StateFailure, error, session);
    }

    AudioOperationResult result;
    result.ok = true;
    result.exitCode = Success;
    result.session = session;
    return result;
}

AudioOperationResult AudioRecorderController::status()
{
    RecordingError error;
    AudioRecordingSession session;
    bool exists = false;
    if (!m_store.read(&session, &exists, &error))
        return failure(StateFailure, error);
    if (!exists) {
        AudioOperationResult result;
        result.ok = true;
        result.exitCode = Success;
        result.session = idleAudioSession();
        return result;
    }

    bool changed = false;
    if (session.state == AudioRecordingState::Starting
        && !m_store.coordinatorMatches(session)) {
        QFile::remove(session.temporaryPath);
        session.state = AudioRecordingState::Error;
        session.error = makeError(
            QStringLiteral("orphaned_audio_start"),
            QStringLiteral("The audio recording start process is no longer running"));
        clearProcess(&session);
        changed = true;
    } else if (session.state == AudioRecordingState::Recording
               && !m_store.recorderMatches(session)) {
        recoverInterrupted(&session);
        changed = true;
    } else if ((session.state == AudioRecordingState::Stopping
                || session.state == AudioRecordingState::Finalizing)
               && !m_store.coordinatorMatches(session)) {
        if (m_store.recorderMatches(session))
            m_backend.stop(m_store.recorderIdentity(session), session.temporaryPath);
        recoverInterrupted(&session);
        changed = true;
    }

    if (changed) {
        std::unique_ptr<QLockFile> lock = m_store.acquireLock(&error, 250);
        if (lock && !persist(&session, &error))
            return failure(StateFailure, error, session);
    }

    AudioOperationResult result;
    result.ok = true;
    result.exitCode = Success;
    result.session = session;
    return result;
}

AudioOperationResult AudioRecorderController::stop()
{
    RecordingError error;
    std::unique_ptr<QLockFile> lock = m_store.acquireLock(&error);
    if (!lock) {
        return failure(error.code == QStringLiteral("recording_busy")
                           ? SessionConflict
                           : DependencyFailure,
                       error);
    }

    AudioRecordingSession session;
    bool exists = false;
    if (!m_store.read(&session, &exists, &error))
        return failure(StateFailure, error);
    if (!exists || session.state == AudioRecordingState::Idle
        || session.state == AudioRecordingState::Error) {
        return failure(
            StateFailure,
            makeError(QStringLiteral("no_active_audio_recording"),
                      QStringLiteral("There is no active Clavis audio recording session")),
            session);
    }
    if (session.state == AudioRecordingState::Starting) {
        return failure(
            StateFailure,
            makeError(QStringLiteral("audio_recording_not_started"),
                      QStringLiteral("The audio recorder is still starting")),
            session);
    }
    if (session.state == AudioRecordingState::Finalizing)
        return finalize(session);

    const ProcessIdentity coordinator =
        ProcessIdentityProbe::capture(QCoreApplication::applicationPid());
    session.state = AudioRecordingState::Stopping;
    session.coordinatorPid = coordinator.pid;
    session.coordinatorStartTicks = coordinator.startTicks;
    if (!persist(&session, &error))
        return failure(StateFailure, error, session);

    if (m_store.recorderMatches(session)) {
        const AudioBackendStopResult stopped =
            m_backend.stop(m_store.recorderIdentity(session), session.temporaryPath);
        if (!stopped.ok) {
            session.error = stopped.error;
            if (!m_store.recorderMatches(session)) {
                session.state = AudioRecordingState::Error;
                clearProcess(&session);
                QFile::remove(session.temporaryPath);
            }
            persist(&session, nullptr);
            return failure(RecorderStopFailure, stopped.error, session);
        }
        if (stopped.forced) {
            session.error = makeError(
                QStringLiteral("audio_recorder_forced_stop"),
                QStringLiteral("ffmpeg required forced termination; validating its output"));
        }
    } else {
        session.error = makeError(
            QStringLiteral("audio_recorder_exited"),
            QStringLiteral("ffmpeg was already gone; attempting output recovery"));
    }

    session.state = AudioRecordingState::Finalizing;
    clearProcess(&session);
    session.coordinatorPid = coordinator.pid;
    session.coordinatorStartTicks = coordinator.startTicks;
    if (!persist(&session, &error))
        return failure(StateFailure, error, session);
    return finalize(session);
}

AudioOperationResult AudioRecorderController::failure(
    int exitCode, const RecordingError &error,
    const AudioRecordingSession &session) const
{
    AudioOperationResult result;
    result.exitCode = exitCode;
    result.session = session;
    result.error = error;
    return result;
}

bool AudioRecorderController::persist(AudioRecordingSession *session,
                                      RecordingError *error)
{
    if (!session)
        return false;
    session->updatedAtMs = QDateTime::currentMSecsSinceEpoch();
    return m_store.write(*session, error);
}

bool AudioRecorderController::prepareOutput(const AudioStartOptions &options,
                                            AudioRecordingSession *session,
                                            RecordingError *error) const
{
    if (!session)
        return false;

    QString directory = options.outputDirectory;
    if (directory.startsWith(QStringLiteral("~/")))
        directory.replace(0, 1, QDir::homePath());
    if (directory.isEmpty()) {
        QString music =
            QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
        if (music.isEmpty())
            music = QDir::home().filePath(QStringLiteral("Music"));
        directory =
            QDir(music).filePath(QStringLiteral("Clavis/Audio"));
    }
    directory = QDir::cleanPath(directory);
    if (!QDir().mkpath(directory) || !QFileInfo(directory).isWritable()) {
        if (error) {
            *error = makeError(QStringLiteral("output_directory_unwritable"),
                               QStringLiteral("Audio output directory is not writable"),
                               {{QStringLiteral("path"), directory}});
        }
        return false;
    }

    const QString stamp =
        QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"));
    const QString sourceLabel =
        session->source.type == AudioSourceType::System
        ? QStringLiteral("System")
        : QStringLiteral("Mic");
    const QString baseName =
        QStringLiteral("Clavis_%1_%2_%3")
            .arg(sourceLabel, stamp, session->sessionId.left(8));
    session->outputPath =
        QDir(directory).filePath(baseName + QStringLiteral(".m4a"));
    session->temporaryPath =
        QDir(directory).filePath(QStringLiteral(".%1.partial.m4a").arg(baseName));
    return true;
}

bool AudioRecorderController::dependenciesAvailable(RecordingError *error) const
{
    for (const QString &dependency :
         {QStringLiteral("ffmpeg"), QStringLiteral("ffprobe"),
          QStringLiteral("pactl")}) {
        if (QStandardPaths::findExecutable(dependency).isEmpty()) {
            if (error) {
                *error = makeError(
                    QStringLiteral("dependency_missing"),
                    QStringLiteral("%1 is not installed or not available in PATH")
                        .arg(dependency),
                    {{QStringLiteral("dependency"), dependency}});
            }
            return false;
        }
    }
    return m_store.ensureRuntimeDirectory(error);
}

AudioOperationResult AudioRecorderController::finalize(
    AudioRecordingSession session)
{
    RecordingError error;
    const AudioFinalizeResult finalized = m_finalizer.finalize(session);
    if (!finalized.ok) {
        QFile::remove(session.temporaryPath);
        session.state = AudioRecordingState::Error;
        session.error = finalized.error;
        clearProcess(&session);
        session.coordinatorPid = 0;
        session.coordinatorStartTicks = 0;
        persist(&session, nullptr);
        return failure(PostprocessFailure, finalized.error, session);
    }

    session.state = AudioRecordingState::Idle;
    session.completedAtMs = QDateTime::currentMSecsSinceEpoch();
    clearProcess(&session);
    session.coordinatorPid = 0;
    session.coordinatorStartTicks = 0;
    session.temporaryPath.clear();
    session.error = {};
    if (!persist(&session, &error))
        return failure(StateFailure, error, session);

    AudioOperationResult result;
    result.ok = true;
    result.exitCode = Success;
    result.session = session;
    return result;
}

void AudioRecorderController::recoverInterrupted(AudioRecordingSession *session)
{
    if (!session)
        return;

    const bool recovered = !session->temporaryPath.isEmpty()
        && m_finalizer.finalize(*session).ok;
    if (!recovered)
        QFile::remove(session->temporaryPath);

    session->state = AudioRecordingState::Error;
    session->completedAtMs =
        recovered ? QDateTime::currentMSecsSinceEpoch() : 0;
    session->error = makeError(
        QStringLiteral("audio_recorder_exited"),
        recovered
            ? QStringLiteral("ffmpeg exited unexpectedly; its valid output was recovered")
            : QStringLiteral("ffmpeg exited unexpectedly and its output was invalid"),
        {{QStringLiteral("outputRecovered"), recovered}});
    if (recovered)
        session->temporaryPath.clear();
    clearProcess(session);
    session->coordinatorPid = 0;
    session->coordinatorStartTicks = 0;
}

void AudioRecorderController::clearProcess(AudioRecordingSession *session)
{
    if (!session)
        return;
    session->pid = 0;
    session->processStartTicks = 0;
    session->processStartedAtMs = 0;
}

} // namespace Clavis::Recording
