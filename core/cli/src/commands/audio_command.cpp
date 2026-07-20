#include "audio_command.h"

#include "recording/audio/audio_recorder_controller.h"

using namespace Clavis::Recording;

CommandResult AudioCommand::run(const QStringList &arguments) const
{
    const bool jsonRequested = arguments.contains(QStringLiteral("--json"));
    if (arguments.isEmpty()) {
        return usageError(QStringLiteral("audio"),
                          QStringLiteral("Missing audio action"),
                          jsonRequested);
    }

    const QString action = arguments.first();
    if (action == QStringLiteral("status")) {
        for (const QString &argument : arguments.mid(1)) {
            if (argument != QStringLiteral("--json")) {
                return usageError(
                    QStringLiteral("audio.status"),
                    QStringLiteral("Unknown status option: %1").arg(argument),
                    jsonRequested);
            }
        }
        return fromOperation(QStringLiteral("audio.status"),
                             AudioRecorderController().status(), jsonRequested);
    }
    if (action == QStringLiteral("stop")) {
        for (const QString &argument : arguments.mid(1)) {
            if (argument != QStringLiteral("--json")) {
                return usageError(
                    QStringLiteral("audio.stop"),
                    QStringLiteral("Unknown stop option: %1").arg(argument),
                    jsonRequested);
            }
        }
        return fromOperation(QStringLiteral("audio.stop"),
                             AudioRecorderController().stop(), jsonRequested);
    }
    if (action != QStringLiteral("start")) {
        return usageError(
            QStringLiteral("audio"),
            QStringLiteral("Unknown audio action: %1").arg(action),
            jsonRequested);
    }

    AudioStartOptions options;
    for (int index = 1; index < arguments.size(); ++index) {
        const QString argument = arguments.at(index);
        if (argument == QStringLiteral("--json"))
            continue;
        if (argument == QStringLiteral("--source")
            && index + 1 < arguments.size()) {
            if (!parseAudioSourceType(arguments.at(++index), &options.source)) {
                return usageError(
                    QStringLiteral("audio.start"),
                    QStringLiteral("Source must be 'mic' or 'system'"),
                    jsonRequested);
            }
            continue;
        }
        if (argument == QStringLiteral("--output")
            && index + 1 < arguments.size()) {
            options.outputDirectory = arguments.at(++index);
            continue;
        }
        return usageError(
            QStringLiteral("audio.start"),
            QStringLiteral("Unknown or incomplete start option: %1").arg(argument),
            jsonRequested);
    }

    return fromOperation(QStringLiteral("audio.start"),
                         AudioRecorderController().start(options),
                         jsonRequested);
}

CommandResult AudioCommand::fromOperation(
    const QString &command, const AudioOperationResult &operation,
    bool jsonRequested)
{
    QString text;
    if (!operation.ok) {
        text = QStringLiteral("Error [%1]: %2")
                   .arg(operation.error.code, operation.error.message);
    } else if (command == QStringLiteral("audio.start")) {
        text = QStringLiteral("Audio recording started: %1 (PID %2)")
                   .arg(operation.session.outputPath)
                   .arg(operation.session.pid);
    } else if (command == QStringLiteral("audio.stop")) {
        text = QStringLiteral("Audio recording completed: %1")
                   .arg(operation.session.outputPath);
    } else {
        switch (operation.session.state) {
        case AudioRecordingState::Idle:
            text = QStringLiteral("No Clavis audio recording is active.");
            break;
        case AudioRecordingState::Starting:
            text = QStringLiteral("Starting ffmpeg audio recording.");
            break;
        case AudioRecordingState::Recording:
            text = QStringLiteral("Recording %1 audio (PID %2) to %3")
                       .arg(audioSourceTypeName(operation.session.source.type))
                       .arg(operation.session.pid)
                       .arg(operation.session.outputPath);
            break;
        case AudioRecordingState::Stopping:
            text = QStringLiteral("Stopping audio recording.");
            break;
        case AudioRecordingState::Finalizing:
            text = QStringLiteral("Finalizing %1.")
                       .arg(operation.session.outputPath);
            break;
        case AudioRecordingState::Error:
            text = QStringLiteral("Last audio recording failed: %1")
                       .arg(operation.session.error.message);
            break;
        }
    }

    return {
        operation.exitCode,
        jsonRequested,
        operation.toJson(command),
        text,
        !operation.ok,
    };
}

CommandResult AudioCommand::usageError(const QString &command,
                                       const QString &message,
                                       bool jsonRequested)
{
    const RecordingError error =
        makeError(QStringLiteral("usage_error"), message);
    AudioOperationResult operation;
    operation.exitCode = UsageError;
    operation.session = idleAudioSession();
    operation.error = error;
    return {
        UsageError,
        jsonRequested,
        operation.toJson(command),
        message,
        true,
    };
}
