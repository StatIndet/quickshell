#pragma once

#include "audio_recording_types.h"
#include "recording/process_identity.h"

#include <QLockFile>
#include <memory>

namespace Clavis::Recording {

class AudioRecordingStateStore {
public:
    QString runtimeDirectory() const;
    QString sessionPath() const;
    QString lockPath() const;
    QString logPath() const;

    bool ensureRuntimeDirectory(RecordingError *error = nullptr) const;
    std::unique_ptr<QLockFile> acquireLock(RecordingError *error = nullptr,
                                           int timeoutMs = 2000) const;
    bool read(AudioRecordingSession *session, bool *exists = nullptr,
              RecordingError *error = nullptr) const;
    bool write(AudioRecordingSession session, RecordingError *error = nullptr) const;

    ProcessIdentity recorderIdentity(const AudioRecordingSession &session) const;
    ProcessIdentity coordinatorIdentity(const AudioRecordingSession &session) const;
    bool recorderMatches(const AudioRecordingSession &session) const;
    bool coordinatorMatches(const AudioRecordingSession &session) const;
};

} // namespace Clavis::Recording
