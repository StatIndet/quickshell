#include "collector.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>
#include <QStorageInfo>

#include <algorithm>
#include <cmath>

namespace Clavis::Sysmon {

namespace {

QByteArray readAll(const QString &path, bool *ok = nullptr)
{
    QFile file(path);
    const bool opened = file.open(QIODevice::ReadOnly);
    if (ok)
        *ok = opened;
    return opened ? file.readAll() : QByteArray();
}

QString readText(const QString &path)
{
    return QString::fromUtf8(readAll(path)).trimmed();
}

OptionalNumber readNumber(const QString &path, double scale = 1.0)
{
    bool ok = false;
    const double value = readText(path).toDouble(&ok);
    return ok ? OptionalNumber(value * scale) : std::nullopt;
}

OptionalInteger readInteger(const QString &path)
{
    bool ok = false;
    const qint64 value = readText(path).toLongLong(&ok);
    return ok ? OptionalInteger(value) : std::nullopt;
}

OptionalNumber readDpmFrequencyMHz(const QString &path)
{
    const QString text = readText(path);
    if (text.isEmpty())
        return std::nullopt;

    const QRegularExpression pattern(
        QStringLiteral(R"((\d+(?:\.\d+)?)\s*MHz\b)"),
        QRegularExpression::CaseInsensitiveOption);
    OptionalNumber fallback;
    const QStringList lines = text.split(QLatin1Char('\n'));
    for (const QString &line : lines) {
        const QRegularExpressionMatch match = pattern.match(line);
        if (!match.hasMatch())
            continue;
        bool ok = false;
        const double value = match.captured(1).toDouble(&ok);
        if (!ok)
            continue;
        if (line.contains(QLatin1Char('*')))
            return value;
        if (!fallback)
            fallback = value;
    }
    return fallback;
}

QString vendorName(const QString &raw)
{
    const QString value = raw.trimmed().toLower();
    if (value == QStringLiteral("0x10de") || value == QStringLiteral("nvidia"))
        return QStringLiteral("NVIDIA");
    if (value == QStringLiteral("0x1002") || value == QStringLiteral("amd"))
        return QStringLiteral("AMD");
    if (value == QStringLiteral("0x8086") || value == QStringLiteral("intel"))
        return QStringLiteral("Intel");
    return raw.trimmed();
}

OptionalNumber parseNvidiaNumber(const QString &text)
{
    const QString value = text.trimmed();
    if (value.isEmpty() || value.compare(QStringLiteral("N/A"), Qt::CaseInsensitive) == 0
        || value.compare(QStringLiteral("[Not Supported]"),
                         Qt::CaseInsensitive) == 0) {
        return std::nullopt;
    }
    bool ok = false;
    const double number = value.toDouble(&ok);
    return ok ? OptionalNumber(number) : std::nullopt;
}

QString blockDeviceName(const QByteArray &device)
{
    if (device.isEmpty() || !device.startsWith('/'))
        return {};
    QFileInfo info(QString::fromUtf8(device));
    QString canonical = info.canonicalFilePath();
    if (canonical.isEmpty())
        canonical = info.absoluteFilePath();
    return QFileInfo(canonical).fileName();
}

QString blockDeviceCursorKey(const QString &name)
{
    if (name.isEmpty())
        return {};

    const QString blockPath =
        QStringLiteral("/sys/class/block/%1").arg(name);
    QString identityPath = blockPath;
    if (QFileInfo::exists(blockPath + QStringLiteral("/partition"))) {
        const QString canonical = QFileInfo(blockPath).canonicalFilePath();
        const QString parentName =
            QFileInfo(QFileInfo(canonical).path()).fileName();
        if (!parentName.isEmpty())
            identityPath =
                QStringLiteral("/sys/class/block/%1").arg(parentName);
    }

    QString generation = readText(identityPath + QStringLiteral("/diskseq"));
    if (generation.isEmpty())
        generation = readText(identityPath + QStringLiteral("/device/wwid"));
    if (generation.isEmpty())
        generation = readText(identityPath + QStringLiteral("/device/serial"));

    const QString fallback =
        QFileInfo(identityPath).canonicalFilePath()
        + QLatin1Char('|')
        + readText(identityPath + QStringLiteral("/dev"))
        + QLatin1Char('|')
        + QString::fromUtf8(
              readAll(identityPath + QStringLiteral("/uevent"))).trimmed();
    return composeDeviceCursorKey(name, generation, fallback);
}

bool isPseudoFilesystem(const QByteArray &filesystem)
{
    static const QSet<QByteArray> pseudo = {
        "autofs",       "bpf",         "cgroup",      "cgroup2",
        "configfs",     "debugfs",     "devpts",      "devtmpfs",
        "efivarfs",     "fusectl",     "hugetlbfs",   "mqueue",
        "nsfs",         "overlay",     "proc",        "pstore",
        "ramfs",        "securityfs",  "selinuxfs",   "squashfs",
        "sysfs",        "tmpfs",       "tracefs",
    };
    return pseudo.contains(filesystem);
}

bool isAcType(const QString &type)
{
    const QString lower = type.toLower();
    return lower == QStringLiteral("mains")
        || lower == QStringLiteral("usb")
        || lower == QStringLiteral("usb_c")
        || lower == QStringLiteral("usb_pd")
        || lower == QStringLiteral("wireless");
}

} // namespace

QVector<GpuInfo> LinuxCollector::collectNvidiaGpus(QVector<Error> *errors)
{
    if (m_nvidiaProgram.isEmpty())
        return {};

    const auto finishProbe = [this, errors]() {
        const QProcess::ProcessError processError = m_nvidiaProcess.error();
        const bool failedToStart =
            processError == QProcess::FailedToStart;
        const bool succeeded =
            m_nvidiaProcess.exitStatus() == QProcess::NormalExit
            && m_nvidiaProcess.exitCode() == 0;

        m_nvidiaProbePending = false;
        m_nvidiaProbeAttempted = true;
        m_nvidiaRefreshTimer.restart();

        if (!succeeded) {
            // NVIDIA support is optional. A missing executable is expected on
            // non-NVIDIA systems, so only report probes that actually ran.
            if (!failedToStart) {
                errors->push_back({
                    QStringLiteral("gpu"),
                    QStringLiteral("nvidia_probe_failed"),
                    QStringLiteral("nvidia-smi could not read GPU metrics"),
                });
            }
            m_cachedNvidiaGpus.clear();
            return;
        }

        QVector<GpuInfo> result;
        const QByteArray output = m_nvidiaProcess.readAllStandardOutput();
        const QList<QByteArray> lines = output.split('\n');
        for (const QByteArray &rawLine : lines) {
            const QString line = QString::fromUtf8(rawLine).trimmed();
            if (line.isEmpty())
                continue;
            const QStringList fields = line.split(QLatin1Char(','));
            if (fields.size() < 10)
                continue;
            GpuInfo gpu;
            gpu.available = true;
            gpu.supported = true;
            gpu.id = QStringLiteral("nvidia%1").arg(fields.at(0).trimmed());
            gpu.pciId = fields.at(1).trimmed();
            gpu.name = fields.at(2).trimmed();
            gpu.vendor = QStringLiteral("NVIDIA");
            gpu.driver = fields.at(3).trimmed();
            gpu.utilizationPercent = parseNvidiaNumber(fields.at(4));
            gpu.temperatureCelsius = parseNvidiaNumber(fields.at(5));
            const OptionalNumber totalMiB = parseNvidiaNumber(fields.at(6));
            const OptionalNumber usedMiB = parseNvidiaNumber(fields.at(7));
            if (totalMiB) {
                gpu.vramTotalBytes =
                    static_cast<qint64>(*totalMiB * 1024.0 * 1024.0);
            }
            if (usedMiB) {
                gpu.vramUsedBytes =
                    static_cast<qint64>(*usedMiB * 1024.0 * 1024.0);
            }
            gpu.powerWatts = parseNvidiaNumber(fields.at(8));
            gpu.frequencyMHz = parseNvidiaNumber(fields.at(9));
            result.push_back(gpu);
        }

        if (result.isEmpty() && !output.trimmed().isEmpty()) {
            errors->push_back({
                QStringLiteral("gpu"),
                QStringLiteral("nvidia_output_invalid"),
                QStringLiteral("nvidia-smi returned an unsupported CSV response"),
            });
        }
        m_cachedNvidiaGpus = std::move(result);
    };

    if (m_nvidiaProbePending) {
        if (m_nvidiaProcess.state() == QProcess::Starting)
            m_nvidiaProcess.waitForStarted(0);
        if (m_nvidiaProcess.state() != QProcess::NotRunning)
            m_nvidiaProcess.waitForFinished(0);

        if (m_nvidiaProcess.state() == QProcess::NotRunning) {
            finishProbe();
            return m_cachedNvidiaGpus;
        }

        if (m_nvidiaProbeTimer.isValid()
            && m_nvidiaProbeTimer.elapsed() >= 1500) {
            m_nvidiaProcess.kill();
            m_nvidiaProcess.waitForFinished(500);
            m_nvidiaProbePending = false;
            m_nvidiaProbeAttempted = true;
            m_nvidiaRefreshTimer.restart();
            m_cachedNvidiaGpus.clear();
            errors->push_back({
                QStringLiteral("gpu"),
                QStringLiteral("nvidia_probe_timeout"),
                QStringLiteral("nvidia-smi did not finish within 1500 ms"),
            });
            return {};
        }

        return m_cachedNvidiaGpus;
    }

    if (m_nvidiaProbeAttempted
        && m_nvidiaRefreshTimer.isValid()
        && m_nvidiaRefreshTimer.elapsed() < 5000) {
        return m_cachedNvidiaGpus;
    }

    m_nvidiaProcess.setProgram(m_nvidiaProgram);
    m_nvidiaProcess.setArguments({
        QStringLiteral(
            "--query-gpu=index,pci.bus_id,name,driver_version,utilization.gpu,"
            "temperature.gpu,memory.total,memory.used,power.draw,"
            "clocks.current.graphics"),
        QStringLiteral("--format=csv,noheader,nounits"),
    });
    m_nvidiaProcess.setProcessChannelMode(QProcess::SeparateChannels);
    m_nvidiaProcess.start(QIODevice::ReadOnly);
    m_nvidiaProbePending = true;
    m_nvidiaProbeTimer.restart();

    // Resolve an immediate executable lookup failure without waiting. All
    // other states are polled by the next sample, keeping collection latency
    // independent from the vendor utility.
    m_nvidiaProcess.waitForStarted(0);
    if (m_nvidiaProcess.state() == QProcess::NotRunning)
        finishProbe();
    return m_cachedNvidiaGpus;
}

QVector<GpuInfo> LinuxCollector::collectGpus(QVector<Error> *errors)
{
    QVector<GpuInfo> result = collectNvidiaGpus(errors);
    QSet<QString> nvidiaPciIds;
    for (const GpuInfo &gpu : std::as_const(result))
        nvidiaPciIds.insert(gpu.pciId.toLower());

    const QDir drm(QStringLiteral("/sys/class/drm"));
    const QRegularExpression cardPattern(QStringLiteral("^card\\d+$"));
    for (const QString &entry : drm.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!cardPattern.match(entry).hasMatch())
            continue;
        const QString devicePath = drm.absoluteFilePath(entry)
            + QStringLiteral("/device");
        if (!QFileInfo::exists(devicePath))
            continue;

        const QString rawVendor = readText(devicePath + QStringLiteral("/vendor"));
        const QString vendor = vendorName(rawVendor);
        const QList<QByteArray> ueventLines =
            readAll(devicePath + QStringLiteral("/uevent")).split('\n');
        QString pciId;
        QString driver;
        for (const QByteArray &raw : ueventLines) {
            const QString line = QString::fromUtf8(raw);
            if (line.startsWith(QStringLiteral("PCI_SLOT_NAME=")))
                pciId = line.mid(14).trimmed();
            else if (line.startsWith(QStringLiteral("DRIVER=")))
                driver = line.mid(7).trimmed();
        }
        if (vendor == QStringLiteral("NVIDIA")
            && (nvidiaPciIds.contains(pciId.toLower())
                || !result.isEmpty())) {
            continue;
        }

        GpuInfo gpu;
        gpu.available = true;
        gpu.id = entry;
        gpu.pciId = pciId;
        gpu.vendor = vendor.isEmpty() ? QStringLiteral("Unknown") : vendor;
        gpu.driver = driver;
        gpu.name = driver.isEmpty()
            ? QStringLiteral("%1 GPU").arg(gpu.vendor)
            : QStringLiteral("%1 (%2)").arg(gpu.vendor, driver);

        gpu.utilizationPercent =
            readNumber(devicePath + QStringLiteral("/gpu_busy_percent"));
        gpu.frequencyMHz =
            readNumber(devicePath + QStringLiteral("/gt_cur_freq_mhz"));
        if (!gpu.frequencyMHz) {
            gpu.frequencyMHz =
                readDpmFrequencyMHz(
                    devicePath + QStringLiteral("/pp_dpm_sclk"));
        }

        OptionalInteger total =
            readInteger(devicePath + QStringLiteral("/mem_info_vram_total"));
        OptionalInteger used =
            readInteger(devicePath + QStringLiteral("/mem_info_vram_used"));
        gpu.vramTotalBytes = total;
        gpu.vramUsedBytes = used;

        const QDir hwmon(devicePath + QStringLiteral("/hwmon"));
        const QStringList hwmons =
            hwmon.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &hwmonName : hwmons) {
            const QString hwmonPath = hwmon.absoluteFilePath(hwmonName);
            if (!gpu.temperatureCelsius)
                gpu.temperatureCelsius =
                    readNumber(hwmonPath + QStringLiteral("/temp1_input"), 0.001);
            if (!gpu.powerWatts) {
                gpu.powerWatts =
                    readNumber(hwmonPath + QStringLiteral("/power1_average"),
                               0.000001);
                if (!gpu.powerWatts) {
                    gpu.powerWatts =
                        readNumber(hwmonPath + QStringLiteral("/power1_input"),
                                   0.000001);
                }
            }
        }
        gpu.supported = gpu.utilizationPercent.has_value()
            || gpu.temperatureCelsius.has_value()
            || gpu.vramTotalBytes.has_value()
            || gpu.vramUsedBytes.has_value()
            || gpu.powerWatts.has_value()
            || gpu.frequencyMHz.has_value();
        result.push_back(gpu);
    }

    return result;
}

