#pragma once

#include "command_result.h"
#include "recording/audio/audio_recording_types.h"

class AudioCommand {
public:
    CommandResult run(const QStringList &arguments) const;

private:
    static CommandResult fromOperation(
        const QString &command,
        const Clavis::Recording::AudioOperationResult &operation,
        bool jsonRequested);
    static CommandResult usageError(const QString &command,
                                    const QString &message,
                                    bool jsonRequested);
};
