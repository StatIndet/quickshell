#pragma once

#include "recording_types.h"

namespace Clavis::Recording {

struct PostprocessResult {
    bool ok = false;
    QString outputPath;
    RecordingError error;
};

class FfmpegPostprocessor {
public:
    PostprocessResult finalize(const RecordingSession &session,
                               int timeoutMs = 300000) const;
    bool validateMedia(const QString &path, RecordingError *error = nullptr,
                       int timeoutMs = 30000) const;

private:
    PostprocessResult finalizeVideo(const RecordingSession &session,
                                    int timeoutMs) const;
    PostprocessResult finalizeGif(const RecordingSession &session,
                                  int timeoutMs) const;
    bool runFfmpeg(const QStringList &arguments, RecordingError *error,
                   int timeoutMs) const;
    static QString partialPath(const QString &outputPath);
    static bool publishFile(const QString &partial, const QString &output,
                            RecordingError *error);
};

} // namespace Clavis::Recording