QVector<RawDiskInfo> LinuxCollector::collectDisks(QVector<Error> *errors) const
{
    QVector<RawDiskInfo> result;
    QSet<QString> seenMounts;
    const QList<QStorageInfo> volumes = QStorageInfo::mountedVolumes();
    for (const QStorageInfo &storage : volumes) {
        if (!storage.isValid() || !storage.isReady()
            || storage.rootPath().isEmpty()
            || seenMounts.contains(storage.rootPath())
            || isPseudoFilesystem(storage.fileSystemType())) {
            continue;
        }
        const QString mountPoint = storage.rootPath();
        const int pathDepth =
            mountPoint.count(QLatin1Char('/'))
            - (mountPoint.endsWith(QLatin1Char('/')) ? 1 : 0);
        const bool conventionalExternal =
            mountPoint.startsWith(QStringLiteral("/mnt/"))
            || mountPoint.startsWith(QStringLiteral("/media/"))
            || mountPoint.startsWith(QStringLiteral("/run/media/"));
        // Sandboxes and container runtimes commonly bind individual project
        // directories. They are not useful storage volumes, while ordinary
        // top-level mounts such as /home and /boot remain visible.
        if (pathDepth > 2 && !conventionalExternal)
            continue;
        seenMounts.insert(storage.rootPath());

        RawDiskInfo disk;
        disk.info.available = true;
        disk.info.mountPoint = storage.rootPath();
        disk.info.filesystem = QString::fromUtf8(storage.fileSystemType());
        disk.info.device = QString::fromUtf8(storage.device());
        disk.info.totalBytes = static_cast<quint64>(
            std::max<qint64>(0, storage.bytesTotal()));
        disk.info.freeBytes = static_cast<quint64>(
            std::max<qint64>(0, storage.bytesAvailable()));
        if (disk.info.freeBytes > disk.info.totalBytes)
            disk.info.freeBytes = disk.info.totalBytes;
        disk.info.usedBytes = disk.info.totalBytes - disk.info.freeBytes;
        if (disk.info.totalBytes > 0) {
            disk.info.usagePercent =
                static_cast<double>(disk.info.usedBytes) * 100.0
                / static_cast<double>(disk.info.totalBytes);
        }

        const QString blockName = blockDeviceName(storage.device());
        disk.counterKey = blockDeviceCursorKey(blockName);
        if (!blockName.isEmpty()) {
            disk.counters = parseDiskStatLine(
                readAll(QStringLiteral("/sys/class/block/%1/stat")
                            .arg(blockName)));
        }
        result.push_back(disk);
    }
    if (result.isEmpty()) {
        errors->push_back({
            QStringLiteral("disk"),
            QStringLiteral("mounts_unavailable"),
            QStringLiteral("No meaningful mounted filesystems were found"),
        });
    }
    std::sort(result.begin(), result.end(), [](const RawDiskInfo &left,
                                               const RawDiskInfo &right) {
        if (left.info.mountPoint == QStringLiteral("/"))
            return true;
        if (right.info.mountPoint == QStringLiteral("/"))
            return false;
        return left.info.mountPoint < right.info.mountPoint;
    });
    return result;
}

