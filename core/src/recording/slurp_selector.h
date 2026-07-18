#pragma once

#include "recording_types.h"

#include <QString>

namespace Clavis::Recording {

struct SelectionResult {
    bool ok = false;
    bool cancelled = false;
    QString geometry;
    RecordingError error;
};

class SlurpSelector {
public:
    SelectionResult selectRegion(int timeoutMs = 300000) const;
    static bool normalizeGeometry(const QString &value, QString *normalized = nullptr);
};

} // namespace Clavis::Recording
