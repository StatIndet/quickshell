#include "clipboard_command.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>

namespace {

constexpr int SchemaVersion = 1;
constexpr int Success = 0;
constexpr int UsageError = 2;
constexpr int DependencyFailure = 3;
constexpr int RuntimeFailure = 1;
constexpr int DefaultLimit = 100;
constexpr int MaximumLimit = 500;

struct ProcessResult {
    bool started = false;
    bool finished = false;
    int exitCode = -1;
    QByteArray standardOutput;
    QByteArray standardError;
};

ProcessResult runProcess(const QString &program,
                         const QStringList &arguments,
                         const QByteArray &input = {})
{
    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.start();

    ProcessResult result;
    result.started = process.waitForStarted(3000);
    if (!result.started)
        return result;

    if (!input.isNull())
        process.write(input);
    process.closeWriteChannel();
    result.finished = process.waitForFinished(10000);
    if (!result.finished) {
        process.kill();
        process.waitForFinished(1000);
    }

    result.exitCode = process.exitCode();
    result.standardOutput = process.readAllStandardOutput();
    result.standardError = process.readAllStandardError();
    return result;
}

QJsonObject dependencyObject(const QString &cliphist, const QString &wlCopy)
{
    return {
        {QStringLiteral("cliphist"), !cliphist.isEmpty()},
        {QStringLiteral("wlCopy"), !wlCopy.isEmpty()},
    };
}

QJsonObject errorObject(const QString &code, const QString &message)
{
    return {
        {QStringLiteral("code"), code},
        {QStringLiteral("message"), message},
    };
}

CommandResult resultFor(const QString &command,
                        bool jsonRequested,
                        int exitCode,
                        const QJsonObject &extra,
                        const QString &text,
                        bool textIsError)
{
    QJsonObject json{
        {QStringLiteral("schemaVersion"), SchemaVersion},
        {QStringLiteral("command"), command},
        {QStringLiteral("ok"), exitCode == Success},
    };
    for (auto iterator = extra.constBegin(); iterator != extra.constEnd(); ++iterator)
        json.insert(iterator.key(), iterator.value());
    if (!json.contains(QStringLiteral("error")))
        json.insert(QStringLiteral("error"), QJsonValue(QJsonValue::Null));
    return {exitCode, jsonRequested, json, text, textIsError};
}

CommandResult usageFailure(const QString &message, bool jsonRequested)
{
    return resultFor(
        QStringLiteral("clipboard"),
        jsonRequested,
        UsageError,
        {{QStringLiteral("available"), false},
         {QStringLiteral("error"),
          errorObject(QStringLiteral("usage_error"), message)}},
        message,
        true);
}

bool parseId(const QString &value, QString *normalized)
{
    static const QRegularExpression expression(QStringLiteral("^[1-9][0-9]*$"));
    if (!expression.match(value).hasMatch())
        return false;
    bool ok = false;
    const qulonglong id = value.toULongLong(&ok);
    if (!ok || id == 0)
        return false;
    *normalized = QString::number(id);
    return true;
}

QString dependencyMessage(bool cliphistAvailable, bool wlCopyAvailable)
{
    if (!cliphistAvailable && !wlCopyAvailable)
        return QStringLiteral("cliphist and wl-copy are unavailable");
    if (!cliphistAvailable)
        return QStringLiteral("cliphist is unavailable");
    if (!wlCopyAvailable)
        return QStringLiteral("wl-copy is unavailable");
    return {};
}

bool clipboardWatcherRunning()
{
    const QString overrideValue =
        qEnvironmentVariable("CLAVIS_CLIPBOARD_WATCHER_RUNNING").trimmed();
    if (overrideValue == QStringLiteral("1")
        || overrideValue.compare(QStringLiteral("true"),
                                 Qt::CaseInsensitive) == 0) {
        return true;
    }
    if (overrideValue == QStringLiteral("0")
        || overrideValue.compare(QStringLiteral("false"),
                                 Qt::CaseInsensitive) == 0) {
        return false;
    }

    const QDir proc(QStringLiteral("/proc"));
    const QStringList processDirectories =
        proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    static const QRegularExpression numericName(QStringLiteral("^[0-9]+$"));
    for (const QString &directory : processDirectories) {
        if (!numericName.match(directory).hasMatch())
            continue;
        QFile commandLine(
            proc.filePath(directory + QStringLiteral("/cmdline")));
        if (!commandLine.open(QIODevice::ReadOnly))
            continue;
        const QList<QByteArray> arguments =
            commandLine.readAll().split('\0');
        bool hasCliphist = false;
        bool hasStore = false;
        for (const QByteArray &argument : arguments) {
            const QString value = QString::fromLocal8Bit(argument);
            hasCliphist = hasCliphist
                || QFileInfo(value).fileName() == QStringLiteral("cliphist");
            hasStore = hasStore || value == QStringLiteral("store");
        }
        if (hasCliphist && hasStore)
            return true;
    }
    return false;
}

QJsonObject parseEntry(const QByteArray &line)
{
    const qsizetype separator = line.indexOf('\t');
    if (separator <= 0)
        return {};

    const QString id = QString::fromUtf8(line.first(separator));
    QString normalizedId;
    if (!parseId(id, &normalizedId))
        return {};

    const QString preview = QString::fromUtf8(line.sliced(separator + 1));
    static const QRegularExpression imageExpression(
        QStringLiteral("^\\[\\[ binary data ([0-9.]+ [A-Za-z]+) ([^ ]+) ([0-9]+)x([0-9]+) \\]\\]$"));
    const QRegularExpressionMatch imageMatch = imageExpression.match(preview);

    QJsonObject entry{
        {QStringLiteral("id"), normalizedId},
        {QStringLiteral("preview"), preview},
        {QStringLiteral("type"), QStringLiteral("text")},
    };
    if (imageMatch.hasMatch()) {
        entry.insert(QStringLiteral("type"), QStringLiteral("image"));
        entry.insert(QStringLiteral("size"), imageMatch.captured(1));
        entry.insert(QStringLiteral("format"), imageMatch.captured(2));
        entry.insert(QStringLiteral("width"), imageMatch.captured(3).toInt());
        entry.insert(QStringLiteral("height"), imageMatch.captured(4).toInt());
    } else if (preview.contains(QChar::ReplacementCharacter)) {
        entry.insert(QStringLiteral("type"), QStringLiteral("binary"));
    }
    return entry;
}

} // namespace

