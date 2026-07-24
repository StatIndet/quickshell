#pragma once

#include "types.h"

#include <QByteArray>
#include <QHash>
#include <QString>
#include <QVector>

#include <optional>

namespace Clavis::Sysmon {

struct CpuTimes {
    quint64 user = 0;
    quint64 nice = 0;
    quint64 system = 0;
    quint64 idle = 0;
    quint64 iowait = 0;
    quint64 irq = 0;
    quint64 softirq = 0;
    quint64 steal = 0;

    quint64 total() const;
    quint64 idleTotal() const;
};

struct CpuCounters {
    struct Core {
        int id = -1;
        CpuTimes times;
    };

    CpuTimes total;
    QVector<Core> cores;
    bool valid = false;
};

struct MemoryCounters {
    quint64 memTotalKiB = 0;
    quint64 memAvailableKiB = 0;
    quint64 memFreeKiB = 0;
    quint64 cachedKiB = 0;
    quint64 buffersKiB = 0;
    quint64 swapTotalKiB = 0;
    quint64 swapFreeKiB = 0;
    bool valid = false;
};

struct NetworkCounter {
    quint64 receiveBytes = 0;
    quint64 transmitBytes = 0;
};

struct DiskCounter {
    quint64 readsCompleted = 0;
    quint64 sectorsRead = 0;
    quint64 writesCompleted = 0;
    quint64 sectorsWritten = 0;
};

struct ProcessStat {
    qint64 pid = 0;
    QString name;
    QChar state;
    qint64 ppid = 0;
    quint64 userTicks = 0;
    quint64 systemTicks = 0;
    int threadCount = 0;
    quint64 startTicks = 0;
    bool valid = false;
};

CpuCounters parseProcStat(const QByteArray &contents);
OptionalInteger parseProcBootTimeMs(const QByteArray &contents);
MemoryCounters parseMeminfo(const QByteArray &contents);
QHash<QString, NetworkCounter> parseProcNetDev(const QByteArray &contents);
QString parseDefaultRouteInterface(const QByteArray &ipv4Routes,
                                   const QByteArray &ipv6Routes);
QString composeDeviceCursorKey(const QString &name,
                               const QString &generation,
                               const QString &fallbackIdentity);
std::optional<DiskCounter> parseDiskStatLine(const QByteArray &contents);
ProcessStat parseProcessStat(const QByteArray &contents);

OptionalNumber percentageDelta(quint64 previousPart,
                               quint64 currentPart,
                               quint64 previousTotal,
                               quint64 currentTotal);
OptionalNumber counterRate(quint64 previous, quint64 current, double elapsedSeconds);
OptionalNumber processCpuPercent(quint64 previousTicks,
                                 quint64 currentTicks,
                                 long ticksPerSecond,
                                 double elapsedSeconds);
CpuInfo calculateCpuInfo(const CpuCounters &previous, const CpuCounters &current);
MemoryInfo calculateMemoryInfo(const MemoryCounters &counters);

} // namespace Clavis::Sysmon
