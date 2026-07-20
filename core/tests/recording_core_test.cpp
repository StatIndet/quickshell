#include "niri_cast_parser.h"
#include "recording/audio/audio_recording_types.h"
#include "recording/audio/audio_source_resolver.h"
#include "recording/gsr_backend.h"
#include "recording/recording_types.h"

#include <QJsonArray>
#include <QTest>

using namespace Clavis::Recording;

class RecordingCoreTest : public QObject {
    Q_OBJECT

private slots:
    void normalizesRegionGeometry();
    void rejectsInvalidRegionGeometry();
    void roundTripsRecordingState();
    void buildsShellFreeGsrArguments();
    void resolvesMicrophoneAndSystemMonitor();
    void parsesNiriCastSchema();
};

void RecordingCoreTest::normalizesRegionGeometry()
{
    QString geometry;
    QVERIFY(normalizeRegionGeometry(QStringLiteral("1920x1080+0+0"), &geometry));
    QCOMPARE(geometry, QStringLiteral("1920x1080+0+0"));
    QVERIFY(normalizeRegionGeometry(QStringLiteral(" 640x480+-20+32\n"), &geometry));
    QCOMPARE(geometry, QStringLiteral("640x480+-20+32"));
}

void RecordingCoreTest::rejectsInvalidRegionGeometry()
{
    QVERIFY(!normalizeRegionGeometry(QStringLiteral("0x1080+0+0")));
    QVERIFY(!normalizeRegionGeometry(QStringLiteral("1920,1080 0x0")));
    QVERIFY(!normalizeRegionGeometry(QStringLiteral("anything")));
}

void RecordingCoreTest::roundTripsRecordingState()
{
    RecordingSession source;
    source.sessionId = QStringLiteral("test-session");
    source.state = RecordingState::Recording;
    source.pid = 4242;
    source.processStartTicks = 123456;
    source.startedAtMs = 1784350284000;
    source.type = RecordingType::Gif;
    source.geometry = QStringLiteral("800x600+12+34");
    source.temporaryPath = QStringLiteral("/tmp/test.mkv");
    source.outputPath = QStringLiteral("/tmp/test.gif");

    RecordingSession parsed;
    RecordingError error;
    QVERIFY(RecordingSession::fromJson(source.toJson(), &parsed, &error));
    QVERIFY(error.isNull());
    QCOMPARE(parsed.sessionId, source.sessionId);
    QCOMPARE(parsed.state, RecordingState::Recording);
    QCOMPARE(parsed.pid, source.pid);
    QCOMPARE(parsed.processStartTicks, source.processStartTicks);
    QCOMPARE(parsed.type, RecordingType::Gif);
    QCOMPARE(parsed.geometry, source.geometry);

    OperationResult result;
    result.ok = true;
    result.session = parsed;
    result.session.error =
        makeError(QStringLiteral("session_warning"), QStringLiteral("Preserved"));
    QCOMPARE(result.toJson(QStringLiteral("record.status"))
                 .value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("session_warning"));
}

void RecordingCoreTest::buildsShellFreeGsrArguments()
{
    RecordingSession session;
    session.geometry = QStringLiteral("1280x720+0+0");
    session.temporaryPath = QStringLiteral("/tmp/clavis-test.mkv");
    session.audio = QStringLiteral("system");
    session.fps = 60;
    const QStringList arguments = GsrBackend().buildArguments(session);
    QCOMPARE(arguments.at(0), QStringLiteral("-w"));
    QVERIFY(arguments.contains(QStringLiteral("region")));
    QVERIFY(arguments.contains(session.geometry));
    QVERIFY(arguments.contains(QStringLiteral("default_output")));
    QCOMPARE(arguments.last(), session.temporaryPath);
    QVERIFY(!arguments.contains(QStringLiteral("sh")));
    QVERIFY(!arguments.contains(QStringLiteral("-c")));
}

void RecordingCoreTest::resolvesMicrophoneAndSystemMonitor()
{
    const QJsonObject serverInfo{
        {QStringLiteral("default_source_name"), QStringLiteral("test.mic")},
        {QStringLiteral("default_sink_name"), QStringLiteral("test.sink")},
    };
    const QJsonArray sources{
        QJsonObject{
            {QStringLiteral("name"), QStringLiteral("test.mic")},
            {QStringLiteral("description"), QStringLiteral("Microphone")},
            {QStringLiteral("state"), QStringLiteral("RUNNING")},
            {QStringLiteral("properties"),
             QJsonObject{{QStringLiteral("node.name"),
                          QStringLiteral("test.mic.node")}}},
        },
        QJsonObject{
            {QStringLiteral("name"), QStringLiteral("test.sink.monitor")},
            {QStringLiteral("description"), QStringLiteral("Monitor")},
            {QStringLiteral("state"), QStringLiteral("IDLE")},
            {QStringLiteral("properties"),
             QJsonObject{{QStringLiteral("node.name"),
                          QStringLiteral("test.monitor.node")},
                         {QStringLiteral("device.class"),
                          QStringLiteral("monitor")}}},
        },
    };
    const QJsonArray sinks{
        QJsonObject{
            {QStringLiteral("name"), QStringLiteral("test.sink")},
            {QStringLiteral("description"), QStringLiteral("Output")},
            {QStringLiteral("monitor_source"),
             QStringLiteral("test.sink.monitor")},
            {QStringLiteral("properties"),
             QJsonObject{{QStringLiteral("node.name"),
                          QStringLiteral("test.sink.node")}}},
        },
    };

    const AudioSourceResolution microphone =
        AudioSourceResolver::resolveFromJson(
            AudioSourceType::Microphone, serverInfo, sources, sinks);
    QVERIFY(microphone.ok);
    QCOMPARE(microphone.source.name, QStringLiteral("test.mic"));
    QCOMPARE(microphone.source.nodeName, QStringLiteral("test.mic.node"));
    QVERIFY(!microphone.source.captureSink);

    const AudioSourceResolution system =
        AudioSourceResolver::resolveFromJson(
            AudioSourceType::System, serverInfo, sources, sinks);
    QVERIFY(system.ok);
    QCOMPARE(system.source.name, QStringLiteral("test.sink.monitor"));
    QCOMPARE(system.source.nodeName, QStringLiteral("test.sink.node"));
    QVERIFY(system.source.captureSink);
}

void RecordingCoreTest::parsesNiriCastSchema()
{
    const QJsonObject castJson{
        {QStringLiteral("stream_id"), 7},
        {QStringLiteral("session_id"), QStringLiteral("session")},
        {QStringLiteral("kind"), QStringLiteral("PipeWire")},
        {QStringLiteral("target"),
         QJsonObject{{QStringLiteral("Output"),
                      QJsonObject{{QStringLiteral("name"), QStringLiteral("DP-1")}}}}},
        {QStringLiteral("is_active"), true},
        {QStringLiteral("is_dynamic_target"), false},
        {QStringLiteral("pid"), 1234},
        {QStringLiteral("pw_node_id"), 88},
    };
    const NiriCast cast = NiriCastParser::parse(castJson);
    QCOMPARE(cast.streamId, quint64(7));
    QCOMPARE(cast.targetType, QStringLiteral("output"));
    QCOMPARE(cast.targetName, QStringLiteral("DP-1"));
    QVERIFY(cast.isActive);
    QCOMPARE(NiriCastParser::activeCount({cast}), 1);
}

QTEST_MAIN(RecordingCoreTest)
#include "recording_core_test.moc"
