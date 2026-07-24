#pragma once

#include "collector.h"
#include "types.h"

#include <QHash>

#include <optional>

namespace Clavis::Sysmon {

class Sampler {
public:
    Sampler();

    Snapshot sample(const ModuleSet &modules = defaultModules());

private:
    struct ProcessCursor {
        quint64 ticks = 0;
        quint64 startTicks = 0;
    };

    LinuxCollector m_collector;
    quint64 m_sequence = 0;
    qint64 m_lastSampleNs = 0;

    CpuCounters m_previousCpu;
    qint64 m_previousCpuNs = 0;
    OptionalInteger m_previousEnergyMicroJoules;
    OptionalInteger m_previousEnergyRangeMicroJoules;

    QHash<QString, NetworkCounter> m_previousNetwork;
    qint64 m_previousNetworkNs = 0;

    QHash<QString, DiskCounter> m_previousDisks;
    qint64 m_previousDiskNs = 0;

    QHash<qint64, ProcessCursor> m_previousProcesses;
    qint64 m_previousProcessNs = 0;
};

} // namespace Clavis::Sysmon
