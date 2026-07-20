#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QTextStream>
#include <QThread>

#include <atomic>
#include <csignal>

namespace {
std::atomic_bool stopRequested = false;

void handleSignal(int)
{
    stopRequested.store(true);
}

int fakeRecorder(const QStringList &arguments)
{
    if (qEnvironmentVariableIsSet("CLAVIS_TEST_GSR_FAIL"))
        return 42;

    const int outputIndex = arguments.indexOf(QStringLiteral("-o"));
    if (outputIndex < 0 || outputIndex + 1 >= arguments.size())
        return 2;

    QFile output(arguments.at(outputIndex + 1));
    if (!output.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return 3;
    output.write("fake-matroska-header\n");
    output.flush();

    std::signal(SIGINT, handleSignal);
    while (!stopRequested.load())
        QThread::msleep(20);

    output.write("fake-matroska-footer\n");
    output.close();
    return 0;
}

int fakeProbe(const QStringList &arguments)
{
    const bool audio = !arguments.isEmpty()
        && arguments.last().endsWith(QStringLiteral(".m4a"));
    const QJsonObject object{
        {QStringLiteral("streams"),
         QJsonArray{QJsonObject{{QStringLiteral("index"), 0},
                                {QStringLiteral("codec_type"),
                                 audio ? QStringLiteral("audio")
                                       : QStringLiteral("video")}}}},
        {QStringLiteral("format"),
         QJsonObject{{QStringLiteral("duration"), QStringLiteral("1.0")}}},
    };
    QTextStream(stdout) << QJsonDocument(object).toJson(QJsonDocument::Compact) << Qt::endl;
    return 0;
}

int fakeFfmpeg(const QStringList &arguments)
{
    if (qEnvironmentVariableIsSet("CLAVIS_TEST_FFMPEG_FAIL"))
        return 17;

    const int inputIndex = arguments.indexOf(QStringLiteral("-i"));
    if (inputIndex < 0 || inputIndex + 1 >= arguments.size() || arguments.isEmpty())
        return 2;
    const QString input = arguments.at(inputIndex + 1);
    const QString output = arguments.last();
    if (arguments.contains(QStringLiteral("pulse"))) {
        if (qEnvironmentVariableIsSet("CLAVIS_TEST_AUDIO_FFMPEG_FAIL"))
            return 18;

        QFile audioOutput(output);
        if (!audioOutput.open(QIODevice::WriteOnly | QIODevice::Truncate))
            return 3;
        audioOutput.write("fake-m4a-header\n");
        audioOutput.flush();
        std::signal(SIGINT, handleSignal);
        std::signal(SIGTERM, handleSignal);
        while (!stopRequested.load())
            QThread::msleep(20);
        audioOutput.write("fake-m4a-footer\n");
        audioOutput.close();
        return 0;
    }

    QFile::remove(output);
    return QFile::copy(input, output) ? 0 : 3;
}

int fakePactl(const QStringList &arguments)
{
    const QJsonObject microphone{
        {QStringLiteral("name"), QStringLiteral("clavis.test.mic")},
        {QStringLiteral("description"), QStringLiteral("Clavis Test Microphone")},
        {QStringLiteral("state"), QStringLiteral("RUNNING")},
        {QStringLiteral("properties"),
         QJsonObject{{QStringLiteral("node.name"),
                      QStringLiteral("clavis.test.mic")}}},
    };
    const QJsonObject monitor{
        {QStringLiteral("name"), QStringLiteral("clavis.test.sink.monitor")},
        {QStringLiteral("description"), QStringLiteral("Clavis Test Monitor")},
        {QStringLiteral("state"), QStringLiteral("RUNNING")},
        {QStringLiteral("properties"),
         QJsonObject{{QStringLiteral("node.name"),
                      QStringLiteral("clavis.test.sink.monitor")},
                     {QStringLiteral("device.class"),
                      QStringLiteral("monitor")}}},
    };
    const QJsonObject sink{
        {QStringLiteral("name"), QStringLiteral("clavis.test.sink")},
        {QStringLiteral("description"), QStringLiteral("Clavis Test Output")},
        {QStringLiteral("monitor_source"),
         QStringLiteral("clavis.test.sink.monitor")},
        {QStringLiteral("properties"),
         QJsonObject{{QStringLiteral("node.name"),
                      QStringLiteral("clavis.test.sink")}}},
    };

    QJsonDocument document;
    if (arguments.contains(QStringLiteral("info"))) {
        document = QJsonDocument(QJsonObject{
            {QStringLiteral("default_source_name"),
             QStringLiteral("clavis.test.mic")},
            {QStringLiteral("default_sink_name"),
             QStringLiteral("clavis.test.sink")},
        });
    } else if (arguments.contains(QStringLiteral("sources"))) {
        QJsonArray sources;
        if (!qEnvironmentVariableIsSet("CLAVIS_TEST_NO_MIC"))
            sources.append(microphone);
        if (!qEnvironmentVariableIsSet("CLAVIS_TEST_NO_MONITOR"))
            sources.append(monitor);
        document = QJsonDocument(sources);
    } else if (arguments.contains(QStringLiteral("sinks"))) {
        QJsonArray sinks;
        if (!qEnvironmentVariableIsSet("CLAVIS_TEST_NO_MONITOR"))
            sinks.append(sink);
        document = QJsonDocument(sinks);
    } else {
        return 2;
    }

    QTextStream(stdout) << document.toJson(QJsonDocument::Compact) << Qt::endl;
    return 0;
}
} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    const QString tool = QFileInfo(QString::fromLocal8Bit(argv[0])).fileName();
    const QStringList arguments = QCoreApplication::arguments().mid(1);
    if (tool == QStringLiteral("gpu-screen-recorder"))
        return fakeRecorder(arguments);
    if (tool == QStringLiteral("ffprobe"))
        return fakeProbe(arguments);
    if (tool == QStringLiteral("ffmpeg"))
        return fakeFfmpeg(arguments);
    if (tool == QStringLiteral("pactl"))
        return fakePactl(arguments);
    return 127;
}
