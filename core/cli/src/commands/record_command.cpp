#include "record_command.h"

#include "recording/recorder_controller.h"

using namespace Clavis::Recording;

CommandResult RecordCommand::run(const QStringList &arguments) const
{
    const bool jsonRequested = arguments.contains(QStringLiteral("--json"));
    if (arguments.isEmpty())
        return usageError(QStringLiteral("record"), QStringLiteral("Missing record action"),
                          jsonRequested);

    const QString action = arguments.first();
    if (action == QStringLiteral("status")) {
        for (const QString &argument : arguments.mid(1)) {
            if (argument != QStringLiteral("--json"))
                return usageError(QStringLiteral("record.status"),
                                  QStringLiteral("Unknown status option: %1").arg(argument),
                                  jsonRequested);
        }
        return fromOperation(QStringLiteral("record.status"), RecorderController().status(),
                             jsonRequested);
    }
    if (action == QStringLiteral("stop")) {
        for (const QString &argument : arguments.mid(1)) {
            if (argument != QStringLiteral("--json"))
                return usageError(QStringLiteral("record.stop"),
                                  QStringLiteral("Unknown stop option: %1").arg(argument),
                                  jsonRequested);
        }
        return fromOperation(QStringLiteral("record.stop"), RecorderController().stop(),
                             jsonRequested);
    }
    if (action != QStringLiteral("start"))
        return usageError(QStringLiteral("record"),
                          QStringLiteral("Unknown record action: %1").arg(action),
                          jsonRequested);

    StartOptions options;
    for (int index = 1; index < arguments.size(); ++index) {
        const QString argument = arguments.at(index);
        if (argument == QStringLiteral("--json"))
            continue;
        if (argument == QStringLiteral("--type") && index + 1 < arguments.size()) {
            if (!parseRecordingType(arguments.at(++index), &options.type)) {
                return usageError(QStringLiteral("record.start"),
                                  QStringLiteral("Type must be 'video' or 'gif'"),
                                  jsonRequested);
            }
            continue;
        }
        if (argument == QStringLiteral("--target") && index + 1 < arguments.size()) {
            options.target = arguments.at(++index);
            continue;
        }
        if (argument == QStringLiteral("--geometry") && index + 1 < arguments.size()) {
            options.geometry = arguments.at(++index);
            continue;
        }
        if (argument == QStringLiteral("--audio") && index + 1 < arguments.size()) {
            options.audio = arguments.at(++index);
            continue;
        }
        if (argument == QStringLiteral("--fps") && index + 1 < arguments.size()) {
            bool ok = false;
            options.fps = arguments.at(++index).toInt(&ok);
            if (!ok) {
                return usageError(QStringLiteral("record.start"),
                                  QStringLiteral("FPS must be a number"), jsonRequested);
            }
            continue;
        }
        if (argument == QStringLiteral("--output") && index + 1 < arguments.size()) {
            options.outputDirectory = arguments.at(++index);
            continue;
        }
        return usageError(QStringLiteral("record.start"),
                          QStringLiteral("Unknown or incomplete start option: %1").arg(argument),
                          jsonRequested);
    }

    return fromOperation(QStringLiteral("record.start"), RecorderController().start(options),
                         jsonRequested);
}

CommandResult RecordCommand::fromOperation(const QString &command,
                                           const OperationResult &operation,
                                           bool jsonRequested)
{
    QString text;
    if (operation.cancelled) {
        text = QStringLiteral("Region selection cancelled.");
    } else if (!operation.ok) {
        text = QStringLiteral("Error [%1]: %2")
                   .arg(operation.error.code, operation.error.message);
    } else if (command == QStringLiteral("record.start")) {
        text = QStringLiteral("Recording started: %1 (PID %2)")
                   .arg(operation.session.outputPath)
                   .arg(operation.session.pid);
    } else if (command == QStringLiteral("record.stop")) {
        text = QStringLiteral("Recording completed: %1").arg(operation.session.outputPath);
    } else {
        switch (operation.session.state) {
        case RecordingState::Idle:
            text = QStringLiteral("No Clavis recording is active.");
            break;
        case RecordingState::Selecting:
            text = QStringLiteral("Waiting for a region selection.");
            break;
        case RecordingState::Starting:
            text = QStringLiteral("Starting gpu-screen-recorder.");
            break;
        case RecordingState::Recording:
            text = QStringLiteral("Recording %1 (PID %2) to %3")
                       .arg(recordingTypeName(operation.session.type))
                       .arg(operation.session.pid)
                       .arg(operation.session.outputPath);
            break;
        case RecordingState::Finalizing:
            text = QStringLiteral("Finalizing %1.").arg(operation.session.outputPath);
            break;
        case RecordingState::Completed:
            text = QStringLiteral("Last recording completed: %1")
                       .arg(operation.session.outputPath);
            break;
        }
    }

    return {
        operation.exitCode,
        jsonRequested,
        operation.toJson(command),
        text,
        !operation.ok && !operation.cancelled,
    };
}

CommandResult RecordCommand::usageError(const QString &command, const QString &message,
                                        bool jsonRequested)
{
    const RecordingError error = makeError(QStringLiteral("usage_error"), message);
    OperationResult operation;
    operation.exitCode = UsageError;
    operation.session = idleSession();
    operation.error = error;
    return {UsageError, jsonRequested, operation.toJson(command), message, true};
}
