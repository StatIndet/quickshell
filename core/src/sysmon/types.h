#pragma once

#include <QDateTime>
#include <QHash>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVector>

#include <optional>

namespace Clavis::Sysmon {

inline constexpr int SchemaVersion = 1;

using OptionalNumber = std::optional<double>;
using OptionalInteger = std::optional<qint64>;
using ModuleSet = QSet<QString>;

struct Error {
    QString module;
    QString code;
    QString message;
};

struct SystemInfo {
    bool available = false;
    QString hostName;
    QString osName;
    QString distroId;
    QString kernel;
    QString architecture;
    qint64 uptimeSeconds = 0;
    qint64 bootTimeMs = 0;
    int logicalCpuCount = 0;
    int physicalCoreCount = 0;
    QString cpuModelName;
    QString vendor;
    QString productName;
    QString boardName;
    QString biosVersion;
    QString systemUser;
    QString wmName;
    QString shellName;
    QString chassis;
    QString osAgeText;
};

struct CpuInfo {
    bool available = false;
    bool sampleReady = false;
    OptionalNumber usagePercent;
    OptionalNumber userPercent;
    OptionalNumber systemPercent;
    OptionalNumber idlePercent;
    OptionalNumber iowaitPercent;
    QVector<int> coreIds;
    QVector<OptionalNumber> coreUsagePercent;
    OptionalNumber frequencyCurrentMHz;
    OptionalNumber frequencyAverageMHz;
    OptionalNumber frequencyMinMHz;
    OptionalNumber frequencyMaxMHz;
    OptionalNumber temperatureCelsius;
    OptionalNumber packageTemperatureCelsius;
    OptionalNumber powerWatts;
    OptionalNumber fanRpm;
};

struct MemoryInfo {
    bool available = false;
    quint64 totalBytes = 0;
    quint64 usedBytes = 0;
    quint64 availableBytes = 0;
    quint64 freeBytes = 0;
    quint64 cachedBytes = 0;
    quint64 buffersBytes = 0;
    quint64 swapTotalBytes = 0;
    quint64 swapUsedBytes = 0;
    OptionalNumber usagePercent;
};

struct GpuInfo {
    bool available = false;
    bool supported = false;
    QString id;
    QString pciId;
    QString name;
    QString vendor;
    QString driver;
    OptionalNumber utilizationPercent;
    OptionalNumber temperatureCelsius;
    OptionalInteger vramTotalBytes;
    OptionalInteger vramUsedBytes;
    OptionalNumber powerWatts;
    OptionalNumber frequencyMHz;
};

struct DiskInfo {
    bool available = false;
    QString mountPoint;
    QString filesystem;
    QString device;
    quint64 totalBytes = 0;
    quint64 usedBytes = 0;
    quint64 freeBytes = 0;
    OptionalNumber usagePercent;
    OptionalNumber readBytesPerSecond;
    OptionalNumber writeBytesPerSecond;
    OptionalNumber readIops;
    OptionalNumber writeIops;
};

struct NetworkInterfaceInfo {
    bool available = false;
    QString name;
    int ifIndex = 0;
    bool up = false;
    bool loopback = false;
    bool wireless = false;
    quint64 downloadTotalBytes = 0;
    quint64 uploadTotalBytes = 0;
    OptionalNumber downloadBytesPerSecond;
    OptionalNumber uploadBytesPerSecond;
};

struct NetworkInfo {
    bool available = false;
    QString defaultInterface;
    bool wifiAvailable = false;
    bool wifiConnected = false;
    quint64 downloadTotalBytes = 0;
    quint64 uploadTotalBytes = 0;
    OptionalNumber downloadBytesPerSecond;
    OptionalNumber uploadBytesPerSecond;
    QVector<NetworkInterfaceInfo> interfaces;
};

struct BatteryInfo {
    bool available = false;
    bool supported = true;
    bool present = false;
    QString name;
    QString status;
    OptionalNumber chargePercent;
    OptionalNumber powerWatts;
    OptionalInteger timeRemainingSeconds;
    std::optional<bool> acOnline;
    OptionalNumber healthPercent;
    OptionalInteger energyNowMicroWh;
    OptionalInteger energyFullMicroWh;
    OptionalInteger energyDesignMicroWh;
};

struct ProcessInfo {
    qint64 pid = 0;
    qint64 ppid = 0;
    QString name;
    QString command;
    QString user;
    QString state;
    OptionalNumber cpuUsagePercent;
    quint64 memoryBytes = 0;
    OptionalNumber memoryPercent;
    int threadCount = 0;
    qint64 startTimeMs = 0;
    qint64 runtimeSeconds = 0;
    quint64 processStartTicks = 0; // Internal Linux identity; not serialized.
    QString executablePath;
    int treeDepth = 0;
};

struct Snapshot {
    int schemaVersion = SchemaVersion;
    qint64 timestampMs = 0;
    quint64 sequence = 0;
    qint64 intervalMs = 0;
    ModuleSet requestedModules;
    SystemInfo system;
    CpuInfo cpu;
    MemoryInfo memory;
    QVector<GpuInfo> gpus;
    QVector<DiskInfo> disks;
    NetworkInfo network;
    BatteryInfo battery;
    QVector<ProcessInfo> processes;
    QVector<Error> errors;
};

inline ModuleSet defaultModules()
{
    return {
        QStringLiteral("system"),
        QStringLiteral("cpu"),
        QStringLiteral("memory"),
        QStringLiteral("gpu"),
        QStringLiteral("disk"),
        QStringLiteral("network"),
        QStringLiteral("battery"),
    };
}

inline ModuleSet allModules()
{
    ModuleSet modules = defaultModules();
    modules.insert(QStringLiteral("processes"));
    return modules;
}

inline QStringList orderedModuleNames()
{
    return {
        QStringLiteral("system"),
        QStringLiteral("cpu"),
        QStringLiteral("memory"),
        QStringLiteral("gpu"),
        QStringLiteral("disk"),
        QStringLiteral("network"),
        QStringLiteral("battery"),
        QStringLiteral("processes"),
    };
}

} // namespace Clavis::Sysmon
