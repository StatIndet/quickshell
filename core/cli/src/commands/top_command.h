#pragma once

#include "command_result.h"

#include <QStringList>

class TopCommand {
public:
    CommandResult run(const QStringList &arguments) const;

    static QString helpText();
};
