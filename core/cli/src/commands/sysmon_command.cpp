#include "sysmon_command.h"

#include "sysmon/sampler.h"
#include "sysmon/serialization.h"
#include "sysmon/types.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QSet>
#include <QTextStream>
#include <QThread>

#include <algorithm>
#include <csignal>
#include <functional>

using namespace Clavis::Sysmon;

namespace {

volatile std::sig_atomic_t streamStopRequested = 0;

void streamSignalHandler(int)
{
    streamStopRequested = 1;
}

class StreamSignalGuard {
public:
    StreamSignalGuard()
    {
        streamStopRequested = 0;
        m_int = std::signal(SIGINT, streamSignalHandler);
        m_term = std::signal(SIGTERM, streamSignalHandler);
        m_hup = std::signal(SIGHUP, streamSignalHandler);
    }

    ~StreamSignalGuard()
    {
        std::signal(SIGINT, m_int);
        std::signal(SIGTERM, m_term);
        std::signal(SIGHUP, m_hup);
    }

private:
    using Handler = void (*)(int);
    Handler m_int = SIG_DFL;
    Handler m_term = SIG_DFL;
    Handler m_hup = SIG_DFL;
};

struct Options {
    QString format;
    ModuleSet modules;
    int intervalMs = 1000;
    int limit = 0;
    QString sort = QStringLiteral("cpu");
    QString filter;
    bool tree = false;
};

CommandResult usageError(const QString &message)
{
    return {
        2,
        false,
        {},
        message + QStringLiteral("\n\n") + SysmonCommand::helpText(),
        true,
    };
}

CommandResult jsonUsageError(const QString &message)
{
    return {
        2,
        true,
        QJsonObject{
            {QStringLiteral("schemaVersion"), SchemaVersion},
            {QStringLiteral("ok"), false},
            {QStringLiteral("error"),
             QJsonObject{
                 {QStringLiteral("code"), QStringLiteral("usage_error")},
                 {QStringLiteral("message"), message},
             }},
        },
        {},
        false,
    };
}

bool parseModules(const QString &value, ModuleSet *modules, QString *error)
{
    modules->clear();
    const ModuleSet supported = allModules();
    const QStringList requested =
        value.split(QLatin1Char(','), Qt::SkipEmptyParts);
    if (requested.isEmpty()) {
        *error = QStringLiteral("--modules requires a comma-separated value");
        return false;
    }
    for (QString module : requested) {
        module = module.trimmed().toLower();
        if (module == QStringLiteral("ram"))
            module = QStringLiteral("memory");
        if (!supported.contains(module)) {
            *error = QStringLiteral("Unknown sysmon module: %1").arg(module);
            return false;
        }
        modules->insert(module);
    }
    return true;
}

bool takeValue(const QStringList &arguments,
               int *index,
               const QString &option,
               QString *value,
               QString *error)
{
    if (*index + 1 >= arguments.size()) {
        *error = QStringLiteral("%1 requires a value").arg(option);
        return false;
    }
    *value = arguments.at(++(*index));
    return true;
}

bool parseOptions(const QStringList &arguments,
                  Options *options,
                  QString *error)
{
    for (int index = 0; index < arguments.size(); ++index) {
        const QString argument = arguments.at(index);
        QString value;
        if (argument == QStringLiteral("--format")) {
            if (!takeValue(arguments, &index, argument, &value, error))
                return false;
            options->format = value.toLower();
        } else if (argument == QStringLiteral("--json")) {
            options->format = QStringLiteral("json");
        } else if (argument == QStringLiteral("--modules")) {
            if (!takeValue(arguments, &index, argument, &value, error)
                || !parseModules(value, &options->modules, error)) {
                return false;
            }
        } else if (argument == QStringLiteral("--interval")) {
            if (!takeValue(arguments, &index, argument, &value, error))
                return false;
            bool ok = false;
            const int interval = value.toInt(&ok);
            if (!ok || interval < 100 || interval > 60000) {
                *error = QStringLiteral(
                    "--interval must be between 100 and 60000 milliseconds");
                return false;
            }
            options->intervalMs = interval;
        } else if (argument == QStringLiteral("--limit")) {
            if (!takeValue(arguments, &index, argument, &value, error))
                return false;
            bool ok = false;
            const int limit = value.toInt(&ok);
            if (!ok || limit < 1 || limit > 100000) {
                *error =
                    QStringLiteral("--limit must be between 1 and 100000");
                return false;
            }
            options->limit = limit;
        } else if (argument == QStringLiteral("--sort")) {
            if (!takeValue(arguments, &index, argument, &value, error))
                return false;
            options->sort = value.toLower();
            if (!QSet<QString>{
                    QStringLiteral("cpu"),
                    QStringLiteral("memory"),
                    QStringLiteral("pid"),
                    QStringLiteral("name"),
                    QStringLiteral("runtime"),
                }.contains(options->sort)) {
                *error = QStringLiteral(
                    "--sort must be cpu, memory, pid, name, or runtime");
                return false;
            }
        } else if (argument == QStringLiteral("--filter")) {
            if (!takeValue(arguments, &index, argument, &value, error))
                return false;
            options->filter = value;
        } else if (argument == QStringLiteral("--tree")) {
            options->tree = true;
        } else {
            *error = QStringLiteral("Unknown option: %1").arg(argument);
            return false;
        }
    }
    return true;
}

bool needsDeltaSample(const ModuleSet &modules)
{
    return modules.contains(QStringLiteral("cpu"))
        || modules.contains(QStringLiteral("disk"))
        || modules.contains(QStringLiteral("network"))
        || modules.contains(QStringLiteral("processes"));
}

Snapshot sampledSnapshot(Sampler *sampler,
                         const ModuleSet &modules,
                         int warmupMs = 200)
{
    Snapshot snapshot = sampler->sample(modules);
    if (needsDeltaSample(modules)) {
        QThread::msleep(static_cast<unsigned long>(warmupMs));
        snapshot = sampler->sample(modules);
    }
    return snapshot;
}

void sortProcesses(QVector<ProcessInfo> *processes, const QString &sort)
{
    std::stable_sort(
        processes->begin(),
        processes->end(),
        [&sort](const ProcessInfo &left, const ProcessInfo &right) {
            if (sort == QStringLiteral("memory"))
                return left.memoryBytes > right.memoryBytes;
            if (sort == QStringLiteral("pid"))
                return left.pid < right.pid;
            if (sort == QStringLiteral("name"))
                return left.name.compare(right.name, Qt::CaseInsensitive) < 0;
            if (sort == QStringLiteral("runtime"))
                return left.runtimeSeconds > right.runtimeSeconds;
            return left.cpuUsagePercent.value_or(-1.0)
                > right.cpuUsagePercent.value_or(-1.0);
        });
}

void filterProcesses(QVector<ProcessInfo> *processes, const QString &filter)
{
    if (filter.isEmpty())
        return;
    const QString needle = filter.toLower();
    processes->erase(
        std::remove_if(
            processes->begin(),
            processes->end(),
            [&needle](const ProcessInfo &process) {
                return !process.name.toLower().contains(needle)
                    && !process.command.toLower().contains(needle)
                    && !process.user.toLower().contains(needle)
                    && !QString::number(process.pid).contains(needle);
            }),
        processes->end());
}

void treeProcesses(QVector<ProcessInfo> *processes)
{
    QHash<qint64, ProcessInfo> byPid;
    QHash<qint64, QVector<qint64>> children;
    QVector<qint64> roots;
    for (const ProcessInfo &process : std::as_const(*processes))
        byPid.insert(process.pid, process);
    for (const ProcessInfo &process : std::as_const(*processes)) {
        if (process.ppid <= 0 || process.ppid == process.pid
            || !byPid.contains(process.ppid)) {
            roots.push_back(process.pid);
        } else {
            children[process.ppid].push_back(process.pid);
        }
    }

    QVector<ProcessInfo> ordered;
    ordered.reserve(processes->size());
    QSet<qint64> visited;
    std::function<void(qint64, int)> append =
        [&](qint64 pid, int depth) {
            if (visited.contains(pid) || !byPid.contains(pid))
                return;
            visited.insert(pid);
            ProcessInfo process = byPid.value(pid);
            process.treeDepth = std::min(depth, 64);
            ordered.push_back(process);
            if (depth >= 64)
                return;
            for (qint64 child : std::as_const(children[pid]))
                append(child, depth + 1);
        };
    for (qint64 pid : std::as_const(roots))
        append(pid, 0);
    for (const ProcessInfo &process : std::as_const(*processes))
        append(process.pid, 0);
    *processes = std::move(ordered);
}

QString processTable(const QVector<ProcessInfo> &processes, bool tree)
{
    QString output;
    QTextStream stream(&output);
    stream << QStringLiteral("%1 %2 %3 %4 %5\n")
                  .arg(QStringLiteral("PID"), -8)
                  .arg(QStringLiteral("CPU%"), -7)
                  .arg(QStringLiteral("MEM%"), -7)
                  .arg(QStringLiteral("USER"), -14)
                  .arg(QStringLiteral("COMMAND"));
    for (const ProcessInfo &process : processes) {
        const QString cpu = process.cpuUsagePercent
            ? QLocale::c().toString(*process.cpuUsagePercent, 'f', 1)
            : QStringLiteral("-");
        const QString memory = process.memoryPercent
            ? QLocale::c().toString(*process.memoryPercent, 'f', 1)
            : QStringLiteral("-");
        QString name = process.command.isEmpty()
            ? process.name
            : process.command;
        if (tree && process.treeDepth > 0)
            name.prepend(QString(process.treeDepth * 2, QLatin1Char(' '))
                         + QStringLiteral("└─"));
        stream << QStringLiteral("%1 %2 %3 %4 %5\n")
                      .arg(QString::number(process.pid), -8)
                      .arg(cpu, -7)
                      .arg(memory, -7)
                      .arg(process.user.left(14), -14)
                      .arg(name);
    }
    return output.trimmed();
}

CommandResult runStream(const Options &options)
{
    const bool jsonl = options.format.isEmpty()
        || options.format == QStringLiteral("jsonl")
        || options.format == QStringLiteral("json");
    if (!jsonl && options.format != QStringLiteral("text"))
        return usageError(QStringLiteral(
            "stream --format must be jsonl or text"));

    StreamSignalGuard signalGuard;
    Sampler sampler;
    QFile output;
    if (!output.open(stdout, QIODevice::WriteOnly | QIODevice::Unbuffered))
        return {3, false, {}, QStringLiteral("Unable to open stdout"), true};

    QElapsedTimer cadence;
    cadence.start();
    while (!streamStopRequested) {
        const Snapshot snapshot = sampler.sample(options.modules);
        const QByteArray bytes = jsonl
            ? snapshotToJsonLine(snapshot)
            : (humanSnapshot(snapshot) + QLatin1Char('\n')).toUtf8();
        if (output.write(bytes) != bytes.size() || !output.flush())
            return {3, false, {}, QStringLiteral("Unable to write sysmon stream"),
                    true, false};

        // Do not try to "catch up" with back-to-back collection if a slow
        // sensor probe already exceeded the requested interval.
        const qint64 nextDeadlineMs = cadence.elapsed() + options.intervalMs;
        while (!streamStopRequested) {
            const qint64 remaining = nextDeadlineMs - cadence.elapsed();
            if (remaining <= 0)
                break;
            QThread::msleep(
                static_cast<unsigned long>(std::min<qint64>(remaining, 50)));
        }
    }
    return {0, false, {}, {}, false, true};
}

} // namespace

