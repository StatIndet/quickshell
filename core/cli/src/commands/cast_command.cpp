#include "cast_command.h"

#include "niri_cast_parser.h"
#include "niri_ipc_client.h"
#include "recording/recording_types.h"

#include <QJsonArray>

using namespace Clavis::Recording;

CommandResult CastCommand::run(const QStringList &arguments) const
{
    const bool jsonRequested = arguments.contains(QStringLiteral("--json"));
    if (arguments.isEmpty()
        || (arguments.first() != QStringLiteral("list")
            && arguments.first() != QStringLiteral("status"))) {
        const RecordingError error =
            makeError(QStringLiteral("usage_error"),
                      QStringLiteral("Cast action must be 'list' or 'status'"));
        return {
            UsageError,
            jsonRequested,
            {{QStringLiteral("schemaVersion"), SchemaVersion},
             {QStringLiteral("command"), QStringLiteral("cast")},
             {QStringLiteral("ok"), false},
             {QStringLiteral("error"), error.toJson()}},
            error.message,
            true,
        };
    }

    const QString action = arguments.first();
    for (const QString &argument : arguments.mid(1)) {
        if (argument != QStringLiteral("--json")) {
            const RecordingError error =
                makeError(QStringLiteral("usage_error"),
                          QStringLiteral("Unknown cast option: %1").arg(argument));
            return {
                UsageError,
                jsonRequested,
                {{QStringLiteral("schemaVersion"), SchemaVersion},
                 {QStringLiteral("command"), QStringLiteral("cast.%1").arg(action)},
                 {QStringLiteral("ok"), false},
                 {QStringLiteral("error"), error.toJson()}},
                error.message,
                true,
            };
        }
    }

    NiriIpcClient client;
    QString ipcError;
    QObject::connect(&client, &NiriIpcClient::errorOccurred,
                     [&ipcError](const QString &message) { ipcError = message; });
    bool ok = false;
    const QJsonValue response = client.sendRequest(QStringLiteral("Casts"), &ok);
    if (!ok || !response.isArray()) {
        const RecordingError error =
            makeError(QStringLiteral("niri_unavailable"),
                      ipcError.isEmpty() ? QStringLiteral("Unable to query niri casts") : ipcError);
        return {
            NiriUnavailable,
            jsonRequested,
            {{QStringLiteral("schemaVersion"), SchemaVersion},
             {QStringLiteral("command"), QStringLiteral("cast.%1").arg(action)},
             {QStringLiteral("ok"), false},
             {QStringLiteral("casts"), QJsonArray{}},
             {QStringLiteral("anyCastPresent"), false},
             {QStringLiteral("anyCastActive"), false},
             {QStringLiteral("activeCastCount"), 0},
             {QStringLiteral("error"), error.toJson()}},
            QStringLiteral("Error [%1]: %2").arg(error.code, error.message),
            true,
        };
    }

    const QList<NiriCast> casts = NiriCastParser::parseArray(response.toArray());
    QJsonArray jsonCasts;
    QStringList lines;
    for (const NiriCast &cast : casts) {
        jsonCasts.append(NiriCastParser::toJson(cast));
        lines << QStringLiteral("Stream %1: %2, target=%3, pid=%4")
                     .arg(cast.streamId)
                     .arg(cast.isActive ? QStringLiteral("active") : QStringLiteral("inactive"),
                          cast.targetType)
                     .arg(cast.pid);
    }
    const int activeCount = NiriCastParser::activeCount(casts);
    if (action == QStringLiteral("status")) {
        lines.prepend(activeCount > 0
                          ? QStringLiteral("The screen is currently being captured (%1 active cast(s)).")
                                .arg(activeCount)
                          : QStringLiteral("The screen is not currently being captured."));
    } else if (casts.isEmpty()) {
        lines << QStringLiteral("No niri casts are present.");
    }

    return {
        Success,
        jsonRequested,
        {{QStringLiteral("schemaVersion"), SchemaVersion},
         {QStringLiteral("command"), QStringLiteral("cast.%1").arg(action)},
         {QStringLiteral("ok"), true},
         {QStringLiteral("casts"), jsonCasts},
         {QStringLiteral("anyCastPresent"), !casts.isEmpty()},
         {QStringLiteral("anyCastActive"), activeCount > 0},
         {QStringLiteral("activeCastCount"), activeCount},
         {QStringLiteral("error"), QJsonValue(QJsonValue::Null)}},
        lines.join(QLatin1Char('\n')),
        false,
    };
}
