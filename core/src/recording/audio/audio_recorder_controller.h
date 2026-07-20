#pragma once

#include "audio_file_finalizer.h"
#include "audio_recording_state_store.h"
#include "audio_source_resolver.h"
#include "ffmpeg_audio_backend.h"
#include "recording/capture_session_guard.h"

namespace Clavis::Recording {

class AudioRecorderController {
public:
    AudioOperationResult start(const AudioStartOptions &options);
    AudioOperationResult status();
    AudioOperationResult stop();

private:
    AudioRecordingStateStore m_store;
    AudioSourceResolver m_sourceResolver;
    FfmpegAudioBackend m_backend;
    AudioFileFinalizer m_finalizer;
    CaptureSessionGuard m_captureGuard;

    AudioOperationResult failure(int exitCode, const RecordingError &error,
                                 const AudioRecordingSession &session =
                                     idleAudioSession()) const;
    bool persist(AudioRecordingSession *session, RecordingError *error = nullptr);
    bool prepareOutput(const AudioStartOptions &options,
                       AudioRecordingSession *session,
                       RecordingError *error) const;
    bool dependenciesAvailable(RecordingError *error) const;
    AudioOperationResult finalize(AudioRecordingSession session);
    void recoverInterrupted(AudioRecordingSession *session);
    static void clearProcess(AudioRecordingSession *session);
};

} // namespace Clavis::Recording
