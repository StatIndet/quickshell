#pragma once

#include "audio_recording_types.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace Clavis::Recording {

struct AudioSourceResolution {
    bool ok = false;
    AudioSourceInfo source;
    RecordingError error;
};

class AudioSourceResolver {
public:
    AudioSourceResolution resolve(AudioSourceType type) const;

    static AudioSourceResolution resolveFromJson(AudioSourceType type,
                                                 const QJsonObject &serverInfo,
                                                 const QJsonArray &sources,
                                                 const QJsonArray &sinks);

private:
    static bool runPactl(const QStringList &arguments, QJsonDocument *document,
                         RecordingError *error);
};

} // namespace Clavis::Recording
