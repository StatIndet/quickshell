#include "ffmpeg_postprocessor.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QStandardPaths>

namespace Clavis::Recording {

PostprocessResult FfmpegPostprocessor::finalize(const RecordingSession &session,
                                                int timeoutMs) const
{
    RecordingError error;
    if (!validateMedia(session.temporaryPath, &error))
        return {false, {}, error};
    return session.type == RecordingType::Gif ? finalizeGif(session, timeoutMs)
                                               : finalizeVideo(session, timeoutMs);
}

bool FfmpegPostprocessor::validateMedia(const QString &path, RecordingError *error,
                                        int timeoutMs) const
{
    const QFileInfo file(path);
    if (!file.isFile() || file.size() <= 0) {
        if (error) {
            *error = makeError(QStringLiteral("temporary_media_missing"),
                               QStringLiteral("Recorded temporary media is missing or empty"),
                               {{QStringLiteral("path"), path}});
        }
        return false;
    }

    const QString ffprobe = QStandardPaths::findExecutable(QStringLiteral("ffprobe"));
    if (ffprobe.isEmpty()) {
        if (error) {
            *error = makeError(QStringLiteral("dependency_missing"),
                               QStringLiteral("ffprobe is not installed or not available in PATH"),
                               {{QStringLiteral("dependency"), QStringLiteral("ffprobe")}});
        }
        return false;
    }

    QProcess process;
    process.setProgram(ffprobe);
    process.setArguments({
        QStringLiteral("-v"),
        QStringLiteral("error"),
        QStringLiteral("-show_entries"),
        QStringLiteral("format=duration:stream=index,codec_type"),
        QStringLiteral("-of"),
        QStringLiteral("json"),
        path,
    });
    process.start();
    if (!process.waitForStarted(3000) || !process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(1000);
        if (error) {
            *error = makeError(QStringLiteral("ffprobe_failed"),
                               QStringLiteral("Unable to validate recorded media"),
                               {{QStringLiteral("path"), path},
                                {QStringLiteral("reason"), process.errorString()}});
        }
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument document =
        QJsonDocument::fromJson(process.readAllStandardOutput(), &parseError);
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0
        || parseError.error != QJsonParseError::NoError || !document.isObject()
        || document.object().value(QStringLiteral("streams")).toArray().isEmpty()) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_recorded_media"),
                               QStringLiteral("ffprobe could not validate recorded media"),
                               {{QStringLiteral("path"), path},
                                {QStringLiteral("exitCode"), process.exitCode()},
                                {QStringLiteral("stderr"),
                                 QString::fromUtf8(process.readAllStandardError()).trimmed()}});
        }
        return false;
    }
    return true;
}

PostprocessResult FfmpegPostprocessor::finalizeVideo(const RecordingSession &session,
                                                     int timeoutMs) const
{
    const QString partial = partialPath(session.outputPath);
    RecordingError error;
    QFile::remove(partial);
    if (!runFfmpeg({
            QStringLiteral("-y"),
            QStringLiteral("-i"),
            session.temporaryPath,
            QStringLiteral("-map"),
            QStringLiteral("0"),
            QStringLiteral("-c"),
            QStringLiteral("copy"),
            QStringLiteral("-movflags"),
            QStringLiteral("+faststart"),
            partial,
        },
        &error, timeoutMs)) {
        return {false, {}, error};
    }
    if (!validateMedia(partial, &error) || !publishFile(partial, session.outputPath, &error))
        return {false, {}, error};
    QFile::remove(session.temporaryPath);
    return {true, session.outputPath, {}};
}

PostprocessResult FfmpegPostprocessor::finalizeGif(const RecordingSession &session,
                                                   int timeoutMs) const
{
    const QString partial = partialPath(session.outputPath);
    RecordingError error;
    QFile::remove(partial);
    if (!runFfmpeg({
            QStringLiteral("-y"),
            QStringLiteral("-i"),
            session.temporaryPath,
            QStringLiteral("-filter_complex"),
            QStringLiteral("fps=15,scale='min(960,iw)':-1:flags=lanczos,"
                           "split[s0][s1];[s0]palettegen=max_colors=256[p];"
                           "[s1][p]paletteuse=dither=sierra2_4a"),
            QStringLiteral("-loop"),
            QStringLiteral("0"),
            partial,
        },
        &error, timeoutMs)) {
        return {false, {}, error};
    }
    if (!validateMedia(partial, &error) || !publishFile(partial, session.outputPath, &error))
        return {false, {}, error};
    QFile::remove(session.temporaryPath);
    return {true, session.outputPath, {}};
}

bool FfmpegPostprocessor::runFfmpeg(const QStringList &arguments, RecordingError *error,
                                    int timeoutMs) const
{
    const QString ffmpeg = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
    if (ffmpeg.isEmpty()) {
        if (error) {
            *error = makeError(QStringLiteral("dependency_missing"),
                               QStringLiteral("ffmpeg is not installed or not available in PATH"),
                               {{QStringLiteral("dependency"), QStringLiteral("ffmpeg")}});
        }
        return false;
    }

    QProcess process;
    process.setProgram(ffmpeg);
    process.setArguments(arguments);
    process.start();
    if (!process.waitForStarted(3000) || !process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(1000);
        if (error) {
            *error = makeError(QStringLiteral("ffmpeg_timeout"),
                               QStringLiteral("FFmpeg post-processing timed out"),
                               {{QStringLiteral("reason"), process.errorString()}});
        }
        return false;
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        if (error) {
            const QString stderrText =
                QString::fromUtf8(process.readAllStandardError()).right(8192).trimmed();
            *error = makeError(QStringLiteral("ffmpeg_failed"),
                               QStringLiteral("FFmpeg post-processing failed"),
                               {{QStringLiteral("exitCode"), process.exitCode()},
                                {QStringLiteral("stderr"), stderrText}});
        }
        return false;
    }
    return true;
}

QString FfmpegPostprocessor::partialPath(const QString &outputPath)
{
    const QFileInfo info(outputPath);
    return info.dir().filePath(
        QStringLiteral("%1.clavis-partial.%2").arg(info.completeBaseName(), info.suffix()));
}

bool FfmpegPostprocessor::publishFile(const QString &partial, const QString &output,
                                      RecordingError *error)
{
    if (QFileInfo::exists(output)) {
        if (error) {
            *error = makeError(QStringLiteral("output_exists"),
                               QStringLiteral("Refusing to overwrite an existing output file"),
                               {{QStringLiteral("path"), output}});
        }
        return false;
    }
    if (!QFile::rename(partial, output)) {
        if (error) {
            *error = makeError(QStringLiteral("output_publish_failed"),
                               QStringLiteral("Unable to publish the finalized recording"),
                               {{QStringLiteral("temporaryPath"), partial},
                                {QStringLiteral("outputPath"), output}});
        }
        return false;
    }
    return true;
}

} // namespace Clavis::Recording
