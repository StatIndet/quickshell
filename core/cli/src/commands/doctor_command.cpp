#include "doctor_command.h"

#include "recording/dependency_probe.h"

#include <QDir>
#include <QJsonArray>

using namespace Clavis::Recording;

CommandResult DoctorCommand::run(const QStringList &arguments) const
{
    const bool jsonRequested = arguments.contains(QStringLiteral("--json"));
    QString outputDirectory;
    for (int index = 0; index < arguments.size(); ++index) {
        const QString argument = arguments.at(index);
        if (argument == QStringLiteral("--json"))
            continue;
        if (argument == QStringLiteral("--output") && index + 1 < arguments.size()) {
            outputDirectory = arguments.at(++index);
            continue;
        }
        const RecordingError error =
            makeError(QStringLiteral("usage_error"),
                      QStringLiteral("Unknown or incomplete doctor option: %1").arg(argument));
        return {
            UsageError,
            jsonRequested,
            {{QStringLiteral("schemaVersion"), SchemaVersion},
             {QStringLiteral("command"), QStringLiteral("doctor")},
             {QStringLiteral("ok"), false},
             {QStringLiteral("error"), error.toJson()}},
            error.message,
            true,
        };
    }
    if (outputDirectory.startsWith(QStringLiteral("~/")))
        outputDirectory.replace(0, 1, QDir::homePath());

    const QList<DependencyCheck> checks =
        DependencyProbe().run(outputDirectory, true);
    const bool ok = DependencyProbe::allPassed(checks);
    QJsonArray checksJson;
    QStringList lines;
    lines << QStringLiteral("Clavis Shell diagnostics:");
    for (const DependencyCheck &check : checks) {
        checksJson.append(check.toJson());
        lines << QStringLiteral("  [%1] %2: %3%4")
                     .arg(check.ok ? QStringLiteral("OK") : QStringLiteral("FAIL"),
                          check.name,
                          check.message,
                          check.path.isEmpty() ? QString()
                                               : QStringLiteral(" (%1)").arg(check.path));
    }

    const RecordingError error =
        ok ? RecordingError{}
           : makeError(QStringLiteral("doctor_failed"),
                       QStringLiteral("One or more required checks failed"));
    return {
        ok ? Success : DependencyFailure,
        jsonRequested,
        {{QStringLiteral("schemaVersion"), SchemaVersion},
         {QStringLiteral("command"), QStringLiteral("doctor")},
         {QStringLiteral("ok"), ok},
         {QStringLiteral("checks"), checksJson},
         {QStringLiteral("error"),
          error.isNull() ? QJsonValue(QJsonValue::Null) : QJsonValue(error.toJson())}},
        lines.join(QLatin1Char('\n')),
        !ok,
    };
}
