#include "sysmon_backend.h"

#include <QLocale>

#include <algorithm>

using namespace Clavis::Sysmon;

SysmonBackend& SysmonBackend::instance() {
    static SysmonBackend inst;
    return inst;
}

SysmonBackend::SysmonBackend(QObject* parent) : QObject(parent) {
    updateFast();
    updateMedium();
    updateSlow();
    updateGlacial();
}

void SysmonBackend::mergeSnapshot(Snapshot snapshot) {
    for (const QString &module : std::as_const(snapshot.requestedModules)) {
        if (module == QStringLiteral("system"))
            m_snapshot.system = std::move(snapshot.system);
        else if (module == QStringLiteral("cpu"))
            m_snapshot.cpu = std::move(snapshot.cpu);
        else if (module == QStringLiteral("memory"))
            m_snapshot.memory = std::move(snapshot.memory);
        else if (module == QStringLiteral("gpu"))
            m_snapshot.gpus = std::move(snapshot.gpus);
        else if (module == QStringLiteral("disk"))
            m_snapshot.disks = std::move(snapshot.disks);
        else if (module == QStringLiteral("network"))
            m_snapshot.network = std::move(snapshot.network);
        else if (module == QStringLiteral("battery"))
            m_snapshot.battery = std::move(snapshot.battery);
    }
    m_snapshot.timestampMs = snapshot.timestampMs;
    m_snapshot.sequence = snapshot.sequence;
    m_snapshot.intervalMs = snapshot.intervalMs;
    m_snapshot.errors = std::move(snapshot.errors);
}

void SysmonBackend::updateFast() {
    mergeSnapshot(m_sampler.sample({
        QStringLiteral("cpu"),
        QStringLiteral("memory"),
        QStringLiteral("network"),
    }));
}

void SysmonBackend::updateMedium() {
    mergeSnapshot(m_sampler.sample({
        QStringLiteral("system"),
        QStringLiteral("gpu"),
    }));
}

void SysmonBackend::updateSlow() {
    mergeSnapshot(m_sampler.sample({QStringLiteral("battery")}));
}

void SysmonBackend::updateGlacial() {
    mergeSnapshot(m_sampler.sample({
        QStringLiteral("disk"),
        QStringLiteral("system"),
    }));
}

// --- Existing getters ---

double SysmonBackend::getGlobalCpuUsage() const { 
    return m_snapshot.cpu.usagePercent.value_or(0.0);
}

std::vector<::ProcessInfo> SysmonBackend::getTopProcesses(int limit) const {
    const Snapshot snapshot = m_sampler.sample({
        QStringLiteral("system"),
        QStringLiteral("memory"),
        QStringLiteral("processes"),
    });
    std::vector<::ProcessInfo> result;
    const int count = std::min(
        limit, static_cast<int>(snapshot.processes.size()));
    result.reserve(static_cast<size_t>(std::max(0, count)));
    for (int index = 0; index < count; ++index) {
        const Clavis::Sysmon::ProcessInfo &process =
            snapshot.processes.at(index);
        result.push_back({
            static_cast<int>(process.pid),
            -1,
            process.name,
            process.command,
            process.cpuUsagePercent.value_or(0.0),
            process.memoryBytes / 1024ULL,
            process.memoryPercent.value_or(0.0),
        });
    }
    return result;
}

double SysmonBackend::getRamUsagePercent() const { 
    return m_snapshot.memory.usagePercent.value_or(0.0);
}

double SysmonBackend::getRamUsedGB() const { 
    return static_cast<double>(m_snapshot.memory.usedBytes)
        / (1024.0 * 1024.0 * 1024.0);
}

double SysmonBackend::getRamTotalGB() const {
    return static_cast<double>(m_snapshot.memory.totalBytes)
        / (1024.0 * 1024.0 * 1024.0);
}

double SysmonBackend::getDiskUsagePercent() const { 
    for (const DiskInfo &disk : m_snapshot.disks) {
        if (disk.mountPoint == QStringLiteral("/"))
            return disk.usagePercent.value_or(0.0);
    }
    return m_snapshot.disks.isEmpty()
        ? 0.0
        : m_snapshot.disks.first().usagePercent.value_or(0.0);
}

