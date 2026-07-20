#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QTemporaryDir>
#include <QTest>

#include <csignal>

class KeyIntegrationTest : public QObject {
    Q_OBJECT

private slots:
    void init();
    void cleanup();
    void rejectsMissingRegionGeometry();
    void reportsMissingDependencies();
    void reportsRecorderStartFailure();
    void recordsAndFinalizesVideo();
    void recordsAndConvertsGif();
    void screenRecordingDoesNotRequireAudioSources();
    void retriesFailedFinalization();
    void recordsMicrophoneAudio();
    void recordsSystemAudio();
    void rejectsUnavailableAudioSource();
    void rejectsCrossCaptureConflicts();

private:
    struct KeyResult {
        int exitCode = -1;
        QJsonObject json;
        QByteArray stderrText;
    };

    KeyResult runKey(const QStringList &arguments, int timeoutMs = 30000);
    void exerciseLifecycle(const QString &type, const QString &extension);
    void exerciseAudioLifecycle(const QString &source, bool captureSink);

    std::unique_ptr<QTemporaryDir> m_temporary;
    QProcessEnvironment m_environment;
    qint64 m_recorderPid = 0;
};

void KeyIntegrationTest::init()
{
    m_temporary = std::make_unique<QTemporaryDir>();
    QVERIFY(m_temporary->isValid());
    QVERIFY(QDir().mkpath(m_temporary->filePath(QStringLiteral("runtime"))));
    QVERIFY(QDir().mkpath(m_temporary->filePath(QStringLiteral("output"))));

    m_environment = QProcessEnvironment::systemEnvironment();
    m_environment.insert(
        QStringLiteral("PATH"),
        QStringLiteral(KEY_FAKE_BIN) + QDir::listSeparator()
            + m_environment.value(QStringLiteral("PATH")));
    m_environment.insert(QStringLiteral("XDG_RUNTIME_DIR"),
                         m_temporary->filePath(QStringLiteral("runtime")));
    m_environment.insert(QStringLiteral("HOME"), m_temporary->path());
}

void KeyIntegrationTest::cleanup()
{
    if (m_recorderPid > 0)
        ::kill(static_cast<pid_t>(m_recorderPid), SIGINT);
    m_recorderPid = 0;
    m_temporary.reset();
}

