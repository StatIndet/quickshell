#pragma once

#include "process_identity.h"
#include "recording_types.h"

#include <QStringList>

namespace Clavis::Recording {

struct GsrStartResult {
    bool ok = false;
    ProcessIdentity identity;
    qint64 startedAtMs = 0;
    QStringList arguments;
    RecordingError error;
};

class GsrBackend {
public:
    GsrStartResult start(const RecordingSession &session, const QString &logPath) const;
    bool stop(const ProcessIdentity &identity, const QString &temporaryPath,
              RecordingError *error = nullptr, int timeoutMs = 30000) const;
    QStringList buildArguments(const RecordingSession &session) const;
    static QString logTail(const QString &logPath, qsizetype maximumBytes = 8192);
};

} // namespace Clavis::Recording
