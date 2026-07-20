#pragma once

#include "audio_recording_types.h"
#include "recording/process_identity.h"

#include <QStringList>

namespace Clavis::Recording {

struct AudioBackendStartResult {
    bool ok = false;
    ProcessIdentity identity;
    qint64 startedAtMs = 0;
    QStringList arguments;
    RecordingError error;
};

struct AudioBackendStopResult {
    bool ok = false;
    bool forced = false;
    RecordingError error;
};

class FfmpegAudioBackend {
public:
    AudioBackendStartResult start(const AudioRecordingSession &session,
                                  const QString &logPath) const;
    AudioBackendStopResult stop(const ProcessIdentity &identity,
                                const QString &temporaryPath,
                                int interruptTimeoutMs = 15000,
                                int terminateTimeoutMs = 3000,
                                int killTimeoutMs = 1000) const;
    QStringList buildArguments(const AudioRecordingSession &session) const;
    static QString logTail(const QString &logPath, qsizetype maximumBytes = 8192);

private:
    static bool waitForExit(const ProcessIdentity &identity, int timeoutMs);
};

} // namespace Clavis::Recording
