#pragma once

#include "audio_recording_types.h"

namespace Clavis::Recording {

struct AudioFinalizeResult {
    bool ok = false;
    RecordingError error;
};

class AudioFileFinalizer {
public:
    AudioFinalizeResult finalize(const AudioRecordingSession &session) const;
    bool validate(const QString &path, RecordingError *error = nullptr) const;
};

} // namespace Clavis::Recording