CommandResult ClipboardCommand::run(const QStringList &arguments) const
{
    const bool jsonRequested =
        arguments.contains(QStringLiteral("--json"))
        || (arguments.contains(QStringLiteral("--format"))
            && arguments.value(arguments.indexOf(QStringLiteral("--format")) + 1)
                == QStringLiteral("json"));
    if (arguments.isEmpty())
        return usageFailure(QStringLiteral("Missing clipboard subcommand"), jsonRequested);

    const QString subcommand = arguments.first();
    const QString cliphist = QStandardPaths::findExecutable(QStringLiteral("cliphist"));
    const QString wlCopy = QStandardPaths::findExecutable(QStringLiteral("wl-copy"));
    const bool cliphistAvailable = !cliphist.isEmpty();
    const bool wlCopyAvailable = !wlCopy.isEmpty();
    const bool watcherRunning =
        cliphistAvailable && clipboardWatcherRunning();
    const QJsonObject dependencies = dependencyObject(cliphist, wlCopy);

    if (subcommand == QStringLiteral("status")) {
        for (int index = 1; index < arguments.size(); ++index) {
            const QString argument = arguments.at(index);
            if (argument == QStringLiteral("--json"))
                continue;
            if (argument == QStringLiteral("--format")
                && arguments.value(index + 1) == QStringLiteral("json")) {
                ++index;
                continue;
            }
            return usageFailure(
                QStringLiteral("Unknown clipboard status option: %1").arg(argument),
                jsonRequested);
        }
        const bool dependenciesAvailable =
            cliphistAvailable && wlCopyAvailable;
        const bool available = dependenciesAvailable && watcherRunning;
        const QString message = !dependenciesAvailable
            ? dependencyMessage(cliphistAvailable, wlCopyAvailable)
            : watcherRunning
                ? QString()
                : QStringLiteral("cliphist watcher is inactive");
        return resultFor(
            QStringLiteral("clipboard.status"),
            jsonRequested,
            available ? Success : DependencyFailure,
            {{QStringLiteral("available"), available},
             {QStringLiteral("canList"), cliphistAvailable},
             {QStringLiteral("canRestore"), dependenciesAvailable},
             {QStringLiteral("watcherRunning"), watcherRunning},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("error"),
              available
                  ? QJsonValue(QJsonValue::Null)
                  : QJsonValue(errorObject(
                      dependenciesAvailable
                          ? QStringLiteral("cliphist_watcher_inactive")
                          : QStringLiteral("clipboard_dependency_unavailable"),
                      message))}},
            available ? QStringLiteral("available") : message,
            !available);
    }

    if (subcommand == QStringLiteral("list")) {
        int limit = DefaultLimit;
        for (int index = 1; index < arguments.size(); ++index) {
            const QString argument = arguments.at(index);
            if (argument == QStringLiteral("--json"))
                continue;
            if (argument == QStringLiteral("--format")
                && arguments.value(index + 1) == QStringLiteral("json")) {
                ++index;
                continue;
            }
            if (argument == QStringLiteral("--limit") && index + 1 < arguments.size()) {
                bool ok = false;
                limit = arguments.at(++index).toInt(&ok);
                if (!ok || limit < 1 || limit > MaximumLimit)
                    return usageFailure(
                        QStringLiteral("Clipboard limit must be between 1 and %1")
                            .arg(MaximumLimit),
                        jsonRequested);
                continue;
            }
            return usageFailure(
                QStringLiteral("Unknown or incomplete clipboard list option: %1")
                    .arg(argument),
                jsonRequested);
        }

        if (!cliphistAvailable) {
            const QString message = dependencyMessage(false, wlCopyAvailable);
            return resultFor(
                QStringLiteral("clipboard.list"),
                jsonRequested,
                DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("canList"), false},
                 {QStringLiteral("canRestore"), false},
                 {QStringLiteral("watcherRunning"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("entries"), QJsonArray{}},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_unavailable"), message)}},
                message,
                true);
        }

        const ProcessResult process = runProcess(cliphist, {QStringLiteral("list")});
        if (!process.started || !process.finished || process.exitCode != 0) {
            const QString message = QStringLiteral("Unable to read clipboard history");
            return resultFor(
                QStringLiteral("clipboard.list"),
                jsonRequested,
                RuntimeFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("canList"), false},
                 {QStringLiteral("canRestore"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("entries"), QJsonArray{}},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_list_failed"), message)}},
                message,
                true);
        }

        QJsonArray entries;
        const QList<QByteArray> lines = process.standardOutput.split('\n');
        for (const QByteArray &rawLine : lines) {
            if (rawLine.isEmpty() || entries.size() >= limit)
                continue;
            const QJsonObject entry = parseEntry(rawLine);
            if (!entry.isEmpty())
                entries.append(entry);
        }
        const bool canRestore = wlCopyAvailable;
        if (entries.isEmpty() && !watcherRunning) {
            const QString message =
                QStringLiteral("cliphist watcher is inactive");
            return resultFor(
                QStringLiteral("clipboard.list"),
                jsonRequested,
                DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("canList"), true},
                 {QStringLiteral("canRestore"), canRestore},
                 {QStringLiteral("watcherRunning"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("entries"), entries},
                 {QStringLiteral("error"),
                  errorObject(
                      QStringLiteral("cliphist_watcher_inactive"),
                      message)}},
                message,
                true);
        }
        return resultFor(
            QStringLiteral("clipboard.list"),
            jsonRequested,
            Success,
            {{QStringLiteral("available"), canRestore},
             {QStringLiteral("canList"), true},
             {QStringLiteral("canRestore"), canRestore},
             {QStringLiteral("watcherRunning"), watcherRunning},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("entries"), entries}},
            QStringLiteral("%1 clipboard entries").arg(entries.size()),
            false);
    }

    if (subcommand == QStringLiteral("clear")) {
        for (int index = 1; index < arguments.size(); ++index) {
            const QString argument = arguments.at(index);
            if (argument == QStringLiteral("--json"))
                continue;
            if (argument == QStringLiteral("--format")
                && arguments.value(index + 1) == QStringLiteral("json")) {
                ++index;
                continue;
            }
            return usageFailure(
                QStringLiteral("Unknown clipboard clear option: %1").arg(argument),
                jsonRequested);
        }
        if (!cliphistAvailable) {
            const QString message = dependencyMessage(false, wlCopyAvailable);
            return resultFor(
                QStringLiteral("clipboard.clear"),
                jsonRequested,
                DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_unavailable"), message)}},
                message,
                true);
        }
        const ProcessResult process = runProcess(cliphist, {QStringLiteral("wipe")});
        const bool ok = process.started && process.finished && process.exitCode == 0;
        const QString message =
            ok ? QStringLiteral("Clipboard history cleared")
               : QStringLiteral("Unable to clear clipboard history");
        return resultFor(
            QStringLiteral("clipboard.clear"),
            jsonRequested,
            ok ? Success : RuntimeFailure,
            {{QStringLiteral("available"), true},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("error"),
              ok ? QJsonValue(QJsonValue::Null)
                 : QJsonValue(errorObject(QStringLiteral("cliphist_clear_failed"),
                                          message))}},
            message,
            !ok);
    }

    if (subcommand == QStringLiteral("restore")
        || subcommand == QStringLiteral("delete")) {
        if (arguments.size() < 2)
            return usageFailure(
                QStringLiteral("Missing clipboard entry id"), jsonRequested);
        QString id;
        if (!parseId(arguments.at(1), &id))
            return usageFailure(
                QStringLiteral("Clipboard entry id must be a positive decimal integer"),
                jsonRequested);
        for (int index = 2; index < arguments.size(); ++index) {
            const QString argument = arguments.at(index);
            if (argument == QStringLiteral("--json"))
                continue;
            if (argument == QStringLiteral("--format")
                && arguments.value(index + 1) == QStringLiteral("json")) {
                ++index;
                continue;
            }
            return usageFailure(
                QStringLiteral("Unknown clipboard %1 option: %2")
                    .arg(subcommand, argument),
                jsonRequested);
        }

        const bool dependenciesAvailable =
            cliphistAvailable && (subcommand != QStringLiteral("restore")
                                  || wlCopyAvailable);
        if (!dependenciesAvailable) {
            const QString message =
                dependencyMessage(cliphistAvailable, wlCopyAvailable);
            return resultFor(
                QStringLiteral("clipboard.") + subcommand,
                jsonRequested,
                DependencyFailure,
                {{QStringLiteral("available"), false},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("clipboard_dependency_unavailable"),
                              message)}},
                message,
                true);
        }

        const QByteArray idInput = id.toUtf8() + '\n';
        if (subcommand == QStringLiteral("delete")) {
            const ProcessResult process =
                runProcess(cliphist, {QStringLiteral("delete")}, idInput);
            const bool ok =
                process.started && process.finished && process.exitCode == 0;
            const QString message =
                ok ? QStringLiteral("Clipboard entry deleted")
                   : QStringLiteral("Unable to delete clipboard entry");
            return resultFor(
                QStringLiteral("clipboard.delete"),
                jsonRequested,
                ok ? Success : RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"),
                  ok ? QJsonValue(QJsonValue::Null)
                     : QJsonValue(errorObject(
                           QStringLiteral("cliphist_delete_failed"), message))}},
                message,
                !ok);
        }

        const ProcessResult decode =
            runProcess(cliphist, {QStringLiteral("decode")}, idInput);
        if (!decode.started || !decode.finished || decode.exitCode != 0) {
            const QString message = QStringLiteral("Unable to decode clipboard entry");
            return resultFor(
                QStringLiteral("clipboard.restore"),
                jsonRequested,
                RuntimeFailure,
                {{QStringLiteral("available"), true},
                 {QStringLiteral("id"), id},
                 {QStringLiteral("dependencies"), dependencies},
                 {QStringLiteral("error"),
                  errorObject(QStringLiteral("cliphist_decode_failed"), message)}},
                message,
                true);
        }

        const ProcessResult copy = runProcess(wlCopy, {}, decode.standardOutput);
        const bool ok = copy.started && copy.finished && copy.exitCode == 0;
        const QString message =
            ok ? QStringLiteral("Clipboard entry restored")
               : QStringLiteral("Unable to write clipboard entry");
        return resultFor(
            QStringLiteral("clipboard.restore"),
            jsonRequested,
            ok ? Success : RuntimeFailure,
            {{QStringLiteral("available"), true},
             {QStringLiteral("id"), id},
             {QStringLiteral("dependencies"), dependencies},
             {QStringLiteral("error"),
              ok ? QJsonValue(QJsonValue::Null)
                 : QJsonValue(errorObject(QStringLiteral("wl_copy_failed"),
                                          message))}},
            message,
            !ok);
    }

    return usageFailure(
        QStringLiteral("Unknown clipboard command: %1").arg(subcommand),
        jsonRequested);
}
