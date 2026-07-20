#include "dependency_probe.h"

#include "audio/audio_source_resolver.h"
#include "recording_state_store.h"

#include <QDir>
#include <QFileInfo>
#include <QProcessEnvironment>
#include <QStandardPaths>

namespace Clavis::Recording {

QJsonObject DependencyCheck::toJson() const
{
    return {
        {QStringLiteral("name"), name},
        {QStringLiteral("ok"), ok},
        {QStringLiteral("path"), path.isEmpty() ? QJsonValue(QJsonValue::Null)
                                                : QJsonValue(path)},
        {QStringLiteral("message"), message},
    };
}

QList<DependencyCheck> DependencyProbe::run(const QString &outputDirectory,
                                            bool includeAudio) const
{
    const QString output =
        outputDirectory.isEmpty() ? defaultOutputDirectory() : outputDirectory;
    RecordingStateStore store;
    QList<DependencyCheck> checks{
        executable(QStringLiteral("gpu-screen-recorder")),
        executable(QStringLiteral("ffmpeg")),
        executable(QStringLiteral("ffprobe")),
        niriSocket(),
        directory(QStringLiteral("output-directory"), output, true),
        directory(QStringLiteral("runtime-directory"), store.runtimeDirectory(), true),
    };
    if (includeAudio) {
        checks.append(executable(QStringLiteral("pactl")));
        checks.append(audioSource(AudioSourceType::Microphone));
        checks.append(audioSource(AudioSourceType::System));
        checks.append(directory(QStringLiteral("audio-output-directory"),
                                defaultAudioOutputDirectory(), true));
    }
    return checks;
}

bool DependencyProbe::allPassed(const QList<DependencyCheck> &checks)
{
    for (const DependencyCheck &check : checks) {
        if (!check.ok)
            return false;
    }
    return true;
}

QString DependencyProbe::defaultOutputDirectory(RecordingType type)
{
    QString movies = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
    if (movies.isEmpty())
        movies = QDir::home().filePath(QStringLiteral("Videos"));
    return QDir(movies).filePath(type == RecordingType::Gif
                                    ? QStringLiteral("Clavis/GIF")
                                    : QStringLiteral("Clavis"));
}

QString DependencyProbe::defaultAudioOutputDirectory()
{
    QString music = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
    if (music.isEmpty())
        music = QDir::home().filePath(QStringLiteral("Music"));
    return QDir(music).filePath(QStringLiteral("Clavis/Audio"));
}

DependencyCheck DependencyProbe::executable(const QString &name)
{
    const QString path = QStandardPaths::findExecutable(name);
    return {
        name,
        !path.isEmpty(),
        path,
        path.isEmpty() ? QStringLiteral("Not found in PATH") : QStringLiteral("Available"),
    };
}

DependencyCheck DependencyProbe::audioSource(AudioSourceType type)
{
    const AudioSourceResolution resolution = AudioSourceResolver().resolve(type);
    const QString name = type == AudioSourceType::System
        ? QStringLiteral("system-audio-source")
        : QStringLiteral("microphone-source");
    return {
        name,
        resolution.ok,
        resolution.ok ? resolution.source.name : QString(),
        resolution.ok ? resolution.source.description
                      : resolution.error.message,
    };
}

DependencyCheck DependencyProbe::directory(const QString &name, const QString &path,
                                           bool createIfMissing)
{
    if (path.isEmpty())
        return {name, false, {}, QStringLiteral("Path is unavailable")};

    if (createIfMissing)
        QDir().mkpath(path);
    const QFileInfo info(path);
    const bool ok = info.isDir() && info.isWritable();
    return {name, ok, path,
            ok ? QStringLiteral("Writable") : QStringLiteral("Missing or not writable")};
}

DependencyCheck DependencyProbe::niriSocket()
{
    const QString path =
        QProcessEnvironment::systemEnvironment().value(QStringLiteral("NIRI_SOCKET"));
    const QFileInfo info(path);
    const bool ok = !path.isEmpty() && info.exists();
    return {
        QStringLiteral("niri-socket"),
        ok,
        path,
        ok ? QStringLiteral("Available")
           : QStringLiteral("NIRI_SOCKET is unset or the socket does not exist"),
    };
}

} // namespace Clavis::Recording