void KeyIntegrationTest::rejectsMissingRegionGeometry()
{
    const KeyResult start = runKey({
        QStringLiteral("record"),
        QStringLiteral("start"),
        QStringLiteral("--type"),
        QStringLiteral("video"),
        QStringLiteral("--target"),
        QStringLiteral("region"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(start.exitCode, 2);
    QCOMPARE(start.json.value(QStringLiteral("cancelled")).toBool(), false);
    QCOMPARE(start.json.value(QStringLiteral("state")).toString(), QStringLiteral("idle"));
    QCOMPARE(start.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("missing_geometry"));
}

void KeyIntegrationTest::recordsAndFinalizesVideo()
{
    exerciseLifecycle(QStringLiteral("video"), QStringLiteral("mp4"));
}

void KeyIntegrationTest::recordsAndConvertsGif()
{
    exerciseLifecycle(QStringLiteral("gif"), QStringLiteral("gif"));
}

void KeyIntegrationTest::screenRecordingDoesNotRequireAudioSources()
{
    m_environment.insert(QStringLiteral("CLAVIS_TEST_NO_MIC"), QStringLiteral("1"));
    m_environment.insert(QStringLiteral("CLAVIS_TEST_NO_MONITOR"), QStringLiteral("1"));
    exerciseLifecycle(QStringLiteral("video"), QStringLiteral("mp4"));
}

void KeyIntegrationTest::recordsMicrophoneAudio()
{
    exerciseAudioLifecycle(QStringLiteral("mic"), false);
}

void KeyIntegrationTest::recordsSystemAudio()
{
    exerciseAudioLifecycle(QStringLiteral("system"), true);
}

void KeyIntegrationTest::rejectsUnavailableAudioSource()
{
    m_environment.insert(QStringLiteral("CLAVIS_TEST_NO_MIC"), QStringLiteral("1"));
    const KeyResult start = runKey({
        QStringLiteral("audio"),
        QStringLiteral("start"),
        QStringLiteral("--source"),
        QStringLiteral("mic"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(start.exitCode, 3);
    QCOMPARE(start.json.value(QStringLiteral("state")).toString(),
             QStringLiteral("idle"));
    QCOMPARE(start.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("microphone_unavailable"));
}

void KeyIntegrationTest::rejectsCrossCaptureConflicts()
{
    const KeyResult audioStart = runKey({
        QStringLiteral("audio"),
        QStringLiteral("start"),
        QStringLiteral("--source"),
        QStringLiteral("mic"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(audioStart.exitCode, 0);
    m_recorderPid = audioStart.json.value(QStringLiteral("pid")).toInteger();
    QVERIFY(m_recorderPid > 0);

    const KeyResult blockedScreen = runKey({
        QStringLiteral("record"),
        QStringLiteral("start"),
        QStringLiteral("--type"),
        QStringLiteral("video"),
        QStringLiteral("--geometry"),
        QStringLiteral("640x480+12+34"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(blockedScreen.exitCode, 4);
    QCOMPARE(blockedScreen.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("capture_session_conflict"));
    QCOMPARE(runKey({QStringLiteral("audio"), QStringLiteral("stop"),
                     QStringLiteral("--json")}).exitCode, 0);
    m_recorderPid = 0;

    const KeyResult screenStart = runKey({
        QStringLiteral("record"),
        QStringLiteral("start"),
        QStringLiteral("--type"),
        QStringLiteral("video"),
        QStringLiteral("--geometry"),
        QStringLiteral("640x480+12+34"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(screenStart.exitCode, 0);
    m_recorderPid = screenStart.json.value(QStringLiteral("pid")).toInteger();
    QVERIFY(m_recorderPid > 0);

    const KeyResult blockedAudio = runKey({
        QStringLiteral("audio"),
        QStringLiteral("start"),
        QStringLiteral("--source"),
        QStringLiteral("system"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(blockedAudio.exitCode, 4);
    QCOMPARE(blockedAudio.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("capture_session_conflict"));
    QCOMPARE(runKey({QStringLiteral("record"), QStringLiteral("stop"),
                     QStringLiteral("--json")}).exitCode, 0);
    m_recorderPid = 0;
}

void KeyIntegrationTest::reportsMissingDependencies()
{
    const QString emptyPath = m_temporary->filePath(QStringLiteral("empty-path"));
    QVERIFY(QDir().mkpath(emptyPath));
    m_environment.insert(QStringLiteral("PATH"), emptyPath);
    const KeyResult start = runKey({
        QStringLiteral("record"),
        QStringLiteral("start"),
        QStringLiteral("--geometry"),
        QStringLiteral("640x480+12+34"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(start.exitCode, 3);
    QCOMPARE(start.json.value(QStringLiteral("ok")).toBool(), false);
    QCOMPARE(start.json.value(QStringLiteral("state")).toString(), QStringLiteral("idle"));
    QCOMPARE(start.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("dependency_check_failed"));
}

void KeyIntegrationTest::reportsRecorderStartFailure()
{
    m_environment.insert(QStringLiteral("CLAVIS_TEST_GSR_FAIL"), QStringLiteral("1"));
    const KeyResult start = runKey({
        QStringLiteral("record"),
        QStringLiteral("start"),
        QStringLiteral("--geometry"),
        QStringLiteral("640x480+12+34"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(start.exitCode, 6);
    QCOMPARE(start.json.value(QStringLiteral("state")).toString(), QStringLiteral("idle"));
    QCOMPARE(start.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("recorder_start_failed"));
}

void KeyIntegrationTest::retriesFailedFinalization()
{
    const KeyResult start = runKey({
        QStringLiteral("record"),
        QStringLiteral("start"),
        QStringLiteral("--type"),
        QStringLiteral("video"),
        QStringLiteral("--geometry"),
        QStringLiteral("640x480+12+34"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(start.exitCode, 0);
    m_recorderPid = start.json.value(QStringLiteral("pid")).toInteger();
    QVERIFY(m_recorderPid > 0);

    m_environment.insert(QStringLiteral("CLAVIS_TEST_FFMPEG_FAIL"), QStringLiteral("1"));
    const KeyResult failedStop =
        runKey({QStringLiteral("record"), QStringLiteral("stop"), QStringLiteral("--json")});
    m_recorderPid = 0;
    QCOMPARE(failedStop.exitCode, 8);
    QCOMPARE(failedStop.json.value(QStringLiteral("state")).toString(),
             QStringLiteral("finalizing"));
    QCOMPARE(failedStop.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("ffmpeg_failed"));

    m_environment.remove(QStringLiteral("CLAVIS_TEST_FFMPEG_FAIL"));
    const KeyResult retry =
        runKey({QStringLiteral("record"), QStringLiteral("stop"), QStringLiteral("--json")});
    QCOMPARE(retry.exitCode, 0);
    QCOMPARE(retry.json.value(QStringLiteral("state")).toString(),
             QStringLiteral("completed"));
    QVERIFY(QFileInfo(retry.json.value(QStringLiteral("outputPath")).toString()).isFile());
}

KeyIntegrationTest::KeyResult KeyIntegrationTest::runKey(const QStringList &arguments,
                                                         int timeoutMs)
{
    QProcess process;
    process.setProcessEnvironment(m_environment);
    process.setProgram(QStringLiteral(KEY_EXECUTABLE));
    process.setArguments(arguments);
    process.start();
    if (!process.waitForStarted(5000) || !process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(1000);
        return {-999, {}, process.readAllStandardError()};
    }

    QJsonParseError parseError;
    const QJsonDocument document =
        QJsonDocument::fromJson(process.readAllStandardOutput().trimmed(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return {process.exitCode(), {}, process.readAllStandardError()};
    return {process.exitCode(), document.object(), process.readAllStandardError()};
}

void KeyIntegrationTest::exerciseLifecycle(const QString &type, const QString &extension)
{
    const KeyResult start = runKey({
        QStringLiteral("record"),
        QStringLiteral("start"),
        QStringLiteral("--type"),
        type,
        QStringLiteral("--target"),
        QStringLiteral("region"),
        QStringLiteral("--geometry"),
        QStringLiteral("640x480+12+34"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(start.exitCode, 0);
    QCOMPARE(start.json.value(QStringLiteral("ok")).toBool(), true);
    QCOMPARE(start.json.value(QStringLiteral("state")).toString(), QStringLiteral("recording"));
    QCOMPARE(start.json.value(QStringLiteral("type")).toString(), type);
    QCOMPARE(start.json.value(QStringLiteral("target")).toObject()
                 .value(QStringLiteral("geometry")).toString(),
             QStringLiteral("640x480+12+34"));
    m_recorderPid = start.json.value(QStringLiteral("pid")).toInteger();
    QVERIFY(m_recorderPid > 0);

    const KeyResult status =
        runKey({QStringLiteral("record"), QStringLiteral("status"), QStringLiteral("--json")});
    QCOMPARE(status.exitCode, 0);
    QCOMPARE(status.json.value(QStringLiteral("state")).toString(), QStringLiteral("recording"));
    QCOMPARE(status.json.value(QStringLiteral("pid")).toInteger(), m_recorderPid);

    const KeyResult duplicate = runKey({
        QStringLiteral("record"),
        QStringLiteral("start"),
        QStringLiteral("--type"),
        type,
        QStringLiteral("--geometry"),
        QStringLiteral("640x480+12+34"),
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(duplicate.exitCode, 4);
    QCOMPARE(duplicate.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("recording_already_active"));

    const KeyResult stop =
        runKey({QStringLiteral("record"), QStringLiteral("stop"), QStringLiteral("--json")},
               30000);
    m_recorderPid = 0;
    QCOMPARE(stop.exitCode, 0);
    QCOMPARE(stop.json.value(QStringLiteral("ok")).toBool(), true);
    QCOMPARE(stop.json.value(QStringLiteral("state")).toString(), QStringLiteral("completed"));
    const QString outputPath = stop.json.value(QStringLiteral("outputPath")).toString();
    QVERIFY(outputPath.endsWith(QLatin1Char('.') + extension));
    QVERIFY(QFileInfo(outputPath).isFile());
    QVERIFY(QFileInfo(outputPath).size() > 0);

    const KeyResult idle =
        runKey({QStringLiteral("record"), QStringLiteral("status"), QStringLiteral("--json")});
    QCOMPARE(idle.exitCode, 0);
    QCOMPARE(idle.json.value(QStringLiteral("state")).toString(), QStringLiteral("idle"));
    QCOMPARE(idle.json.value(QStringLiteral("outputPath")).toString(), outputPath);
}

void KeyIntegrationTest::exerciseAudioLifecycle(const QString &source,
                                                bool captureSink)
{
    const KeyResult start = runKey({
        QStringLiteral("audio"),
        QStringLiteral("start"),
        QStringLiteral("--source"),
        source,
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(start.exitCode, 0);
    QCOMPARE(start.json.value(QStringLiteral("ok")).toBool(), true);
    QCOMPARE(start.json.value(QStringLiteral("state")).toString(),
             QStringLiteral("recording"));
    QCOMPARE(start.json.value(QStringLiteral("source")).toObject()
                 .value(QStringLiteral("type")).toString(), source);
    QCOMPARE(start.json.value(QStringLiteral("source")).toObject()
                 .value(QStringLiteral("captureSink")).toBool(), captureSink);
    QVERIFY(start.json.value(QStringLiteral("startedAtMs")).toInteger() > 0);
    m_recorderPid = start.json.value(QStringLiteral("pid")).toInteger();
    QVERIFY(m_recorderPid > 0);

    const KeyResult status = runKey({
        QStringLiteral("audio"), QStringLiteral("status"), QStringLiteral("--json")
    });
    QCOMPARE(status.exitCode, 0);
    QCOMPARE(status.json.value(QStringLiteral("state")).toString(),
             QStringLiteral("recording"));
    QCOMPARE(status.json.value(QStringLiteral("pid")).toInteger(), m_recorderPid);

    const KeyResult duplicate = runKey({
        QStringLiteral("audio"),
        QStringLiteral("start"),
        QStringLiteral("--source"),
        source,
        QStringLiteral("--output"),
        m_temporary->filePath(QStringLiteral("output")),
        QStringLiteral("--json"),
    });
    QCOMPARE(duplicate.exitCode, 4);
    QCOMPARE(duplicate.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("audio_recording_already_active"));

    const KeyResult stop = runKey({
        QStringLiteral("audio"), QStringLiteral("stop"), QStringLiteral("--json")
    });
    m_recorderPid = 0;
    QCOMPARE(stop.exitCode, 0);
    QCOMPARE(stop.json.value(QStringLiteral("ok")).toBool(), true);
    QCOMPARE(stop.json.value(QStringLiteral("state")).toString(),
             QStringLiteral("idle"));
    const QString outputPath = stop.json.value(QStringLiteral("outputPath")).toString();
    QVERIFY(outputPath.endsWith(QStringLiteral(".m4a")));
    QVERIFY(QFileInfo(outputPath).isFile());
    QVERIFY(QFileInfo(outputPath).size() > 0);

    const KeyResult idle = runKey({
        QStringLiteral("audio"), QStringLiteral("status"), QStringLiteral("--json")
    });
    QCOMPARE(idle.exitCode, 0);
    QCOMPARE(idle.json.value(QStringLiteral("state")).toString(),
             QStringLiteral("idle"));
    QCOMPARE(idle.json.value(QStringLiteral("outputPath")).toString(), outputPath);
}

QTEST_MAIN(KeyIntegrationTest)
#include "key_integration_test.moc"