QVector<RawNetworkInterfaceInfo> LinuxCollector::collectNetwork(
    QString *defaultInterface,
    QVector<Error> *errors) const
{
    bool ok = false;
    const QHash<QString, NetworkCounter> counters =
        parseProcNetDev(readAll(QStringLiteral("/proc/net/dev"), &ok));
    if (!ok) {
        errors->push_back({
            QStringLiteral("network"),
            QStringLiteral("netdev_unavailable"),
            QStringLiteral("Unable to read /proc/net/dev"),
        });
        return {};
    }

    *defaultInterface = parseDefaultRouteInterface(
        readAll(QStringLiteral("/proc/net/route")),
        readAll(QStringLiteral("/proc/net/ipv6_route")));

    QVector<RawNetworkInterfaceInfo> result;
    const QStringList names = counters.keys();
    for (const QString &name : names) {
        RawNetworkInterfaceInfo interface;
        interface.info.available = true;
        interface.info.name = name;
        bool ifIndexOk = false;
        interface.info.ifIndex =
            readText(QStringLiteral("/sys/class/net/%1/ifindex").arg(name))
                .toInt(&ifIndexOk);
        if (!ifIndexOk || interface.info.ifIndex <= 0)
            interface.info.ifIndex = 0;
        interface.info.loopback = name == QStringLiteral("lo");
        interface.info.wireless =
            QFileInfo::exists(
                QStringLiteral("/sys/class/net/%1/wireless").arg(name));
        const QString state =
            readText(QStringLiteral("/sys/class/net/%1/operstate").arg(name));
        interface.info.up = state == QStringLiteral("up")
            || state == QStringLiteral("unknown");
        interface.counters = counters.value(name);
        interface.info.downloadTotalBytes = interface.counters.receiveBytes;
        interface.info.uploadTotalBytes = interface.counters.transmitBytes;
        result.push_back(interface);
    }
    const auto activeDefault = std::find_if(
        result.cbegin(),
        result.cend(),
        [defaultInterface](const RawNetworkInterfaceInfo &interface) {
            return interface.info.name == *defaultInterface
                && interface.info.up;
        });
    if (activeDefault == result.cend()) {
        const auto fallback = std::find_if(
            result.cbegin(),
            result.cend(),
            [](const RawNetworkInterfaceInfo &interface) {
                return interface.info.up && !interface.info.loopback;
            });
        *defaultInterface = fallback == result.cend()
            ? QString()
            : fallback->info.name;
    }
    std::sort(result.begin(),
              result.end(),
              [defaultInterface](const RawNetworkInterfaceInfo &left,
                                 const RawNetworkInterfaceInfo &right) {
                  if (left.info.name == *defaultInterface)
                      return true;
                  if (right.info.name == *defaultInterface)
                      return false;
                  if (left.info.loopback != right.info.loopback)
                      return !left.info.loopback;
                  return left.info.name < right.info.name;
              });
    return result;
}

