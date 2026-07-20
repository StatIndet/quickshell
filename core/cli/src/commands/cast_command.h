#pragma once

#include "command_result.h"

#include <QStringList>

class CastCommand {
public:
    CommandResult run(const QStringList &arguments) const;
};
