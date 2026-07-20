#pragma once

#include "command_result.h"

#include <QStringList>

class DoctorCommand {
public:
    CommandResult run(const QStringList &arguments) const;
};
