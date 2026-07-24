#include "top_command.h"

#include "sysmon/sampler.h"
#include "tui/top_tui.h"

#include <QByteArray>

#include <exception>
#include <unistd.h>

namespace {

constexpr int SuccessExit = 0;
constexpr int FailureExit = 1;
constexpr int UsageExit = 2;

CommandResult usageError(const QString &message)
{
    return {
        UsageExit,
        false,
        {},
        message + QStringLiteral("\n\n") + TopCommand::helpText(),
        true,
    };
}

} // namespace

CommandResult TopCommand::run(const QStringList &arguments) const
{
    TopTui::Options options;

    for (int index = 0; index < arguments.size(); ++index) {
        const QString &argument = arguments.at(index);
        if (argument == QStringLiteral("--help")
            || argument == QStringLiteral("-h")) {
            if (arguments.size() != 1)
                return usageError(QStringLiteral("--help cannot be combined with other options"));
            return {SuccessExit, false, {}, helpText(), false};
        }
        if (argument == QStringLiteral("--ascii")) {
            options.forceAscii = true;
            continue;
        }
        if (argument == QStringLiteral("--interval")
            && index + 1 < arguments.size()) {
            bool ok = false;
            const int interval = arguments.at(++index).toInt(&ok);
            if (!ok || interval < 250 || interval > 60000) {
                return usageError(
                    QStringLiteral("--interval must be between 250 and 60000 milliseconds"));
            }
            options.refreshIntervalMs = interval;
            continue;
        }
        return usageError(
            QStringLiteral("Unknown or incomplete top option: %1").arg(argument));
    }

    if (!::isatty(STDIN_FILENO) || !::isatty(STDOUT_FILENO)) {
        return {
            UsageExit,
            false,
            {},
            QStringLiteral(
                "key top requires an interactive terminal on stdin and stdout.\n"
                "Run it directly in a terminal; use 'key sysmon stream' for pipes."),
            true,
        };
    }

    const QByteArray term = qgetenv("TERM");
    if (term.isEmpty() || term == QByteArrayLiteral("dumb")) {
        return {
            UsageExit,
            false,
            {},
            QStringLiteral(
                "key top requires a usable TERM definition (TERM is unset or 'dumb')."),
            true,
        };
    }

    try {
        Clavis::Sysmon::Sampler sampler;
        TopTui tui(sampler, options);
        const int exitCode = tui.run();
        if (exitCode != SuccessExit) {
            return {
                exitCode == UsageExit ? UsageExit : FailureExit,
                false,
                {},
                tui.errorMessage().isEmpty()
                    ? QStringLiteral("key top could not initialize the terminal.")
                    : tui.errorMessage(),
                true,
            };
        }
    } catch (const std::exception &error) {
        return {
            FailureExit,
            false,
            {},
            QStringLiteral("key top failed: %1")
                .arg(QString::fromLocal8Bit(error.what())),
            true,
        };
    } catch (...) {
        return {
            FailureExit,
            false,
            {},
            QStringLiteral("key top failed with an unknown error."),
            true,
        };
    }

    return {SuccessExit, false, {}, {}, false, true};
}

QString TopCommand::helpText()
{
    return QStringLiteral(
        "Clavis interactive system monitor\n"
        "\n"
        "Usage:\n"
        "  key top [--interval MILLISECONDS] [--ascii]\n"
        "  key top --help\n"
        "\n"
        "Options:\n"
        "  --interval MS   refresh every 250..60000 ms (default: 1000)\n"
        "  --ascii         force ASCII-only UI output\n"
        "  -h, --help      show this help without entering the TUI\n"
        "\n"
        "Navigation:\n"
        "  Up/Down, k/j        move the selected process\n"
        "  PageUp/PageDown     move one process page\n"
        "  Tab/Shift+Tab       select the next/previous panel\n"
        "  / or f              filter processes\n"
        "  s                   cycle CPU, memory, PID and name sorting\n"
        "  t                   toggle process tree view\n"
        "  p or Space          pause/resume sampling\n"
        "  Enter               show selected process details\n"
        "  r                   refresh immediately\n"
        "  ?                   show in-app help\n"
        "  Esc                 close the current dialog or input mode\n"
        "  q                   quit\n"
        "\n"
        "Process signals:\n"
        "  K (uppercase) opens the signal confirmation. Enter confirms the\n"
        "  default SIGTERM. Choose SIGKILL with K, then press K a second time\n"
        "  to confirm it. Lowercase k remains the move-up key.\n"
        "\n"
        "Notes:\n"
        "  key top needs an interactive terminal. It restores terminal input,\n"
        "  cursor, colors and the alternate screen on normal or signaled exit.\n"
        "  Set NO_COLOR to disable colors; unsupported Unicode falls back to ASCII.");
}
