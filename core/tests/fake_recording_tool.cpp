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

int fakeSlurp()
{
    if (qEnvironmentVariableIsSet("CLAVIS_TEST_SLURP_CANCEL"))
        return 1;

    // Real slurp consumes redirected stdin before connecting to Wayland. Keep
    // this behavior in the fake so an unclosed QProcess input pipe regresses
    // into a deterministic integration-test timeout.
    QFile input;
    if (!input.open(stdin, QIODevice::ReadOnly))
        return 2;
    input.readAll();

    QTextStream(stdout) << "640x480+12+34" << Qt::endl;
    return 0;
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

int fakeProbe()
{
    const QJsonObject object{
        {QStringLiteral("streams"),
         QJsonArray{QJsonObject{{QStringLiteral("index"), 0},
                                {QStringLiteral("codec_type"), QStringLiteral("video")}}}},
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
    QFile::remove(output);
    return QFile::copy(input, output) ? 0 : 3;
}
} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    const QString tool = QFileInfo(QString::fromLocal8Bit(argv[0])).fileName();
    const QStringList arguments = QCoreApplication::arguments().mid(1);
    if (tool == QStringLiteral("slurp"))
        return fakeSlurp();
    if (tool == QStringLiteral("gpu-screen-recorder"))
        return fakeRecorder(arguments);
    if (tool == QStringLiteral("ffprobe"))
        return fakeProbe();
    if (tool == QStringLiteral("ffmpeg"))
        return fakeFfmpeg(arguments);
    return 127;
}
