#pragma once

#include "recording_types.h"

#include <QLockFile>
#include <memory>

namespace Clavis::Recording {

struct CaptureConflict {
    bool active = false;
    QString kind;
    QString state;
    QString sessionId;

    QJsonObject toJson() const;
};

class CaptureSessionGuard {
public:
    QString baseDirectory() const;
    QString lockPath() const;

    std::unique_ptr<QLockFile> acquire(RecordingError *error = nullptr,
                                       int timeoutMs = 2000) const;
    CaptureConflict conflictExcluding(const QString &kind) const;

private:
    CaptureConflict inspect(const QString &kind, const QString &path) const;
};

} // namespace Clavis::Recording
