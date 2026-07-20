#pragma once

#include "capture_session_guard.h"
#include "dependency_probe.h"
#include "ffmpeg_postprocessor.h"
#include "gsr_backend.h"
#include "recording_state_store.h"

namespace Clavis::Recording {

class RecorderController {
public:
    OperationResult start(const StartOptions &options);
    OperationResult status();
    OperationResult stop();

private:
    RecordingStateStore m_store;
    CaptureSessionGuard m_captureGuard;
    GsrBackend m_backend;
    FfmpegPostprocessor m_postprocessor;
    DependencyProbe m_dependencies;

    OperationResult failure(int exitCode, const RecordingError &error,
                            const RecordingSession &session = idleSession()) const;
    bool persist(RecordingSession *session, RecordingError *error);
    bool prepareOutput(const StartOptions &options, RecordingSession *session,
                       RecordingError *error) const;
    bool recordingDependenciesAvailable(const QString &outputDirectory,
                                        RecordingError *error) const;
    bool waitForFileToSettle(const QString &path, RecordingError *error,
                             int timeoutMs = 10000) const;
    OperationResult finalize(RecordingSession session);
};

} // namespace Clavis::Recording