CommandResult SysmonCommand::run(const QStringList &arguments) const
{
    if (arguments.isEmpty() || arguments.first() == QStringLiteral("--help")
        || arguments.first() == QStringLiteral("-h")) {
        return {0, false, {}, helpText(), false};
    }

    const QString subcommand = arguments.first().toLower();
    if (subcommand == QStringLiteral("modules")) {
        Options options;
        options.modules = defaultModules();
        QString error;
        if (!parseOptions(arguments.mid(1), &options, &error))
            return usageError(error);
        if (!options.format.isEmpty()
            && options.format != QStringLiteral("json")
            && options.format != QStringLiteral("text")) {
            return usageError(QStringLiteral(
                "modules output --format must be json or text"));
        }
        if (options.format == QStringLiteral("json")) {
            QJsonArray modules;
            for (const QString &name : orderedModuleNames())
                modules.push_back(name);
            return {
                0,
                true,
                QJsonObject{
                    {QStringLiteral("schemaVersion"), SchemaVersion},
                    {QStringLiteral("modules"), modules},
                },
                {},
                false,
            };
        }
        return {
            0,
            false,
            {},
            QStringLiteral(
                "system\ncpu\nmemory\ngpu\ndisk\nnetwork\nbattery\nprocesses"),
            false,
        };
    }

    Options options;
    options.modules = defaultModules();
    options.limit = subcommand == QStringLiteral("processes") ? 20 : 0;
    if (subcommand == QStringLiteral("stream"))
        options.format = QStringLiteral("jsonl");

    QString error;
    if (!parseOptions(arguments.mid(1), &options, &error)) {
        const bool json =
            arguments.contains(QStringLiteral("--json"))
            || (arguments.contains(QStringLiteral("--format"))
                && arguments.value(
                       arguments.indexOf(QStringLiteral("--format")) + 1)
                    .startsWith(QStringLiteral("json")));
        return json ? jsonUsageError(error) : usageError(error);
    }

    static const QSet<QString> moduleCommands{
        QStringLiteral("system"),
        QStringLiteral("cpu"),
        QStringLiteral("memory"),
        QStringLiteral("gpu"),
        QStringLiteral("disk"),
        QStringLiteral("network"),
        QStringLiteral("battery"),
    };
    if (moduleCommands.contains(subcommand))
        options.modules = ModuleSet{subcommand};
    else if (subcommand == QStringLiteral("processes"))
        options.modules = ModuleSet{
            QStringLiteral("system"),
            QStringLiteral("memory"),
            QStringLiteral("processes"),
        };
    else if (subcommand != QStringLiteral("snapshot")
             && subcommand != QStringLiteral("stream")) {
        return usageError(
            QStringLiteral("Unknown sysmon command: %1").arg(subcommand));
    }

    if (subcommand == QStringLiteral("stream"))
        return runStream(options);

    if (!options.format.isEmpty()
        && options.format != QStringLiteral("json")
        && options.format != QStringLiteral("text")) {
        return usageError(QStringLiteral(
            "snapshot output --format must be json or text"));
    }

    Sampler sampler;
    Snapshot snapshot = sampledSnapshot(&sampler, options.modules);
    if (subcommand == QStringLiteral("processes")) {
        filterProcesses(&snapshot.processes, options.filter);
        sortProcesses(&snapshot.processes, options.sort);
        if (options.tree)
            treeProcesses(&snapshot.processes);
        if (options.limit > 0
            && snapshot.processes.size() > options.limit) {
            snapshot.processes.resize(options.limit);
        }
    }

    if (options.format == QStringLiteral("json")) {
        return {0, true, snapshotToJson(snapshot), {}, false};
    }
    if (subcommand == QStringLiteral("processes")) {
        return {
            0,
            false,
            {},
            processTable(snapshot.processes, options.tree),
            false,
        };
    }
    return {0, false, {}, humanSnapshot(snapshot), false};
}

QString SysmonCommand::helpText()
{
    return QStringLiteral(
        "Clavis system monitor\n"
        "\n"
        "Usage:\n"
        "  key sysmon snapshot [--format json|text] [--modules LIST]\n"
        "  key sysmon stream [--format jsonl|text] [--interval MS] "
        "[--modules LIST]\n"
        "  key sysmon system|cpu|memory|gpu|disk|network|battery "
        "[--format json|text]\n"
        "  key sysmon processes [--sort FIELD] [--limit N] "
        "[--filter TEXT] [--tree] [--format json|text]\n"
        "  key sysmon modules [--format json]\n"
        "\n"
        "Modules:\n"
        "  system,cpu,memory,gpu,disk,network,battery,processes\n"
        "\n"
        "Process sort fields:\n"
        "  cpu, memory, pid, name, runtime\n"
        "\n"
        "Notes:\n"
        "  JSON uses schemaVersion 1. Unavailable numeric metrics are null.\n"
        "  stream emits one complete JSON object per line and flushes each line.\n"
        "  processes are collected only when explicitly requested.\n"
        "\n"
        "Exit codes:\n"
        "  0 success (including partial sensors), 2 usage, 3 output failure.\n");
}
