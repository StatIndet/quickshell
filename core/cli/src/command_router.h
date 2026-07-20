#pragma once

#include "command_result.h"

#include <QStringList>

class CommandRouter {
public:
    CommandResult route(const QStringList &arguments) const;
    static QString helpText();

private:
    static CommandResult usageError(const QString &message, bool jsonRequested = false);
};
