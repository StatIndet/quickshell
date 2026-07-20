#pragma once

#include "command_result.h"
#include "recording/recording_types.h"

#include <QStringList>

class RecordCommand {
public:
    CommandResult run(const QStringList &arguments) const;

private:
    static CommandResult fromOperation(const QString &command,
                                       const Clavis::Recording::OperationResult &operation,
                                       bool jsonRequested);
    static CommandResult usageError(const QString &command, const QString &message,
                                    bool jsonRequested);
};
