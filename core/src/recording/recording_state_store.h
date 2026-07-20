#pragma once

#include "process_identity.h"
#include "recording_types.h"

#include <QLockFile>
#include <memory>

namespace Clavis::Recording {

class RecordingStateStore {
public:
    QString runtimeDirectory() const;
    QString sessionPath() const;
    QString lockPath() const;
    QString logPath() const;

    bool ensureRuntimeDirectory(RecordingError *error = nullptr) const;
    std::unique_ptr<QLockFile> acquireLock(RecordingError *error = nullptr,
                                           int timeoutMs = 2000) const;
    bool read(RecordingSession *session, bool *exists = nullptr,
              RecordingError *error = nullptr) const;
    bool write(RecordingSession session, RecordingError *error = nullptr) const;

    ProcessIdentity recorderIdentity(const RecordingSession &session) const;
    ProcessIdentity coordinatorIdentity(const RecordingSession &session) const;
    bool recorderMatches(const RecordingSession &session) const;
    bool coordinatorMatches(const RecordingSession &session) const;
};

} // namespace Clavis::Recording