double SysmonBackend::getDiskUsedGB() const {
    for (const DiskInfo &disk : m_snapshot.disks) {
        if (disk.mountPoint == QStringLiteral("/"))
            return static_cast<double>(disk.usedBytes)
                / (1024.0 * 1024.0 * 1024.0);
    }
    return 0.0;
}

double SysmonBackend::getDiskTotalGB() const {
    for (const DiskInfo &disk : m_snapshot.disks) {
        if (disk.mountPoint == QStringLiteral("/"))
            return static_cast<double>(disk.totalBytes)
                / (1024.0 * 1024.0 * 1024.0);
    }
    return 0.0;
}

double SysmonBackend::getCoreTempCelsius() const { 
    return m_snapshot.cpu.packageTemperatureCelsius.value_or(
        m_snapshot.cpu.temperatureCelsius.value_or(0.0));
}

// --- Network ---
double SysmonBackend::getNetDownBps() const {
    return m_snapshot.network.downloadBytesPerSecond.value_or(0.0);
}
double SysmonBackend::getNetUpBps() const {
    return m_snapshot.network.uploadBytesPerSecond.value_or(0.0);
}

// --- Battery ---
double SysmonBackend::getBatteryPercent() const {
    return m_snapshot.battery.chargePercent.value_or(0.0);
}
QString SysmonBackend::getBatteryStatus() const { return m_snapshot.battery.status; }
int SysmonBackend::getBatteryHealth() const {
    return static_cast<int>(m_snapshot.battery.healthPercent.value_or(0.0));
}
double SysmonBackend::getBatteryPowerW() const {
    return m_snapshot.battery.powerWatts.value_or(0.0);
}
bool SysmonBackend::hasBattery() const { return m_snapshot.battery.present; }

// --- GPU ---
double SysmonBackend::getGpuUsagePercent() const {
    return m_snapshot.gpus.isEmpty()
        ? 0.0
        : m_snapshot.gpus.first().utilizationPercent.value_or(0.0);
}
double SysmonBackend::getGpuTempCelsius() const {
    return m_snapshot.gpus.isEmpty()
        ? 0.0
        : m_snapshot.gpus.first().temperatureCelsius.value_or(0.0);
}

// --- Misc ---
int SysmonBackend::getFanRpm() const {
    return static_cast<int>(m_snapshot.cpu.fanRpm.value_or(0.0));
}
double SysmonBackend::getCpuFreqGHz() const {
    return m_snapshot.cpu.frequencyCurrentMHz.value_or(0.0) / 1000.0;
}
QString SysmonBackend::getUptime() const {
    qint64 seconds = m_snapshot.system.uptimeSeconds;
    const qint64 days = seconds / 86400;
    const qint64 hours = (seconds % 86400) / 3600;
    const qint64 minutes = (seconds % 3600) / 60;
    if (days > 0)
        return QStringLiteral("%1d %2h").arg(days).arg(hours);
    if (hours > 0)
        return QStringLiteral("%1h %2m").arg(hours).arg(minutes);
    return QStringLiteral("%1m").arg(minutes);
}
QString SysmonBackend::getSystemUser() const { return m_snapshot.system.systemUser; }
QString SysmonBackend::getHostName() const { return m_snapshot.system.hostName; }
QString SysmonBackend::getWmName() const { return m_snapshot.system.wmName; }
QString SysmonBackend::getKernelRelease() const { return m_snapshot.system.kernel; }
QString SysmonBackend::getShellName() const { return m_snapshot.system.shellName; }
QString SysmonBackend::getDistroId() const { return m_snapshot.system.distroId; }
QString SysmonBackend::getDistroName() const { return m_snapshot.system.osName; }
QString SysmonBackend::getChassis() const {
    return m_snapshot.system.chassis.isEmpty()
        ? QStringLiteral("Computer")
        : m_snapshot.system.chassis;
}
QString SysmonBackend::getOsAgeText() const {
    return m_snapshot.system.osAgeText.isEmpty()
        ? QStringLiteral("Unknown")
        : m_snapshot.system.osAgeText;
}
