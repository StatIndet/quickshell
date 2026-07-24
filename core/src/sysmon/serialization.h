#pragma once

#include "types.h"

#include <QByteArray>
#include <QJsonObject>
#include <QString>

namespace Clavis::Sysmon {

QJsonObject snapshotToJson(const Snapshot &snapshot);
QByteArray snapshotToJsonLine(const Snapshot &snapshot);
QString humanSnapshot(const Snapshot &snapshot);

} // namespace Clavis::Sysmon
