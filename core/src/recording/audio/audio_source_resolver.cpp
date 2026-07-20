#include "audio_source_resolver.h"

#include <QJsonDocument>
#include <QJsonValue>
#include <QProcess>
#include <QStandardPaths>

namespace Clavis::Recording {
namespace {

QString propertyValue(const QJsonObject &object, const QString &name)
{
    return object.value(QStringLiteral("properties")).toObject().value(name).toString();
}

bool isMonitor(const QJsonObject &source)
{
    return propertyValue(source, QStringLiteral("device.class"))
               == QStringLiteral("monitor")
        || source.value(QStringLiteral("name")).toString().endsWith(
            QStringLiteral(".monitor"));
}

bool activePortUnavailable(const QJsonObject &source)
{
    const QString activePort = source.value(QStringLiteral("active_port")).toString();
    if (activePort.isEmpty())
        return false;
    const QJsonArray ports = source.value(QStringLiteral("ports")).toArray();
    for (const QJsonValue &value : ports) {
        const QJsonObject port = value.toObject();
        if (port.value(QStringLiteral("name")).toString() == activePort) {
            return port.value(QStringLiteral("availability")).toString()
                == QStringLiteral("not available");
        }
    }
    return false;
}

bool sourceUsable(const QJsonObject &source)
{
    return source.value(QStringLiteral("state")).toString() != QStringLiteral("UNAVAILABLE")
        && !activePortUnavailable(source);
}

QJsonObject findByName(const QJsonArray &values, const QString &name)
{
    for (const QJsonValue &value : values) {
        const QJsonObject object = value.toObject();
        if (object.value(QStringLiteral("name")).toString() == name)
            return object;
    }
    return {};
}

AudioSourceInfo sourceInfo(AudioSourceType type, const QJsonObject &source,
                           const QString &nodeName, bool captureSink)
{
    AudioSourceInfo info;
    info.type = type;
    info.name = source.value(QStringLiteral("name")).toString();
    info.nodeName = nodeName;
    info.description = source.value(QStringLiteral("description")).toString();
    info.captureSink = captureSink;
    return info;
}

} // namespace

AudioSourceResolution AudioSourceResolver::resolve(AudioSourceType type) const
{
    QJsonDocument infoDocument;
    QJsonDocument sourcesDocument;
    QJsonDocument sinksDocument;
    RecordingError error;
    if (!runPactl({QStringLiteral("-f"), QStringLiteral("json"), QStringLiteral("info")},
                  &infoDocument, &error)
        || !runPactl({QStringLiteral("-f"), QStringLiteral("json"),
                      QStringLiteral("list"), QStringLiteral("sources")},
                     &sourcesDocument, &error)
        || !runPactl({QStringLiteral("-f"), QStringLiteral("json"),
                      QStringLiteral("list"), QStringLiteral("sinks")},
                     &sinksDocument, &error)) {
        return {false, {}, error};
    }

    return resolveFromJson(type, infoDocument.object(), sourcesDocument.array(),
                           sinksDocument.array());
}

AudioSourceResolution AudioSourceResolver::resolveFromJson(
    AudioSourceType type, const QJsonObject &serverInfo, const QJsonArray &sources,
    const QJsonArray &sinks)
{
    if (type == AudioSourceType::Microphone) {
        const QString defaultName =
            serverInfo.value(QStringLiteral("default_source_name")).toString();
        QJsonObject source = findByName(sources, defaultName);
        if (source.isEmpty() || isMonitor(source) || !sourceUsable(source)) {
            source = {};
            for (const QJsonValue &value : sources) {
                const QJsonObject candidate = value.toObject();
                if (!isMonitor(candidate) && sourceUsable(candidate)) {
                    source = candidate;
                    break;
                }
            }
        }

        if (source.isEmpty()) {
            return {
                false,
                {},
                makeError(QStringLiteral("microphone_unavailable"),
                          QStringLiteral("No usable microphone source is available")),
            };
        }

        const QString nodeName =
            propertyValue(source, QStringLiteral("node.name")).isEmpty()
            ? source.value(QStringLiteral("name")).toString()
            : propertyValue(source, QStringLiteral("node.name"));
        const AudioSourceInfo info =
            sourceInfo(type, source, nodeName, false);
        if (!info.isValid()) {
            return {
                false,
                {},
                makeError(QStringLiteral("microphone_unavailable"),
                          QStringLiteral("The default microphone has no usable node name")),
            };
        }
        return {true, info, {}};
    }

    const QString defaultSinkName =
        serverInfo.value(QStringLiteral("default_sink_name")).toString();
    const QJsonObject sink = findByName(sinks, defaultSinkName);
    const QString monitorName =
        sink.value(QStringLiteral("monitor_source")).toString();
    const QJsonObject monitor = findByName(sources, monitorName);
    if (sink.isEmpty() || monitor.isEmpty() || !isMonitor(monitor)
        || !sourceUsable(monitor)) {
        return {
            false,
            {},
            makeError(QStringLiteral("system_monitor_unavailable"),
                      QStringLiteral("The default output has no usable monitor source"),
                      {{QStringLiteral("defaultSink"), defaultSinkName},
                       {QStringLiteral("monitorSource"), monitorName}}),
        };
    }

    const QString sinkNodeName =
        propertyValue(sink, QStringLiteral("node.name")).isEmpty()
        ? sink.value(QStringLiteral("name")).toString()
        : propertyValue(sink, QStringLiteral("node.name"));
    AudioSourceInfo info = sourceInfo(type, monitor, sinkNodeName, true);
    if (info.description.isEmpty())
        info.description = sink.value(QStringLiteral("description")).toString();
    if (!info.isValid()) {
        return {
            false,
            {},
            makeError(QStringLiteral("system_monitor_unavailable"),
                      QStringLiteral("The default output monitor has no usable node name")),
        };
    }
    return {true, info, {}};
}

bool AudioSourceResolver::runPactl(const QStringList &arguments,
                                   QJsonDocument *document,
                                   RecordingError *error)
{
    const QString program = QStandardPaths::findExecutable(QStringLiteral("pactl"));
    if (program.isEmpty()) {
        if (error) {
            *error = makeError(QStringLiteral("dependency_missing"),
                               QStringLiteral("pactl is not installed or not available in PATH"),
                               {{QStringLiteral("dependency"), QStringLiteral("pactl")}});
        }
        return false;
    }

    QProcess process;
    process.start(program, arguments);
    if (!process.waitForStarted(3000) || !process.waitForFinished(5000)) {
        process.kill();
        process.waitForFinished(1000);
        if (error) {
            *error = makeError(QStringLiteral("audio_server_unavailable"),
                               QStringLiteral("Unable to query the PulseAudio server"),
                               {{QStringLiteral("reason"), process.errorString()}});
        }
        return false;
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        if (error) {
            *error = makeError(
                QStringLiteral("audio_server_unavailable"),
                QStringLiteral("pactl could not query the PulseAudio server"),
                {{QStringLiteral("stderr"),
                  QString::fromLocal8Bit(process.readAllStandardError()).trimmed()}});
        }
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument parsed =
        QJsonDocument::fromJson(process.readAllStandardOutput(), &parseError);
    if (parseError.error != QJsonParseError::NoError
        || (!parsed.isObject() && !parsed.isArray())) {
        if (error) {
            *error = makeError(QStringLiteral("invalid_pactl_json"),
                               QStringLiteral("pactl returned invalid JSON"),
                               {{QStringLiteral("reason"), parseError.errorString()}});
        }
        return false;
    }
    if (document)
        *document = parsed;
    return true;
}

} // namespace Clavis::Recording
