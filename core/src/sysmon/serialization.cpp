#include "serialization.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QLocale>
#include <QTextStream>

#include <cmath>

namespace Clavis::Sysmon {

namespace {

QJsonValue numberOrNull(const OptionalNumber &value)
{
    return value && std::isfinite(*value)
        ? QJsonValue(*value)
        : QJsonValue(QJsonValue::Null);
}

QJsonValue integerOrNull(const OptionalInteger &value)
{
    return value
        ? QJsonValue(*value)
        : QJsonValue(QJsonValue::Null);
}

QJsonObject systemJson(const SystemInfo &system)
{
    return {
        {QStringLiteral("available"), system.available},
        {QStringLiteral("hostName"), system.hostName},
        {QStringLiteral("osName"), system.osName},
        {QStringLiteral("distroId"), system.distroId},
        {QStringLiteral("kernel"), system.kernel},
        {QStringLiteral("architecture"), system.architecture},
        {QStringLiteral("uptimeSeconds"), system.uptimeSeconds},
        {QStringLiteral("bootTimeMs"), system.bootTimeMs},
        {QStringLiteral("logicalCpuCount"), system.logicalCpuCount},
        {QStringLiteral("physicalCoreCount"), system.physicalCoreCount},
        {QStringLiteral("cpuModelName"), system.cpuModelName},
        {QStringLiteral("vendor"), system.vendor},
        {QStringLiteral("productName"), system.productName},
        {QStringLiteral("boardName"), system.boardName},
        {QStringLiteral("biosVersion"), system.biosVersion},
        {QStringLiteral("systemUser"), system.systemUser},
        {QStringLiteral("wmName"), system.wmName},
        {QStringLiteral("shellName"), system.shellName},
        {QStringLiteral("chassis"), system.chassis},
        {QStringLiteral("osAgeText"), system.osAgeText},
    };
}

QJsonObject cpuJson(const CpuInfo &cpu)
{
    QJsonArray coreIds;
    for (int id : cpu.coreIds)
        coreIds.push_back(id);
    QJsonArray cores;
    for (const OptionalNumber &value : cpu.coreUsagePercent)
        cores.push_back(numberOrNull(value));
    return {
        {QStringLiteral("available"), cpu.available},
        {QStringLiteral("sampleReady"), cpu.sampleReady},
        {QStringLiteral("usagePercent"), numberOrNull(cpu.usagePercent)},
        {QStringLiteral("userPercent"), numberOrNull(cpu.userPercent)},
        {QStringLiteral("systemPercent"), numberOrNull(cpu.systemPercent)},
        {QStringLiteral("idlePercent"), numberOrNull(cpu.idlePercent)},
        {QStringLiteral("iowaitPercent"), numberOrNull(cpu.iowaitPercent)},
        {QStringLiteral("coreIds"), coreIds},
        {QStringLiteral("coreUsagePercent"), cores},
        {QStringLiteral("frequencyCurrentMHz"),
         numberOrNull(cpu.frequencyCurrentMHz)},
        {QStringLiteral("frequencyAverageMHz"),
         numberOrNull(cpu.frequencyAverageMHz)},
        {QStringLiteral("frequencyMinMHz"),
         numberOrNull(cpu.frequencyMinMHz)},
        {QStringLiteral("frequencyMaxMHz"),
         numberOrNull(cpu.frequencyMaxMHz)},
        {QStringLiteral("temperatureCelsius"),
         numberOrNull(cpu.temperatureCelsius)},
        {QStringLiteral("packageTemperatureCelsius"),
         numberOrNull(cpu.packageTemperatureCelsius)},
        {QStringLiteral("powerWatts"), numberOrNull(cpu.powerWatts)},
        {QStringLiteral("fanRpm"), numberOrNull(cpu.fanRpm)},
    };
}

QJsonObject memoryJson(const MemoryInfo &memory)
{
    return {
        {QStringLiteral("available"), memory.available},
        {QStringLiteral("totalBytes"), static_cast<qint64>(memory.totalBytes)},
        {QStringLiteral("usedBytes"), static_cast<qint64>(memory.usedBytes)},
        {QStringLiteral("availableBytes"),
         static_cast<qint64>(memory.availableBytes)},
        {QStringLiteral("freeBytes"), static_cast<qint64>(memory.freeBytes)},
        {QStringLiteral("cachedBytes"), static_cast<qint64>(memory.cachedBytes)},
        {QStringLiteral("buffersBytes"),
         static_cast<qint64>(memory.buffersBytes)},
        {QStringLiteral("swapTotalBytes"),
         static_cast<qint64>(memory.swapTotalBytes)},
        {QStringLiteral("swapUsedBytes"),
         static_cast<qint64>(memory.swapUsedBytes)},
        {QStringLiteral("usagePercent"),
         numberOrNull(memory.usagePercent)},
    };
}

QJsonObject gpuJson(const GpuInfo &gpu)
{
    return {
        {QStringLiteral("available"), gpu.available},
        {QStringLiteral("supported"), gpu.supported},
        {QStringLiteral("id"), gpu.id},
        {QStringLiteral("pciId"), gpu.pciId},
        {QStringLiteral("name"), gpu.name},
        {QStringLiteral("vendor"), gpu.vendor},
        {QStringLiteral("driver"), gpu.driver},
        {QStringLiteral("utilizationPercent"),
         numberOrNull(gpu.utilizationPercent)},
        {QStringLiteral("temperatureCelsius"),
         numberOrNull(gpu.temperatureCelsius)},
        {QStringLiteral("vramTotalBytes"),
         integerOrNull(gpu.vramTotalBytes)},
        {QStringLiteral("vramUsedBytes"),
         integerOrNull(gpu.vramUsedBytes)},
        {QStringLiteral("powerWatts"), numberOrNull(gpu.powerWatts)},
        {QStringLiteral("frequencyMHz"),
         numberOrNull(gpu.frequencyMHz)},
    };
}

QJsonObject diskJson(const DiskInfo &disk)
{
    return {
        {QStringLiteral("available"), disk.available},
        {QStringLiteral("mountPoint"), disk.mountPoint},
        {QStringLiteral("filesystem"), disk.filesystem},
        {QStringLiteral("device"), disk.device},
        {QStringLiteral("totalBytes"), static_cast<qint64>(disk.totalBytes)},
        {QStringLiteral("usedBytes"), static_cast<qint64>(disk.usedBytes)},
        {QStringLiteral("freeBytes"), static_cast<qint64>(disk.freeBytes)},
        {QStringLiteral("usagePercent"),
         numberOrNull(disk.usagePercent)},
        {QStringLiteral("readBytesPerSecond"),
         numberOrNull(disk.readBytesPerSecond)},
        {QStringLiteral("writeBytesPerSecond"),
         numberOrNull(disk.writeBytesPerSecond)},
        {QStringLiteral("readIops"), numberOrNull(disk.readIops)},
        {QStringLiteral("writeIops"), numberOrNull(disk.writeIops)},
    };
}

QJsonObject networkInterfaceJson(const NetworkInterfaceInfo &interface)
{
    return {
        {QStringLiteral("available"), interface.available},
        {QStringLiteral("name"), interface.name},
        {QStringLiteral("ifIndex"), interface.ifIndex},
        {QStringLiteral("up"), interface.up},
        {QStringLiteral("loopback"), interface.loopback},
        {QStringLiteral("wireless"), interface.wireless},
        {QStringLiteral("wirelessSignalPercent"),
         QJsonValue(QJsonValue::Null)},
        {QStringLiteral("downloadTotalBytes"),
         static_cast<qint64>(interface.downloadTotalBytes)},
        {QStringLiteral("uploadTotalBytes"),
         static_cast<qint64>(interface.uploadTotalBytes)},
        {QStringLiteral("downloadBytesPerSecond"),
         numberOrNull(interface.downloadBytesPerSecond)},
        {QStringLiteral("uploadBytesPerSecond"),
         numberOrNull(interface.uploadBytesPerSecond)},
    };
}

QJsonObject networkJson(const NetworkInfo &network)
{
    QJsonArray interfaces;
    for (const NetworkInterfaceInfo &interface : network.interfaces)
        interfaces.push_back(networkInterfaceJson(interface));
    return {
        {QStringLiteral("available"), network.available},
        {QStringLiteral("defaultInterface"), network.defaultInterface},
        {QStringLiteral("wifiAvailable"), network.wifiAvailable},
        {QStringLiteral("wifiConnected"), network.wifiConnected},
        {QStringLiteral("wifiSignalPercent"),
         QJsonValue(QJsonValue::Null)},
        {QStringLiteral("downloadTotalBytes"),
         static_cast<qint64>(network.downloadTotalBytes)},
        {QStringLiteral("uploadTotalBytes"),
         static_cast<qint64>(network.uploadTotalBytes)},
        {QStringLiteral("downloadBytesPerSecond"),
         numberOrNull(network.downloadBytesPerSecond)},
        {QStringLiteral("uploadBytesPerSecond"),
         numberOrNull(network.uploadBytesPerSecond)},
        {QStringLiteral("interfaces"), interfaces},
    };
}

QJsonObject batteryJson(const BatteryInfo &battery)
{
    const QJsonValue acOnline = battery.acOnline
        ? QJsonValue(*battery.acOnline)
        : QJsonValue(QJsonValue::Null);
    return {
        {QStringLiteral("available"), battery.available},
        {QStringLiteral("supported"), battery.supported},
        {QStringLiteral("present"), battery.present},
        {QStringLiteral("name"), battery.name},
        {QStringLiteral("status"), battery.status},
        {QStringLiteral("chargePercent"),
         numberOrNull(battery.chargePercent)},
        {QStringLiteral("powerWatts"), numberOrNull(battery.powerWatts)},
        {QStringLiteral("timeRemainingSeconds"),
         integerOrNull(battery.timeRemainingSeconds)},
        {QStringLiteral("acOnline"), acOnline},
        {QStringLiteral("healthPercent"),
         numberOrNull(battery.healthPercent)},
        {QStringLiteral("energyNowMicroWh"),
         integerOrNull(battery.energyNowMicroWh)},
        {QStringLiteral("energyFullMicroWh"),
         integerOrNull(battery.energyFullMicroWh)},
        {QStringLiteral("energyDesignMicroWh"),
         integerOrNull(battery.energyDesignMicroWh)},
    };
}

QJsonObject processJson(const ProcessInfo &process)
{
    return {
        {QStringLiteral("pid"), process.pid},
        {QStringLiteral("ppid"), process.ppid},
        {QStringLiteral("name"), process.name},
        {QStringLiteral("command"), process.command},
        {QStringLiteral("user"), process.user},
        {QStringLiteral("state"), process.state},
        {QStringLiteral("cpuUsagePercent"),
         numberOrNull(process.cpuUsagePercent)},
        {QStringLiteral("memoryBytes"),
         static_cast<qint64>(process.memoryBytes)},
        {QStringLiteral("memoryPercent"),
         numberOrNull(process.memoryPercent)},
        {QStringLiteral("threadCount"), process.threadCount},
        {QStringLiteral("startTimeMs"), process.startTimeMs},
        {QStringLiteral("runtimeSeconds"), process.runtimeSeconds},
        {QStringLiteral("executablePath"), process.executablePath},
        {QStringLiteral("treeDepth"), process.treeDepth},
    };
}

QString humanPercent(const OptionalNumber &value)
{
    return value
        ? QLocale::c().toString(*value, 'f', 1) + QLatin1Char('%')
        : QStringLiteral("unavailable");
}

QString humanBytes(quint64 bytes)
{
    static const QStringList units{
        QStringLiteral("B"),
        QStringLiteral("KiB"),
        QStringLiteral("MiB"),
        QStringLiteral("GiB"),
        QStringLiteral("TiB"),
    };
    double value = static_cast<double>(bytes);
    int unit = 0;
    while (value >= 1024.0 && unit < units.size() - 1) {
        value /= 1024.0;
        ++unit;
    }
    return QStringLiteral("%1 %2")
        .arg(QLocale::c().toString(value, 'f', unit == 0 ? 0 : 1),
             units.at(unit));
}

} // namespace

QJsonObject snapshotToJson(const Snapshot &snapshot)
{
    QJsonObject root{
        {QStringLiteral("schemaVersion"), snapshot.schemaVersion},
        {QStringLiteral("timestampMs"), snapshot.timestampMs},
        {QStringLiteral("sequence"), static_cast<qint64>(snapshot.sequence)},
        {QStringLiteral("intervalMs"), snapshot.intervalMs},
    };

    if (snapshot.requestedModules.contains(QStringLiteral("system")))
        root.insert(QStringLiteral("system"), systemJson(snapshot.system));
    if (snapshot.requestedModules.contains(QStringLiteral("cpu")))
        root.insert(QStringLiteral("cpu"), cpuJson(snapshot.cpu));
    if (snapshot.requestedModules.contains(QStringLiteral("memory")))
        root.insert(QStringLiteral("memory"), memoryJson(snapshot.memory));
    if (snapshot.requestedModules.contains(QStringLiteral("gpu"))) {
        QJsonArray gpus;
        for (const GpuInfo &gpu : snapshot.gpus)
            gpus.push_back(gpuJson(gpu));
        root.insert(QStringLiteral("gpus"), gpus);
    }
    if (snapshot.requestedModules.contains(QStringLiteral("disk"))) {
        QJsonArray disks;
        for (const DiskInfo &disk : snapshot.disks)
            disks.push_back(diskJson(disk));
        root.insert(QStringLiteral("disks"), disks);
    }
    if (snapshot.requestedModules.contains(QStringLiteral("network")))
        root.insert(QStringLiteral("network"), networkJson(snapshot.network));
    if (snapshot.requestedModules.contains(QStringLiteral("battery")))
        root.insert(QStringLiteral("battery"), batteryJson(snapshot.battery));
    if (snapshot.requestedModules.contains(QStringLiteral("processes"))) {
        QJsonArray processes;
        for (const ProcessInfo &process : snapshot.processes)
            processes.push_back(processJson(process));
        root.insert(QStringLiteral("processes"), processes);
    }

    QJsonArray errors;
    for (const Error &error : snapshot.errors) {
        errors.push_back(QJsonObject{
            {QStringLiteral("module"), error.module},
            {QStringLiteral("code"), error.code},
            {QStringLiteral("message"), error.message},
        });
    }
    root.insert(QStringLiteral("errors"), errors);
    return root;
}

QByteArray snapshotToJsonLine(const Snapshot &snapshot)
{
    QByteArray result =
        QJsonDocument(snapshotToJson(snapshot)).toJson(QJsonDocument::Compact);
    result.push_back('\n');
    return result;
}

QString humanSnapshot(const Snapshot &snapshot)
{
    QString output;
    QTextStream stream(&output);
    if (snapshot.requestedModules.contains(QStringLiteral("system"))) {
        stream << "System  " << snapshot.system.hostName << " · "
               << snapshot.system.osName << " · " << snapshot.system.kernel
               << '\n';
    }
    if (snapshot.requestedModules.contains(QStringLiteral("cpu"))) {
        stream << "CPU     " << humanPercent(snapshot.cpu.usagePercent);
        if (snapshot.cpu.temperatureCelsius)
            stream << " · " << QLocale::c().toString(
                *snapshot.cpu.temperatureCelsius, 'f', 1) << " °C";
        stream << '\n';
    }
    if (snapshot.requestedModules.contains(QStringLiteral("memory"))) {
        stream << "Memory  " << humanPercent(snapshot.memory.usagePercent)
               << " · " << humanBytes(snapshot.memory.usedBytes)
               << " / " << humanBytes(snapshot.memory.totalBytes) << '\n';
    }
    if (snapshot.requestedModules.contains(QStringLiteral("gpu")))
        stream << "GPU     " << snapshot.gpus.size() << " detected\n";
    if (snapshot.requestedModules.contains(QStringLiteral("disk")))
        stream << "Disk    " << snapshot.disks.size() << " mounts\n";
    if (snapshot.requestedModules.contains(QStringLiteral("network"))) {
        stream << "Network "
               << (snapshot.network.defaultInterface.isEmpty()
                       ? QStringLiteral("no default interface")
                       : snapshot.network.defaultInterface)
               << '\n';
    }
    if (snapshot.requestedModules.contains(QStringLiteral("battery"))) {
        stream << "Battery "
               << (snapshot.battery.present
                       ? humanPercent(snapshot.battery.chargePercent)
                       : QStringLiteral("not present"))
               << '\n';
    }
    if (snapshot.requestedModules.contains(QStringLiteral("processes")))
        stream << "Processes " << snapshot.processes.size() << '\n';
    if (!snapshot.errors.isEmpty())
        stream << "Partial data: " << snapshot.errors.size() << " diagnostic(s)\n";
    return output.trimmed();
}

} // namespace Clavis::Sysmon
