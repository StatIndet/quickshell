#include "audio_file_finalizer.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QStandardPaths>

namespace Clavis::Recording {

AudioFinalizeResult AudioFileFinalizer::finalize(
    const AudioRecordingSession &session) const
{
    RecordingError error;
    if (!validate(session.temporaryPath, &error))
        return {false, error};

    if (QFileInfo::exists(session.outputPath)) {
        return {
            false,
            makeError(QStringLiteral("output_already_exists"),
                      QStringLiteral("Refusing to overwrite an existing audio recording"),
                      {{QStringLiteral("path"), session.outputPath}}),
        };
    }
    if (!QFile::rename(session.temporaryPath, session.outputPath)) {
        return {
            false,
            makeError(QStringLiteral("audio_publish_failed"),
                      QStringLiteral("Unable to publish the completed audio recording"),
                      {{QStringLiteral("temporaryPath"), session.temporaryPath},
                       {QStringLiteral("outputPath"), session.outputPath}}),
        };
    }
    return {true, {}};
}

bool AudioFileFinalizer::validate(const QString &path, RecordingError *error) const
{
    const QFileInfo info(path);
    if (!info.isFile() || info.size() <= 0) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_audio_file"),
                               QStringLiteral("The recorded audio file is missing or empty"),
                               {{QStringLiteral("path"), path}});
        }
        return false;
    }

    const QString program =
        QStandardPaths::findExecutable(QStringLiteral("ffprobe"));
    if (program.isEmpty()) {
        if (error) {
            *error = makeError(QStringLiteral("dependency_missing"),
                               QStringLiteral("ffprobe is not installed or not in PATH"),
                               {{QStringLiteral("dependency"), QStringLiteral("ffprobe")}});
        }
        return false;
    }

    QProcess process;
    process.start(program,
                  {QStringLiteral("-v"), QStringLiteral("error"),
                   QStringLiteral("-show_entries"),
                   QStringLiteral("stream=codec_type:format=duration"),
                   QStringLiteral("-of"), QStringLiteral("json"), path});
    if (!process.waitForStarted(3000) || !process.waitForFinished(10000)
        || process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        process.kill();
        process.waitForFinished(1000);
        if (error) {
            *error = makeError(
                QStringLiteral("audio_probe_failed"),
                QStringLiteral("ffprobe could not validate the recorded audio"),
                {{QStringLiteral("path"), path},
                 {QStringLiteral("stderr"),
                  QString::fromLocal8Bit(process.readAllStandardError()).trimmed()}});
        }
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument document =
        QJsonDocument::fromJson(process.readAllStandardOutput(), &parseError);
    bool hasAudio = false;
    for (const QJsonValue &value :
         document.object().value(QStringLiteral("streams")).toArray()) {
        if (value.toObject().value(QStringLiteral("codec_type")).toString()
            == QStringLiteral("audio")) {
            hasAudio = true;
            break;
        }
    }
    bool durationOk = false;
    const double duration =
        document.object()
            .value(QStringLiteral("format"))
            .toObject()
            .value(QStringLiteral("duration"))
            .toString()
            .toDouble(&durationOk);
    if (parseError.error != QJsonParseError::NoError || !hasAudio
        || !durationOk || duration <= 0.0) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_audio_file"),
                               QStringLiteral("The recorded file has no valid audio stream"),
                               {{QStringLiteral("path"), path}});
        }
        return false;
    }
    return true;
}

} // namespace Clavis::Recording
