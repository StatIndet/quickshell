#pragma once

#include "command_result.h"

#include <QStringList>

class ClipboardCommand {
public:
    CommandResult run(const QStringList &arguments) const;
};
