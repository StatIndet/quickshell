#include "parsers.h"

#include <QStringList>

#include <algorithm>
#include <cmath>

namespace Clavis::Sysmon {

namespace {

quint64 valueAt(const QList<QByteArray> &parts, qsizetype index)
{
    if (index >= parts.size())
        return 0;
    bool ok = false;
    const quint64 value = parts.at(index).toULongLong(&ok);
    return ok ? value : 0;
}

CpuTimes parseCpuLine(const QByteArray &line)
{
    const QList<QByteArray> parts = line.simplified().split(' ');
    CpuTimes times;
    times.user = valueAt(parts, 1);
    times.nice = valueAt(parts, 2);
    times.system = valueAt(parts, 3);
    times.idle = valueAt(parts, 4);
    times.iowait = valueAt(parts, 5);
    times.irq = valueAt(parts, 6);
    times.softirq = valueAt(parts, 7);
    times.steal = valueAt(parts, 8);
    return times;
}

quint64 kibToBytes(quint64 value)
{
    constexpr quint64 KiB = 1024;
    if (value > std::numeric_limits<quint64>::max() / KiB)
        return std::numeric_limits<quint64>::max();
    return value * KiB;
}

} // namespace

quint64 CpuTimes::total() const
{
    // Linux reports guest time inside user/nice, so guest fields must not be
    // added again.
    return user + nice + system + idle + iowait + irq + softirq + steal;
}

quint64 CpuTimes::idleTotal() const
{
    return idle + iowait;
}

CpuCounters parseProcStat(const QByteArray &contents)
{
    CpuCounters result;
    const QList<QByteArray> lines = contents.split('\n');
    for (const QByteArray &rawLine : lines) {
        const QByteArray line = rawLine.simplified();
        if (line.startsWith("cpu ")) {
            result.total = parseCpuLine(line);
            result.valid = result.total.total() > 0;
            continue;
        }
        if (line.size() > 3 && line.startsWith("cpu")
            && line.at(3) >= '0' && line.at(3) <= '9') {
            const QList<QByteArray> parts = line.split(' ');
            bool idOk = false;
            const int id = parts.value(0).mid(3).toInt(&idOk);
            if (idOk && id >= 0)
                result.cores.push_back({id, parseCpuLine(line)});
        }
    }
    std::sort(
        result.cores.begin(),
        result.cores.end(),
        [](const CpuCounters::Core &left, const CpuCounters::Core &right) {
            return left.id < right.id;
        });
    return result;
}

OptionalInteger parseProcBootTimeMs(const QByteArray &contents)
{
    const QList<QByteArray> lines = contents.split('\n');
    for (const QByteArray &rawLine : lines) {
        const QList<QByteArray> parts = rawLine.simplified().split(' ');
        if (parts.size() != 2 || parts.at(0) != "btime")
            continue;
        bool ok = false;
        const qint64 seconds = parts.at(1).toLongLong(&ok);
        if (!ok || seconds <= 0
            || seconds > std::numeric_limits<qint64>::max() / 1000) {
            return std::nullopt;
        }
        return seconds * 1000;
    }
    return std::nullopt;
}

MemoryCounters parseMeminfo(const QByteArray &contents)
{
    QHash<QByteArray, quint64> values;
    const QList<QByteArray> lines = contents.split('\n');
    for (const QByteArray &line : lines) {
        const qsizetype colon = line.indexOf(':');
        if (colon <= 0)
            continue;
        const QByteArray key = line.left(colon);
        const QList<QByteArray> parts = line.mid(colon + 1).simplified().split(' ');
        if (parts.isEmpty())
            continue;
        bool ok = false;
        const quint64 value = parts.first().toULongLong(&ok);
        if (ok)
            values.insert(key, value);
    }

    MemoryCounters result;
    result.memTotalKiB = values.value("MemTotal");
    result.memAvailableKiB = values.value("MemAvailable");
    result.memFreeKiB = values.value("MemFree");
    result.cachedKiB = values.value("Cached") + values.value("SReclaimable");
    result.buffersKiB = values.value("Buffers");
    result.swapTotalKiB = values.value("SwapTotal");
    result.swapFreeKiB = values.value("SwapFree");
    result.valid = result.memTotalKiB > 0;

    // MemAvailable exists on supported modern kernels. This conservative
    // fallback follows procps' broad intent without treating reclaimable cache
    // as permanently used.
    if (result.valid && !values.contains("MemAvailable")) {
        result.memAvailableKiB = std::min(
            result.memTotalKiB,
            result.memFreeKiB + result.buffersKiB + result.cachedKiB);
    }
    return result;
}

QHash<QString, NetworkCounter> parseProcNetDev(const QByteArray &contents)
{
    QHash<QString, NetworkCounter> result;
    const QList<QByteArray> lines = contents.split('\n');
    for (const QByteArray &rawLine : lines) {
        const qsizetype colon = rawLine.indexOf(':');
        if (colon <= 0)
            continue;
        const QString name = QString::fromUtf8(rawLine.left(colon)).trimmed();
        const QList<QByteArray> fields =
            rawLine.mid(colon + 1).simplified().split(' ');
        if (name.isEmpty() || fields.size() < 16)
            continue;
        bool rxOk = false;
        bool txOk = false;
        const quint64 rx = fields.at(0).toULongLong(&rxOk);
        const quint64 tx = fields.at(8).toULongLong(&txOk);
        if (rxOk && txOk)
            result.insert(name, NetworkCounter{rx, tx});
    }
    return result;
}

QString parseDefaultRouteInterface(const QByteArray &ipv4Routes,
                                   const QByteArray &ipv6Routes)
{
    QString selected;
    quint64 selectedMetric = std::numeric_limits<quint64>::max();

    const auto consider = [&selected, &selectedMetric](
                              const QByteArray &interface,
                              const QByteArray &metricText,
                              int metricBase,
                              const QByteArray &flagsText,
                              int flagsBase) {
        bool metricOk = false;
        bool flagsOk = false;
        const quint64 metric = metricText.toULongLong(&metricOk, metricBase);
        const quint64 flags = flagsText.toULongLong(&flagsOk, flagsBase);
        constexpr quint64 RouteUp = 0x1;
        constexpr quint64 RouteReject = 0x200;
        if (interface.isEmpty() || !metricOk || !flagsOk
            || !(flags & RouteUp) || (flags & RouteReject)
            || metric >= selectedMetric) {
            return;
        }
        selected = QString::fromUtf8(interface);
        selectedMetric = metric;
    };

    for (const QByteArray &raw : ipv4Routes.split('\n')) {
        const QList<QByteArray> fields = raw.simplified().split(' ');
        if (fields.size() < 8 || fields.at(1) != "00000000"
            || fields.at(7) != "00000000") {
            continue;
        }
        consider(fields.at(0), fields.at(6), 10, fields.at(3), 16);
    }

    const QByteArray zeroV6(32, '0');
    for (const QByteArray &raw : ipv6Routes.split('\n')) {
        const QList<QByteArray> fields = raw.simplified().split(' ');
        if (fields.size() < 10 || fields.at(0) != zeroV6
            || fields.at(1) != "00") {
            continue;
        }
        consider(fields.at(9), fields.at(5), 16, fields.at(8), 16);
    }
    return selected;
}

QString composeDeviceCursorKey(const QString &name,
                               const QString &generation,
                               const QString &fallbackIdentity)
{
    if (name.isEmpty())
        return {};
    return name + QLatin1Char('#')
        + (generation.isEmpty()
               ? QStringLiteral("fallback:") + fallbackIdentity
               : QStringLiteral("generation:") + generation);
}

std::optional<DiskCounter> parseDiskStatLine(const QByteArray &contents)
{
    const QList<QByteArray> fields = contents.simplified().split(' ');
    if (fields.size() < 7)
        return std::nullopt;

    bool ok[4] = {false, false, false, false};
    DiskCounter result;
    result.readsCompleted = fields.at(0).toULongLong(&ok[0]);
    result.sectorsRead = fields.at(2).toULongLong(&ok[1]);
    result.writesCompleted = fields.at(4).toULongLong(&ok[2]);
    result.sectorsWritten = fields.at(6).toULongLong(&ok[3]);
    if (!ok[0] || !ok[1] || !ok[2] || !ok[3])
        return std::nullopt;
    return result;
}

ProcessStat parseProcessStat(const QByteArray &contents)
{
    ProcessStat result;
    const qsizetype open = contents.indexOf('(');
    const qsizetype close = contents.lastIndexOf(')');
    if (open <= 0 || close <= open)
        return result;

    bool pidOk = false;
    result.pid = contents.left(open).trimmed().toLongLong(&pidOk);
    result.name = QString::fromUtf8(contents.mid(open + 1, close - open - 1));
    const QList<QByteArray> fields =
        contents.mid(close + 1).simplified().split(' ');
    if (!pidOk || fields.size() < 20)
        return result;

    bool ppidOk = false;
    bool userOk = false;
    bool systemOk = false;
    bool threadsOk = false;
    bool startOk = false;
    result.state = fields.at(0).isEmpty()
        ? QChar()
        : QChar::fromLatin1(fields.at(0).at(0));
    result.ppid = fields.at(1).toLongLong(&ppidOk);
    result.userTicks = fields.at(11).toULongLong(&userOk);
    result.systemTicks = fields.at(12).toULongLong(&systemOk);
    result.threadCount = fields.at(17).toInt(&threadsOk);
    result.startTicks = fields.at(19).toULongLong(&startOk);
    result.valid = ppidOk && userOk && systemOk && threadsOk && startOk;
    return result;
}

OptionalNumber percentageDelta(quint64 previousPart,
                               quint64 currentPart,
                               quint64 previousTotal,
                               quint64 currentTotal)
{
    if (currentPart < previousPart || currentTotal <= previousTotal)
        return std::nullopt;
    const quint64 totalDelta = currentTotal - previousTotal;
    if (totalDelta == 0)
        return std::nullopt;
    const quint64 partDelta = currentPart - previousPart;
    return std::clamp(
        static_cast<double>(partDelta) * 100.0
            / static_cast<double>(totalDelta),
        0.0,
        100.0);
}

OptionalNumber counterRate(quint64 previous, quint64 current, double elapsedSeconds)
{
    if (elapsedSeconds <= 0.0 || current < previous)
        return std::nullopt;
    return static_cast<double>(current - previous) / elapsedSeconds;
}

OptionalNumber processCpuPercent(quint64 previousTicks,
                                 quint64 currentTicks,
                                 long ticksPerSecond,
                                 double elapsedSeconds)
{
    if (currentTicks < previousTicks || ticksPerSecond <= 0
        || elapsedSeconds <= 0.0) {
        return std::nullopt;
    }
    return static_cast<double>(currentTicks - previousTicks) * 100.0
        / (static_cast<double>(ticksPerSecond) * elapsedSeconds);
}

CpuInfo calculateCpuInfo(const CpuCounters &previous, const CpuCounters &current)
{
    CpuInfo result;
    result.available = current.valid;
    if (!previous.valid || !current.valid)
        return result;

    const quint64 previousTotal = previous.total.total();
    const quint64 currentTotal = current.total.total();
    if (currentTotal <= previousTotal)
        return result;

    const OptionalNumber inactive = percentageDelta(
        previous.total.idleTotal(),
        current.total.idleTotal(),
        previousTotal,
        currentTotal);
    if (!inactive)
        return result;

    result.sampleReady = true;
    result.usagePercent = std::clamp(100.0 - *inactive, 0.0, 100.0);
    result.userPercent = percentageDelta(
        previous.total.user + previous.total.nice,
        current.total.user + current.total.nice,
        previousTotal,
        currentTotal);
    result.systemPercent = percentageDelta(
        previous.total.system + previous.total.irq + previous.total.softirq,
        current.total.system + current.total.irq + current.total.softirq,
        previousTotal,
        currentTotal);
    result.idlePercent = percentageDelta(
        previous.total.idle,
        current.total.idle,
        previousTotal,
        currentTotal);
    result.iowaitPercent = percentageDelta(
        previous.total.iowait,
        current.total.iowait,
        previousTotal,
        currentTotal);

    QHash<int, CpuTimes> previousCores;
    previousCores.reserve(previous.cores.size());
    for (const CpuCounters::Core &core : previous.cores)
        previousCores.insert(core.id, core.times);

    result.coreIds.reserve(current.cores.size());
    result.coreUsagePercent.reserve(current.cores.size());
    for (const CpuCounters::Core &currentCore : current.cores) {
        result.coreIds.push_back(currentCore.id);
        const auto previousCore = previousCores.constFind(currentCore.id);
        if (previousCore == previousCores.cend()) {
            result.coreUsagePercent.push_back(std::nullopt);
            continue;
        }
        const CpuTimes &before = *previousCore;
        const CpuTimes &after = currentCore.times;
        const OptionalNumber coreIdle = percentageDelta(
            before.idleTotal(), after.idleTotal(), before.total(), after.total());
        result.coreUsagePercent.push_back(
            coreIdle
                ? OptionalNumber(std::clamp(100.0 - *coreIdle, 0.0, 100.0))
                : std::nullopt);
    }
    return result;
}

MemoryInfo calculateMemoryInfo(const MemoryCounters &counters)
{
    MemoryInfo result;
    result.available = counters.valid;
    if (!counters.valid)
        return result;

    result.totalBytes = kibToBytes(counters.memTotalKiB);
    result.availableBytes =
        kibToBytes(std::min(counters.memAvailableKiB, counters.memTotalKiB));
    result.usedBytes = result.totalBytes - result.availableBytes;
    result.freeBytes =
        kibToBytes(std::min(counters.memFreeKiB, counters.memTotalKiB));
    result.cachedBytes = kibToBytes(counters.cachedKiB);
    result.buffersBytes = kibToBytes(counters.buffersKiB);
    result.swapTotalBytes = kibToBytes(counters.swapTotalKiB);
    const quint64 swapFree =
        std::min(counters.swapFreeKiB, counters.swapTotalKiB);
    result.swapUsedBytes = kibToBytes(counters.swapTotalKiB - swapFree);
    result.usagePercent = result.totalBytes > 0
        ? OptionalNumber(static_cast<double>(result.usedBytes) * 100.0
                         / static_cast<double>(result.totalBytes))
        : std::nullopt;
    return result;
}

} // namespace Clavis::Sysmon
