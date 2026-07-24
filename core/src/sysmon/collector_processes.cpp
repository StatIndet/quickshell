#include "collector.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>

#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <limits>

namespace Clavis::Sysmon {

namespace {

QByteArray readAll(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

QString userNameForUid(uid_t uid)
{
    long suggested = ::sysconf(_SC_GETPW_R_SIZE_MAX);
    if (suggested < 1024)
        suggested = 16384;
    QByteArray buffer(static_cast<qsizetype>(suggested), Qt::Uninitialized);
    struct passwd entry {};
    struct passwd *result = nullptr;
    if (::getpwuid_r(uid,
                     &entry,
                     buffer.data(),
                     static_cast<size_t>(buffer.size()),
                     &result)
            == 0
        && result && result->pw_name) {
        return QString::fromLocal8Bit(result->pw_name);
    }
    return QString::number(uid);
}

QString processStateName(QChar state)
{
    switch (state.toLatin1()) {
    case 'R':
        return QStringLiteral("running");
    case 'S':
        return QStringLiteral("sleeping");
    case 'D':
        return QStringLiteral("disk-sleep");
    case 'Z':
        return QStringLiteral("zombie");
    case 'T':
    case 't':
        return QStringLiteral("stopped");
    case 'X':
    case 'x':
        return QStringLiteral("dead");
    case 'I':
        return QStringLiteral("idle");
    default:
        return state.isNull() ? QStringLiteral("unknown") : QString(state);
    }
}

QString fullCommand(const QByteArray &raw, const QString &fallback)
{
    if (raw.isEmpty())
        return fallback;
    QList<QByteArray> arguments = raw.split('\0');
    while (!arguments.isEmpty() && arguments.last().isEmpty())
        arguments.removeLast();
    QStringList decoded;
    decoded.reserve(arguments.size());
    for (const QByteArray &argument : arguments)
        decoded.push_back(QString::fromLocal8Bit(argument));
    const QString command = decoded.join(QLatin1Char(' ')).trimmed();
    return command.isEmpty() ? fallback : command;
}

} // namespace

QVector<RawProcessInfo> LinuxCollector::collectProcesses(
    quint64 totalMemoryBytes,
    qint64 bootTimeMs,
    QVector<Error> *errors) const
{
    QVector<RawProcessInfo> result;
    const QDir proc(QStringLiteral("/proc"));
    const QStringList entries =
        proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable);
    const long pageSize = ::sysconf(_SC_PAGESIZE);
    const long clockTicks = ::sysconf(_SC_CLK_TCK);
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    int permissionFailures = 0;
    QHash<uint, QString> users;

    result.reserve(entries.size());
    for (const QString &entry : entries) {
        bool pidOk = false;
        const qint64 pid = entry.toLongLong(&pidOk);
        if (!pidOk || pid <= 0)
            continue;

        const QString base = proc.absoluteFilePath(entry);
        const ProcessStat stat =
            parseProcessStat(readAll(base + QStringLiteral("/stat")));
        if (!stat.valid || stat.pid != pid)
            continue; // The process may have exited between directory and read.

        RawProcessInfo process;
        process.info.pid = pid;
        process.info.ppid = stat.ppid;
        process.info.name = stat.name;
        process.info.state = processStateName(stat.state);
        process.info.threadCount = stat.threadCount;
        process.cpuTicks = stat.userTicks + stat.systemTicks;
        process.startTicks = stat.startTicks;
        process.info.processStartTicks = stat.startTicks;
        if (clockTicks > 0 && bootTimeMs > 0) {
            process.info.startTimeMs =
                bootTimeMs
                + static_cast<qint64>(
                    static_cast<long double>(stat.startTicks) * 1000.0L
                    / static_cast<long double>(clockTicks));
            process.info.runtimeSeconds =
                std::max<qint64>(
                    0,
                    (nowMs - process.info.startTimeMs) / 1000);
        }

        const QList<QByteArray> statm =
            readAll(base + QStringLiteral("/statm")).simplified().split(' ');
        if (statm.size() >= 2 && pageSize > 0) {
            bool rssOk = false;
            const quint64 pages = statm.at(1).toULongLong(&rssOk);
            if (rssOk
                && pages
                    <= std::numeric_limits<quint64>::max()
                        / static_cast<quint64>(pageSize)) {
                process.info.memoryBytes =
                    pages * static_cast<quint64>(pageSize);
                if (totalMemoryBytes > 0) {
                    process.info.memoryPercent =
                        static_cast<double>(process.info.memoryBytes) * 100.0
                        / static_cast<double>(totalMemoryBytes);
                }
            }
        }

        process.info.command = fullCommand(
            readAll(base + QStringLiteral("/cmdline")), process.info.name);
        process.info.executablePath =
            QFileInfo(base + QStringLiteral("/exe")).symLinkTarget();

        const QFileInfo directoryInfo(base);
        const uint uid = directoryInfo.ownerId();
        if (uid == std::numeric_limits<uint>::max()) {
            ++permissionFailures;
        } else {
            auto user = users.constFind(uid);
            if (user == users.cend()) {
                user = users.insert(
                    uid,
                    userNameForUid(static_cast<uid_t>(uid)));
            }
            process.info.user = *user;
        }
        result.push_back(process);
    }

    if (result.isEmpty()) {
        errors->push_back({
            QStringLiteral("processes"),
            QStringLiteral("processes_unavailable"),
            QStringLiteral("No readable processes were found in /proc"),
        });
    } else if (permissionFailures > 0) {
        errors->push_back({
            QStringLiteral("processes"),
            QStringLiteral("partial_permissions"),
            QStringLiteral("Some process owners were not readable"),
        });
    }
    return result;
}

} // namespace Clavis::Sysmon
