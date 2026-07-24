#pragma once

#include "command_result.h"

#include <QStringList>

class SysmonCommand {
public:
    CommandResult run(const QStringList &arguments) const;
    static QString helpText();
};
