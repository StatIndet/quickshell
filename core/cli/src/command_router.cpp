#include "command_router.h"

#include "commands/audio_command.h"
#include "commands/cast_command.h"
#include "commands/doctor_command.h"
#include "commands/record_command.h"
#include "commands/sysmon_command.h"
#include "commands/top_command.h"
#include "recording/recording_types.h"

#include <QCoreApplication>

using namespace Clavis::Recording;

CommandResult CommandRouter::route(const QStringList &arguments) const
{
    if (arguments.isEmpty() || arguments.first() == QStringLiteral("--help")
        || arguments.first() == QStringLiteral("-h")) {
        return {Success, false, {}, helpText(), false};
    }
    if (arguments.first() == QStringLiteral("--version")
        || arguments.first() == QStringLiteral("-v")) {
        return {
            Success,
            false,
            {},
            QStringLiteral("key %1").arg(QCoreApplication::applicationVersion()),
            false,
        };
    }

    const QString command = arguments.first();
    const QStringList rest = arguments.mid(1);
    if (command == QStringLiteral("doctor"))
        return DoctorCommand().run(rest);
    if (command == QStringLiteral("audio"))
        return AudioCommand().run(rest);
    if (command == QStringLiteral("record"))
        return RecordCommand().run(rest);
    if (command == QStringLiteral("cast"))
        return CastCommand().run(rest);
    if (command == QStringLiteral("sysmon"))
        return SysmonCommand().run(rest);
    if (command == QStringLiteral("top"))
        return TopCommand().run(rest);
    return usageError(QStringLiteral("Unknown command: %1").arg(command),
                      arguments.contains(QStringLiteral("--json")));
}

QString CommandRouter::helpText()
{
    return QStringLiteral(
        "Clavis Shell command line interface\n"
        "\n"
        "Usage:\n"
        "  key [--help] [--version]\n"
        "  key doctor [--json] [--output DIRECTORY]\n"
        "  key audio start --source mic|system [--output DIRECTORY] [--json]\n"
        "  key audio status [--json]\n"
        "  key audio stop [--json]\n"
        "  key record start --type video|gif --geometry WIDTHxHEIGHT+X+Y [options]\n"
        "  key record status [--json]\n"
        "  key record stop [--json]\n"
        "  key cast list [--json]\n"
        "  key cast status [--json]\n"
        "  key sysmon snapshot [--format json] [--modules LIST]\n"
        "  key sysmon stream [--format jsonl] [--interval MS] [--modules LIST]\n"
        "  key sysmon system|cpu|memory|gpu|disk|network|battery [--format json]\n"
        "  key sysmon processes [--sort FIELD] [--limit N] [--filter TEXT] [--tree]\n"
        "  key top\n"
        "\n"
        "Recording options:\n"
        "  --type TYPE         video or gif (default: video)\n"
        "  --target TARGET     region (default: region)\n"
        "  --geometry REGION   required compositor-logical WIDTHxHEIGHT+X+Y\n"
        "  --audio SOURCE      none or system (default: none)\n"
        "  --fps NUMBER        capture rate from 1 to 240 (default: 60)\n"
        "  --output DIRECTORY  output directory\n"
        "  --json              stable machine-readable output\n"
        "\n"
        "Exit codes:\n"
        "  0 success, 1 runtime/TUI, 2 usage, 3 dependency/output\n"
        "  4 session conflict\n"
        "  5 state, 6 recorder start, 7 recorder stop, 8 post-process\n"
        "  11 niri unavailable\n");
}

CommandResult CommandRouter::usageError(const QString &message, bool jsonRequested)
{
    const RecordingError error = makeError(QStringLiteral("usage_error"), message);
    return {
        UsageError,
        jsonRequested,
        QJsonObject{
            {QStringLiteral("schemaVersion"), SchemaVersion},
            {QStringLiteral("command"), QStringLiteral("unknown")},
            {QStringLiteral("ok"), false},
            {QStringLiteral("error"), error.toJson()},
        },
        message + QStringLiteral("\n\n") + helpText(),
        true,
    };
}