BatteryInfo LinuxCollector::collectBattery(QVector<Error> *errors) const
{
    BatteryInfo result;
    result.supported = true;
    const QDir supplies(QStringLiteral("/sys/class/power_supply"));
    if (!supplies.exists()) {
        result.supported = false;
        errors->push_back({
            QStringLiteral("battery"),
            QStringLiteral("power_supply_unavailable"),
            QStringLiteral("/sys/class/power_supply is unavailable"),
        });
        return result;
    }

    std::optional<bool> acOnline;
    QString batteryPath;
    QString fallbackBatteryPath;
    QString batteryName;
    QString fallbackBatteryName;
    for (const QString &entry :
         supplies.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        const QString path = supplies.absoluteFilePath(entry);
        const QString type = readText(path + QStringLiteral("/type"));
        if (type.compare(QStringLiteral("Battery"), Qt::CaseInsensitive) == 0) {
            if (fallbackBatteryPath.isEmpty()) {
                fallbackBatteryPath = path;
                fallbackBatteryName = entry;
            }
            const OptionalInteger present =
                readInteger(path + QStringLiteral("/present"));
            if (batteryPath.isEmpty() && (!present || *present > 0)) {
                batteryPath = path;
                batteryName = entry;
            }
        } else if (isAcType(type)) {
            const OptionalInteger online =
                readInteger(path + QStringLiteral("/online"));
            if (online)
                acOnline = acOnline.value_or(false) || *online > 0;
        }
    }
    result.acOnline = acOnline;
    if (batteryPath.isEmpty()) {
        batteryPath = fallbackBatteryPath;
        batteryName = fallbackBatteryName;
    }
    if (batteryPath.isEmpty()) {
        result.available = true;
        result.present = false;
        return result;
    }
    result.name = batteryName;

    const OptionalInteger present =
        readInteger(batteryPath + QStringLiteral("/present"));
    result.present = !present || *present > 0;
    result.available = result.present;
    if (!result.present)
        return result;

    result.chargePercent =
        readNumber(batteryPath + QStringLiteral("/capacity"));
    result.status = readText(batteryPath + QStringLiteral("/status")).toLower();

    OptionalInteger energyNow =
        readInteger(batteryPath + QStringLiteral("/energy_now"));
    OptionalInteger energyFull =
        readInteger(batteryPath + QStringLiteral("/energy_full"));
    OptionalInteger energyDesign =
        readInteger(batteryPath + QStringLiteral("/energy_full_design"));
    OptionalInteger powerNow =
        readInteger(batteryPath + QStringLiteral("/power_now"));

    if (!energyNow || !energyFull) {
        const OptionalInteger chargeNow =
            readInteger(batteryPath + QStringLiteral("/charge_now"));
        const OptionalInteger chargeFull =
            readInteger(batteryPath + QStringLiteral("/charge_full"));
        const OptionalInteger chargeDesign =
            readInteger(batteryPath + QStringLiteral("/charge_full_design"));
        const OptionalInteger voltage =
            readInteger(batteryPath + QStringLiteral("/voltage_now"));
        if (voltage && chargeNow)
            energyNow = static_cast<qint64>(
                static_cast<long double>(*voltage)
                * static_cast<long double>(*chargeNow) / 1'000'000.0L);
        if (voltage && chargeFull)
            energyFull = static_cast<qint64>(
                static_cast<long double>(*voltage)
                * static_cast<long double>(*chargeFull) / 1'000'000.0L);
        if (voltage && chargeDesign)
            energyDesign = static_cast<qint64>(
                static_cast<long double>(*voltage)
                * static_cast<long double>(*chargeDesign) / 1'000'000.0L);
    }

    if (!powerNow) {
        const OptionalInteger current =
            readInteger(batteryPath + QStringLiteral("/current_now"));
        const OptionalInteger voltage =
            readInteger(batteryPath + QStringLiteral("/voltage_now"));
        if (current && voltage) {
            powerNow = static_cast<qint64>(
                static_cast<long double>(*current)
                * static_cast<long double>(*voltage) / 1'000'000.0L);
        }
    }

    result.energyNowMicroWh = energyNow;
    result.energyFullMicroWh = energyFull;
    result.energyDesignMicroWh = energyDesign;
    if (powerNow && *powerNow >= 0)
        result.powerWatts = static_cast<double>(*powerNow) / 1'000'000.0;
    if (energyFull && energyDesign && *energyDesign > 0) {
        result.healthPercent =
            static_cast<double>(*energyFull) * 100.0
            / static_cast<double>(*energyDesign);
    }
    if (powerNow && *powerNow > 0) {
        qint64 relevantEnergy = 0;
        if (result.status == QStringLiteral("charging")
            && energyNow && energyFull && *energyFull >= *energyNow) {
            relevantEnergy = *energyFull - *energyNow;
        } else if (energyNow) {
            relevantEnergy = *energyNow;
        }
        if (relevantEnergy > 0) {
            result.timeRemainingSeconds = static_cast<qint64>(
                static_cast<long double>(relevantEnergy) * 3600.0L
                / static_cast<long double>(*powerNow));
        }
    }
    return result;
}

} // namespace Clavis::Sysmon
