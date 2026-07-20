#include "recorder_controller.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QJsonArray>
#include <QThread>
#include <QUuid>

namespace Clavis::Recording {

OperationResult RecorderController::start(const StartOptions &options)
{
    RecordingError error;
    if (options.target != QStringLiteral("region")) {
        return failure(UsageError,
                       makeError(QStringLiteral("unsupported_target"),
                                 QStringLiteral("Only the region recording target is supported")));
    }
    QString geometry;
    if (options.geometry.trimmed().isEmpty()) {
        return failure(
            UsageError,
            makeError(QStringLiteral("missing_geometry"),
                      QStringLiteral("Region geometry must be provided with --geometry"),
                      {{QStringLiteral("expected"), QStringLiteral("WIDTHxHEIGHT+X+Y")}}));
    }
    if (!normalizeRegionGeometry(options.geometry, &geometry)) {
        return failure(
            UsageError,
            makeError(QStringLiteral("invalid_geometry"),
                      QStringLiteral("A valid region geometry must be provided with --geometry"),
                      {{QStringLiteral("expected"), QStringLiteral("WIDTHxHEIGHT+X+Y")}}));
    }
    if (options.fps < 1 || options.fps > 240) {
        return failure(UsageError,
                       makeError(QStringLiteral("invalid_fps"),
                                 QStringLiteral("FPS must be between 1 and 240")));
    }
    if (options.audio != QStringLiteral("none")
        && options.audio != QStringLiteral("system")) {
        return failure(UsageError,
                       makeError(QStringLiteral("unsupported_audio"),
                                 QStringLiteral("Audio must be 'none' or 'system'")));
    }

    std::unique_ptr<QLockFile> captureLock = m_captureGuard.acquire(&error);
    if (!captureLock)
        return failure(error.code == QStringLiteral("capture_busy")
                           ? SessionConflict
                           : DependencyFailure,
                       error);

    std::unique_ptr<QLockFile> lock = m_store.acquireLock(&error);
    if (!lock)
        return failure(error.code == QStringLiteral("recording_busy")
                           ? SessionConflict
                           : DependencyFailure,
                       error);

    RecordingSession current;
    bool exists = false;
    if (!m_store.read(&current, &exists, &error))
        return failure(StateFailure, error);

    if ((current.state == RecordingState::Selecting
         || current.state == RecordingState::Starting)
        && !m_store.coordinatorMatches(current)) {
        current = idleSession();
        current.error = makeError(QStringLiteral("orphaned_start"),
                                  QStringLiteral("Recovered an interrupted recording start"));
        if (!persist(&current, &error))
            return failure(StateFailure, error, current);
    }

    if (current.state == RecordingState::Recording && !m_store.recorderMatches(current)) {
        current.state = RecordingState::Finalizing;
        current.pid = 0;
        current.error = makeError(
            QStringLiteral("recorder_exited"),
            QStringLiteral("The recorder exited unexpectedly; stop can retry finalization"));
        if (!persist(&current, &error))
            return failure(StateFailure, error, current);
    }

    if (current.isActive()) {
        return failure(
            SessionConflict,
            makeError(QStringLiteral("recording_already_active"),
                      QStringLiteral("A Clavis recording session is already active"),
                      {{QStringLiteral("state"), recordingStateName(current.state)},
                       {QStringLiteral("sessionId"), current.sessionId}}),
            current);
    }

    const CaptureConflict conflict =
        m_captureGuard.conflictExcluding(QStringLiteral("screen"));
    if (conflict.active) {
        return failure(
            SessionConflict,
            makeError(QStringLiteral("capture_session_conflict"),
                      QStringLiteral("Another Clavis capture session is already active"),
                      {{QStringLiteral("conflict"), conflict.toJson()}}),
            current);
    }

    RecordingSession session;
    session.sessionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    session.type = options.type;
    session.targetType = options.target;
    session.geometry = geometry;
    session.fps = options.fps;
    session.audio = options.audio;
    const ProcessIdentity coordinator =
        ProcessIdentityProbe::capture(QCoreApplication::applicationPid());
    session.coordinatorPid = coordinator.pid;
    session.coordinatorStartTicks = coordinator.startTicks;

    if (!prepareOutput(options, &session, &error))
        return failure(DependencyFailure, error, session);
    if (!recordingDependenciesAvailable(QFileInfo(session.outputPath).absolutePath(), &error))
        return failure(DependencyFailure, error, session);
    session.state = RecordingState::Starting;
    session.error = {};
    if (!persist(&session, &error))
        return failure(StateFailure, error, session);

    const GsrStartResult started = m_backend.start(session, m_store.logPath());
    if (!started.ok) {
        session = idleSession();
        session.error = started.error;
        persist(&session, nullptr);
        return failure(RecorderStartFailure, started.error, session);
    }

    session.state = RecordingState::Recording;
    session.pid = started.identity.pid;
    session.processStartTicks = started.identity.startTicks;
    session.processStartedAtMs = started.startedAtMs;
    session.startedAtMs = started.startedAtMs;
    session.coordinatorPid = 0;
    session.coordinatorStartTicks = 0;
    session.error = {};
    if (!persist(&session, &error)) {
        RecordingError stopError;
        m_backend.stop(started.identity, session.temporaryPath, &stopError);
        return failure(StateFailure, error, session);
    }

    OperationResult result;
    result.ok = true;
    result.exitCode = Success;
    result.session = session;
    return result;
}

OperationResult RecorderController::status()
{
    RecordingError error;
    RecordingSession session;
    bool exists = false;
    if (!m_store.read(&session, &exists, &error))
        return failure(StateFailure, error);
    if (!exists) {
        OperationResult result;
        result.ok = true;
        result.exitCode = Success;
        result.session = idleSession();
        return result;
    }

    bool changed = false;
    if ((session.state == RecordingState::Selecting
         || session.state == RecordingState::Starting)
        && !m_store.coordinatorMatches(session)) {
        session = idleSession();
        session.error = makeError(QStringLiteral("orphaned_start"),
                                  QStringLiteral("The recording start process is no longer running"));
        changed = true;
    } else if (session.state == RecordingState::Recording
               && !m_store.recorderMatches(session)) {
        session.state = RecordingState::Finalizing;
        session.pid = 0;
        session.error = makeError(
            QStringLiteral("recorder_exited"),
            QStringLiteral("The recorder exited unexpectedly; finalization is required"));
        changed = true;
    }

    if (changed) {
        std::unique_ptr<QLockFile> lock = m_store.acquireLock(&error, 250);
        if (lock && !persist(&session, &error))
            return failure(StateFailure, error, session);
    }

    OperationResult result;
    result.ok = true;
    result.exitCode = Success;
    result.session = session;
    return result;
}

OperationResult RecorderController::stop()
{
    RecordingError error;
    std::unique_ptr<QLockFile> lock = m_store.acquireLock(&error);
    if (!lock)
        return failure(error.code == QStringLiteral("recording_busy")
                           ? SessionConflict
                           : DependencyFailure,
                       error);

    RecordingSession session;
    bool exists = false;
    if (!m_store.read(&session, &exists, &error))
        return failure(StateFailure, error);
    if (!exists || session.state == RecordingState::Idle
        || session.state == RecordingState::Completed) {
        return failure(
            StateFailure,
            makeError(QStringLiteral("no_active_recording"),
                      QStringLiteral("There is no active Clavis recording session")),
            session);
    }
    if (session.state == RecordingState::Selecting
        || session.state == RecordingState::Starting) {
        return failure(
            StateFailure,
            makeError(QStringLiteral("recording_not_started"),
                      QStringLiteral("The region selection or recorder startup is still in progress")),
            session);
    }
    if (session.state == RecordingState::Finalizing)
        return finalize(session);

    const ProcessIdentity identity = m_store.recorderIdentity(session);
    if (m_store.recorderMatches(session)) {
        if (!m_backend.stop(identity, session.temporaryPath, &error))
            return failure(RecorderStopFailure, error, session);
    } else {
        session.error = makeError(
            QStringLiteral("recorder_exited"),
            QStringLiteral("The recorder was already gone; attempting to recover its output"));
    }

    session.state = RecordingState::Finalizing;
    session.pid = 0;
    if (!persist(&session, &error))
        return failure(StateFailure, error, session);
    return finalize(session);
}

OperationResult RecorderController::failure(int exitCode, const RecordingError &error,
                                            const RecordingSession &session) const
{
    OperationResult result;
    result.exitCode = exitCode;
    result.session = session;
    result.error = error;
    return result;
}

bool RecorderController::persist(RecordingSession *session, RecordingError *error)
{
    if (!session)
        return false;
    session->updatedAtMs = QDateTime::currentMSecsSinceEpoch();
    return m_store.write(*session, error);
}

bool RecorderController::prepareOutput(const StartOptions &options,
                                       RecordingSession *session,
                                       RecordingError *error) const
{
    if (!session)
        return false;
    QString outputDirectory = options.outputDirectory;
    if (outputDirectory.startsWith(QStringLiteral("~/")))
        outputDirectory.replace(0, 1, QDir::homePath());
    if (outputDirectory.isEmpty())
        outputDirectory = DependencyProbe::defaultOutputDirectory(options.type);
    outputDirectory = QDir::cleanPath(outputDirectory);
    if (!QDir().mkpath(outputDirectory) || !QFileInfo(outputDirectory).isWritable()) {
        if (error) {
            *error = makeError(QStringLiteral("output_directory_unwritable"),
                               QStringLiteral("Output directory is missing or not writable"),
                               {{QStringLiteral("path"), outputDirectory}});
        }
        return false;
    }

    if (!m_store.ensureRuntimeDirectory(error))
        return false;
    const QString stamp =
        QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"));
    const QString shortId = session->sessionId.left(8);
    const QString extension =
        options.type == RecordingType::Gif ? QStringLiteral("gif") : QStringLiteral("mp4");
    const QString prefix =
        options.type == RecordingType::Gif ? QStringLiteral("Clavis_GIF")
                                           : QStringLiteral("Clavis");
    session->outputPath =
        QDir(outputDirectory)
            .filePath(QStringLiteral("%1_%2_%3.%4").arg(prefix, stamp, shortId, extension));
    session->temporaryPath =
        QDir(m_store.runtimeDirectory())
            .filePath(QStringLiteral("%1.mkv").arg(session->sessionId));
    return true;
}

bool RecorderController::recordingDependenciesAvailable(const QString &outputDirectory,
                                                        RecordingError *error) const
{
    const QList<DependencyCheck> checks = m_dependencies.run(outputDirectory);
    QJsonArray missing;
    for (const DependencyCheck &check : checks) {
        if (check.name == QStringLiteral("niri-socket"))
            continue;
        if (!check.ok)
            missing.append(check.toJson());
    }
    if (missing.isEmpty())
        return true;
    if (error) {
        *error = makeError(QStringLiteral("dependency_check_failed"),
                           QStringLiteral("Recording dependencies are unavailable"),
                           {{QStringLiteral("checks"), missing}});
    }
    return false;
}

bool RecorderController::waitForFileToSettle(const QString &path, RecordingError *error,
                                             int timeoutMs) const
{
    QElapsedTimer timer;
    timer.start();
    qint64 previousSize = -1;
    int stableSamples = 0;
    while (timer.elapsed() < timeoutMs) {
        const QFileInfo info(path);
        const qint64 size = info.exists() ? info.size() : -1;
        if (size > 0 && size == previousSize) {
            if (++stableSamples >= 3)
                return true;
        } else {
            stableSamples = 0;
        }
        previousSize = size;
        QThread::msleep(150);
    }
    if (error) {
        *error = makeError(QStringLiteral("temporary_media_unsettled"),
                           QStringLiteral("Recorded media did not finish writing"),
                           {{QStringLiteral("path"), path}});
    }
    return false;
}

OperationResult RecorderController::finalize(RecordingSession session)
{
    RecordingError error;
    if (!waitForFileToSettle(session.temporaryPath, &error)) {
        session.error = error;
        persist(&session, nullptr);
        return failure(PostprocessFailure, error, session);
    }

    const PostprocessResult postprocess = m_postprocessor.finalize(session);
    if (!postprocess.ok) {
        session.error = postprocess.error;
        persist(&session, nullptr);
        return failure(PostprocessFailure, postprocess.error, session);
    }

    session.state = RecordingState::Completed;
    session.completedAtMs = QDateTime::currentMSecsSinceEpoch();
    session.pid = 0;
    session.processStartTicks = 0;
    session.processStartedAtMs = 0;
    session.temporaryPath.clear();
    session.error = {};
    if (!persist(&session, &error))
        return failure(StateFailure, error, session);

    OperationResult result;
    result.ok = true;
    result.exitCode = Success;
    result.session = session;

    // Keep the completed snapshot in the stop response, then return the
    // authoritative on-disk state to idle while retaining the last output.
    RecordingSession idle = session;
    idle.state = RecordingState::Idle;
    if (!persist(&idle, &error))
        return failure(StateFailure, error, session);
    return result;
}

} // namespace Clavis::Recording
