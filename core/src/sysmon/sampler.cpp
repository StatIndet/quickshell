#include "sampler.h"

#include <unistd.h>
#include <time.h>

#include <algorithm>
#include <cmath>

namespace Clavis::Sysmon {

namespace {

qint64 monotonicNsecs()
{
    struct timespec value {};
    return ::clock_gettime(CLOCK_MONOTONIC, &value) == 0
        ? static_cast<qint64>(value.tv_sec) * 1'000'000'000
            + static_cast<qint64>(value.tv_nsec)
        : 0;
}

double elapsedSeconds(qint64 beforeNs, qint64 currentNs)
{
    if (beforeNs <= 0 || currentNs <= beforeNs)
        return 0.0;
    return static_cast<double>(currentNs - beforeNs) / 1'000'000'000.0;
}

OptionalNumber energyPower(const OptionalInteger &previous,
                           const OptionalInteger &current,
                           const OptionalInteger &range,
                           double seconds)
{
    if (!previous || !current || seconds <= 0.0)
        return std::nullopt;
    qint64 delta = *current - *previous;
    if (delta < 0 && range && *range > 0)
        delta = (*range - *previous) + *current;
    if (delta < 0)
        return std::nullopt;
    return static_cast<double>(delta) / 1'000'000.0 / seconds;
}

} // namespace

Sampler::Sampler() = default;

Snapshot Sampler::sample(const ModuleSet &modules)
{
    Snapshot snapshot;
    snapshot.timestampMs = QDateTime::currentMSecsSinceEpoch();
    snapshot.sequence = ++m_sequence;
    snapshot.requestedModules = modules;

    const qint64 sampleStartedNs = monotonicNsecs();
    if (m_lastSampleNs > 0 && sampleStartedNs > m_lastSampleNs) {
        snapshot.intervalMs =
            (sampleStartedNs - m_lastSampleNs) / 1'000'000;
    }
    m_lastSampleNs = sampleStartedNs;

    RawSnapshot raw = m_collector.collect(modules);
    const qint64 sampleFinishedNs = monotonicNsecs();
    snapshot.errors = std::move(raw.errors);

    if (modules.contains(QStringLiteral("system")))
        snapshot.system = std::move(raw.system);

    if (modules.contains(QStringLiteral("cpu"))) {
        const qint64 cpuTimestampNs = raw.cpuTimestampNs > 0
            ? raw.cpuTimestampNs
            : sampleFinishedNs;
        snapshot.cpu = calculateCpuInfo(m_previousCpu, raw.cpu.counters);
        snapshot.cpu.frequencyCurrentMHz = raw.cpu.frequencyCurrentMHz;
        snapshot.cpu.frequencyAverageMHz = raw.cpu.frequencyAverageMHz;
        snapshot.cpu.frequencyMinMHz = raw.cpu.frequencyMinMHz;
        snapshot.cpu.frequencyMaxMHz = raw.cpu.frequencyMaxMHz;
        snapshot.cpu.temperatureCelsius = raw.cpu.temperatureCelsius;
        snapshot.cpu.packageTemperatureCelsius =
            raw.cpu.packageTemperatureCelsius;
        const double seconds =
            elapsedSeconds(m_previousCpuNs, cpuTimestampNs);
        snapshot.cpu.powerWatts = energyPower(
            m_previousEnergyMicroJoules,
            raw.cpu.packageEnergyMicroJoules,
            raw.cpu.packageEnergyRangeMicroJoules
                ? raw.cpu.packageEnergyRangeMicroJoules
                : m_previousEnergyRangeMicroJoules,
            seconds);
        snapshot.cpu.fanRpm = raw.cpu.fanRpm;
        m_previousCpu = raw.cpu.counters;
        m_previousCpuNs = cpuTimestampNs;
        m_previousEnergyMicroJoules = raw.cpu.packageEnergyMicroJoules;
        m_previousEnergyRangeMicroJoules =
            raw.cpu.packageEnergyRangeMicroJoules;
    }

    if (modules.contains(QStringLiteral("memory")))
        snapshot.memory = calculateMemoryInfo(raw.memory);

    if (modules.contains(QStringLiteral("gpu")))
        snapshot.gpus = std::move(raw.gpus);

    if (modules.contains(QStringLiteral("disk"))) {
        const qint64 diskTimestampNs = raw.diskTimestampNs > 0
            ? raw.diskTimestampNs
            : sampleFinishedNs;
        const double seconds =
            elapsedSeconds(m_previousDiskNs, diskTimestampNs);
        QHash<QString, DiskCounter> next;
        snapshot.disks.reserve(raw.disks.size());
        for (RawDiskInfo &rawDisk : raw.disks) {
            if (rawDisk.counters && !rawDisk.counterKey.isEmpty()) {
                next.insert(rawDisk.counterKey, *rawDisk.counters);
                const auto previous = m_previousDisks.constFind(rawDisk.counterKey);
                if (previous != m_previousDisks.cend() && seconds > 0.0) {
                    rawDisk.info.readBytesPerSecond = counterRate(
                        previous->sectorsRead,
                        rawDisk.counters->sectorsRead,
                        seconds);
                    rawDisk.info.writeBytesPerSecond = counterRate(
                        previous->sectorsWritten,
                        rawDisk.counters->sectorsWritten,
                        seconds);
                    if (rawDisk.info.readBytesPerSecond)
                        *rawDisk.info.readBytesPerSecond *= 512.0;
                    if (rawDisk.info.writeBytesPerSecond)
                        *rawDisk.info.writeBytesPerSecond *= 512.0;
                    rawDisk.info.readIops = counterRate(
                        previous->readsCompleted,
                        rawDisk.counters->readsCompleted,
                        seconds);
                    rawDisk.info.writeIops = counterRate(
                        previous->writesCompleted,
                        rawDisk.counters->writesCompleted,
                        seconds);
                }
            }
            snapshot.disks.push_back(std::move(rawDisk.info));
        }
        m_previousDisks = std::move(next);
        m_previousDiskNs = diskTimestampNs;
    }

    if (modules.contains(QStringLiteral("network"))) {
        const qint64 networkTimestampNs = raw.networkTimestampNs > 0
            ? raw.networkTimestampNs
            : sampleFinishedNs;
        snapshot.network.available = !raw.networkInterfaces.isEmpty();
        snapshot.network.defaultInterface = raw.defaultNetworkInterface;
        const double seconds =
            elapsedSeconds(m_previousNetworkNs, networkTimestampNs);
        QHash<QString, NetworkCounter> next;
        double aggregateDownload = 0.0;
        double aggregateUpload = 0.0;
        bool aggregateDownloadReady = false;
        bool aggregateUploadReady = false;
        snapshot.network.interfaces.reserve(raw.networkInterfaces.size());

        for (RawNetworkInterfaceInfo &rawInterface : raw.networkInterfaces) {
            const QString cursorKey =
                rawInterface.info.name + QLatin1Char('#')
                + QString::number(rawInterface.info.ifIndex);
            next.insert(cursorKey, rawInterface.counters);
            const auto previous =
                m_previousNetwork.constFind(cursorKey);
            if (previous != m_previousNetwork.cend() && seconds > 0.0) {
                rawInterface.info.downloadBytesPerSecond = counterRate(
                    previous->receiveBytes,
                    rawInterface.counters.receiveBytes,
                    seconds);
                rawInterface.info.uploadBytesPerSecond = counterRate(
                    previous->transmitBytes,
                    rawInterface.counters.transmitBytes,
                    seconds);
            }
            if (!rawInterface.info.loopback) {
                snapshot.network.downloadTotalBytes +=
                    rawInterface.info.downloadTotalBytes;
                snapshot.network.uploadTotalBytes +=
                    rawInterface.info.uploadTotalBytes;
                if (rawInterface.info.downloadBytesPerSecond) {
                    aggregateDownload +=
                        *rawInterface.info.downloadBytesPerSecond;
                    aggregateDownloadReady = true;
                }
                if (rawInterface.info.uploadBytesPerSecond) {
                    aggregateUpload += *rawInterface.info.uploadBytesPerSecond;
                    aggregateUploadReady = true;
                }
            }
            snapshot.network.interfaces.push_back(
                std::move(rawInterface.info));
        }
        for (const NetworkInterfaceInfo &interface :
             snapshot.network.interfaces) {
            if (!interface.wireless)
                continue;
            snapshot.network.wifiAvailable = true;
            if (interface.up)
                snapshot.network.wifiConnected = true;
        }
        if (aggregateDownloadReady)
            snapshot.network.downloadBytesPerSecond = aggregateDownload;
        if (aggregateUploadReady)
            snapshot.network.uploadBytesPerSecond = aggregateUpload;
        m_previousNetwork = std::move(next);
        m_previousNetworkNs = networkTimestampNs;
    }

    if (modules.contains(QStringLiteral("battery")))
        snapshot.battery = std::move(raw.battery);

    if (modules.contains(QStringLiteral("processes"))) {
        const qint64 processTimestampNs = raw.processTimestampNs > 0
            ? raw.processTimestampNs
            : sampleFinishedNs;
        const double seconds =
            elapsedSeconds(m_previousProcessNs, processTimestampNs);
        const long ticksPerSecond = ::sysconf(_SC_CLK_TCK);
        QHash<qint64, ProcessCursor> next;
        snapshot.processes.reserve(raw.processes.size());
        for (RawProcessInfo &rawProcess : raw.processes) {
            const ProcessCursor cursor{
                rawProcess.cpuTicks,
                rawProcess.startTicks,
            };
            next.insert(rawProcess.info.pid, cursor);
            const auto previous =
                m_previousProcesses.constFind(rawProcess.info.pid);
            if (previous != m_previousProcesses.cend()
                && previous->startTicks == rawProcess.startTicks
                && rawProcess.cpuTicks >= previous->ticks
                && seconds > 0.0
                && ticksPerSecond > 0) {
                rawProcess.info.cpuUsagePercent = processCpuPercent(
                    previous->ticks,
                    rawProcess.cpuTicks,
                    ticksPerSecond,
                    seconds);
            }
            snapshot.processes.push_back(std::move(rawProcess.info));
        }
        m_previousProcesses = std::move(next);
        m_previousProcessNs = processTimestampNs;
        std::stable_sort(
            snapshot.processes.begin(),
            snapshot.processes.end(),
            [](const ProcessInfo &left, const ProcessInfo &right) {
                return left.cpuUsagePercent.value_or(-1.0)
                    > right.cpuUsagePercent.value_or(-1.0);
            });
    }

    return snapshot;
}

} // namespace Clavis::Sysmon
