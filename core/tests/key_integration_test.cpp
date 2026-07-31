#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

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
    void clipboardListIsStructured();
    void clipboardListWorksWithoutWlCopy();
    void clipboardRejectsInvalidId();
    void clipboardRestoresOriginalBytes();
    void clipboardRestoresImageWithMime();
    void clipboardInspectsTextAndImage();
    void clipboardClassifiesFiles();
    void clipboardReportsDecodeAndCopyFailures();
    void clipboardPreviewCacheIsCleaned();
    void clipboardDeleteAndClearAreSafe();
    void clipboardReportsMissingDependencies();
    void clipboardReportsInactiveWatcher();

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
    m_environment.insert(
        QStringLiteral("CLAVIS_CLIPBOARD_WATCHER_RUNNING"),
        QStringLiteral("1"));
    const QString fileRoot =
        m_temporary->filePath(QStringLiteral("clipboard-files"));
    QVERIFY(QDir().mkpath(fileRoot));
    QVERIFY(QDir().mkpath(
        QDir(fileRoot).filePath(QStringLiteral("folder"))));
    m_environment.insert(QStringLiteral("CLAVIS_TEST_FILE_ROOT"), fileRoot);
    m_environment.insert(
        QStringLiteral("CLAVIS_CLIPBOARD_CACHE_DIR"),
        m_temporary->filePath(QStringLiteral("clipboard-cache")));
    const QByteArray png = QByteArray::fromBase64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC"
        "AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=");
    const QList<QPair<QString, QByteArray>> files{
        {QStringLiteral("image.png"), png},
        {QStringLiteral("video.mp4"), QByteArrayLiteral("fake video")},
        {QStringLiteral("archive.zip"), QByteArrayLiteral("PK fake archive")},
        {QStringLiteral("main.cpp"), QByteArrayLiteral("int main() { return 0; }\n")},
    };
    for (const auto &item : files) {
        QFile file(QDir(fileRoot).filePath(item.first));
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(item.second), item.second.size());
    }
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

void KeyIntegrationTest::clipboardListIsStructured()
{
    const KeyResult result = runKey({
        QStringLiteral("clipboard"),
        QStringLiteral("list"),
        QStringLiteral("--format"),
        QStringLiteral("json"),
        QStringLiteral("--limit"),
        QStringLiteral("2"),
    });
    QCOMPARE(result.exitCode, 0);
    QCOMPARE(result.json.value(QStringLiteral("ok")).toBool(), true);
    QCOMPARE(result.json.value(QStringLiteral("canList")).toBool(), true);
    QCOMPARE(result.json.value(QStringLiteral("canRestore")).toBool(), true);
    const QJsonArray entries =
        result.json.value(QStringLiteral("entries")).toArray();
    QCOMPARE(entries.size(), 2);
    QCOMPARE(entries.at(0).toObject().value(QStringLiteral("id")).toString(),
             QStringLiteral("9"));
    QCOMPARE(entries.at(0).toObject()
                 .value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("text"));
    QCOMPARE(entries.at(1).toObject()
                 .value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("image"));
    QCOMPARE(result.json.value(QStringLiteral("schemaVersion")).toInt(), 2);
    QCOMPARE(result.json.value(QStringLiteral("capabilities")).toObject()
                 .value(QStringLiteral("inspect")).toBool(), true);
}

void KeyIntegrationTest::clipboardListWorksWithoutWlCopy()
{
    const QString bin =
        m_temporary->filePath(QStringLiteral("cliphist-only-bin"));
    QVERIFY(QDir().mkpath(bin));
    QVERIFY(QFile::link(
        QDir(QStringLiteral(KEY_FAKE_BIN)).filePath(QStringLiteral("cliphist")),
        QDir(bin).filePath(QStringLiteral("cliphist"))));
    m_environment.insert(QStringLiteral("PATH"), bin);
    const KeyResult result = runKey({
        QStringLiteral("clipboard"), QStringLiteral("list"),
        QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(result.exitCode, 0);
    QCOMPARE(result.json.value(QStringLiteral("canList")).toBool(), true);
    QCOMPARE(result.json.value(QStringLiteral("canRestore")).toBool(), false);
    QVERIFY(result.json.value(QStringLiteral("entries")).toArray().size() > 0);
}

void KeyIntegrationTest::clipboardRejectsInvalidId()
{
    const KeyResult result = runKey({
        QStringLiteral("clipboard"),
        QStringLiteral("restore"),
        QStringLiteral("9;touch /tmp/not-allowed"),
        QStringLiteral("--format"),
        QStringLiteral("json"),
    });
    QCOMPARE(result.exitCode, 2);
    QCOMPARE(result.json.value(QStringLiteral("ok")).toBool(), false);
    QCOMPARE(result.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("usage_error"));
}

void KeyIntegrationTest::clipboardRestoresOriginalBytes()
{
    const QString trace =
        m_temporary->filePath(QStringLiteral("clipboard-trace"));
    m_environment.insert(QStringLiteral("CLAVIS_TEST_CLIPBOARD_TRACE"), trace);
    const KeyResult result = runKey({
        QStringLiteral("clipboard"),
        QStringLiteral("restore"),
        QStringLiteral("9"),
        QStringLiteral("--format"),
        QStringLiteral("json"),
    });
    QCOMPARE(result.exitCode, 0);
    QFile traceFile(trace);
    QVERIFY(traceFile.open(QIODevice::ReadOnly));
    QCOMPARE(traceFile.readAll(), QByteArrayLiteral("copy:alpha\nbeta"));
    QCOMPARE(result.json.value(QStringLiteral("mimeType")).toString(),
             QStringLiteral("text/plain;charset=utf-8"));
    QVERIFY(!result.json.contains(QStringLiteral("preview")));
}

void KeyIntegrationTest::clipboardRestoresImageWithMime()
{
    const QString trace =
        m_temporary->filePath(QStringLiteral("clipboard-image-trace"));
    const QString arguments =
        m_temporary->filePath(QStringLiteral("wl-copy-arguments"));
    m_environment.insert(QStringLiteral("CLAVIS_TEST_CLIPBOARD_TRACE"), trace);
    m_environment.insert(QStringLiteral("CLAVIS_TEST_WL_COPY_ARGUMENTS"),
                         arguments);
    const KeyResult result = runKey({
        QStringLiteral("clipboard"), QStringLiteral("restore"),
        QStringLiteral("8"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(result.exitCode, 0);
    QCOMPARE(result.json.value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("image"));
    QCOMPARE(result.json.value(QStringLiteral("mimeType")).toString(),
             QStringLiteral("image/png"));
    QFile argumentsFile(arguments);
    QVERIFY(argumentsFile.open(QIODevice::ReadOnly));
    QCOMPARE(argumentsFile.readAll(), QByteArrayLiteral("--type\nimage/png"));
    QFile traceFile(trace);
    QVERIFY(traceFile.open(QIODevice::ReadOnly));
    QVERIFY(traceFile.readAll().startsWith(QByteArrayLiteral("copy:\x89PNG")));
}

void KeyIntegrationTest::clipboardInspectsTextAndImage()
{
    const KeyResult text = runKey({
        QStringLiteral("clipboard"), QStringLiteral("inspect"),
        QStringLiteral("9"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(text.exitCode, 0);
    QCOMPARE(text.json.value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("text"));
    QCOMPARE(text.json.value(QStringLiteral("textSubtype")).toString(),
             QStringLiteral("plain"));
    QCOMPARE(text.json.value(QStringLiteral("preview")).toString(),
             QStringLiteral("alpha\nbeta"));

    const KeyResult image = runKey({
        QStringLiteral("clipboard"), QStringLiteral("preview"),
        QStringLiteral("8"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(image.exitCode, 0);
    QCOMPARE(image.json.value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("image"));
    QCOMPARE(image.json.value(QStringLiteral("width")).toInt(), 1);
    QCOMPARE(image.json.value(QStringLiteral("height")).toInt(), 1);
    const QUrl preview(image.json.value(QStringLiteral("previewUrl")).toString());
    QVERIFY(preview.isLocalFile());
    QVERIFY(QFileInfo::exists(preview.toLocalFile()));
    const QFileDevice::Permissions publicPermissions =
        QFileInfo(preview.toLocalFile()).permissions()
        & (QFileDevice::ReadGroup | QFileDevice::WriteGroup
           | QFileDevice::ExeGroup | QFileDevice::ReadOther
           | QFileDevice::WriteOther | QFileDevice::ExeOther);
    QCOMPARE(publicPermissions, QFileDevice::Permissions{});

    const KeyResult code = runKey({
        QStringLiteral("clipboard"), QStringLiteral("inspect"),
        QStringLiteral("2"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(code.exitCode, 0);
    QCOMPARE(code.json.value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("text"));
    QCOMPARE(code.json.value(QStringLiteral("textSubtype")).toString(),
             QStringLiteral("code"));

    const KeyResult url = runKey({
        QStringLiteral("clipboard"), QStringLiteral("inspect"),
        QStringLiteral("1"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(url.exitCode, 0);
    QCOMPARE(url.json.value(QStringLiteral("textSubtype")).toString(),
             QStringLiteral("url"));
    QCOMPARE(url.json.value(QStringLiteral("icon")).toString(),
             QStringLiteral("link"));

    const KeyResult damagedImage = runKey({
        QStringLiteral("clipboard"), QStringLiteral("preview"),
        QStringLiteral("10"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(damagedImage.exitCode, 0);
    QCOMPARE(damagedImage.json.value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("binary"));
    QCOMPARE(damagedImage.json.value(QStringLiteral("previewUrl")).toString(),
             QString());
}

void KeyIntegrationTest::clipboardClassifiesFiles()
{
    const KeyResult single = runKey({
        QStringLiteral("clipboard"), QStringLiteral("inspect"),
        QStringLiteral("7"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(single.exitCode, 0);
    QCOMPARE(single.json.value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("file"));
    QCOMPARE(single.json.value(QStringLiteral("fileCount")).toInt(), 1);
    QCOMPARE(single.json.value(QStringLiteral("mimeType")).toString(),
             QStringLiteral("text/uri-list"));
    QVERIFY(!single.json.value(QStringLiteral("previewUrl")).toString().isEmpty());

    const KeyResult copied = runKey({
        QStringLiteral("clipboard"), QStringLiteral("inspect"),
        QStringLiteral("6"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(copied.exitCode, 0);
    QCOMPARE(copied.json.value(QStringLiteral("payloadKind")).toString(),
             QStringLiteral("file-list"));
    QCOMPARE(copied.json.value(QStringLiteral("fileOperation")).toString(),
             QStringLiteral("copy"));
    QCOMPARE(copied.json.value(QStringLiteral("fileCount")).toInt(), 2);
    QCOMPARE(copied.json.value(QStringLiteral("mimeType")).toString(),
             QStringLiteral("x-special/gnome-copied-files"));
    const QJsonArray copiedFiles =
        copied.json.value(QStringLiteral("files")).toArray();
    QCOMPARE(copiedFiles.at(0).toObject()
                 .value(QStringLiteral("category")).toString(),
             QStringLiteral("video"));
    QCOMPARE(copiedFiles.at(1).toObject()
                 .value(QStringLiteral("category")).toString(),
             QStringLiteral("archive"));

    const QString arguments =
        m_temporary->filePath(QStringLiteral("file-wl-copy-arguments"));
    m_environment.insert(QStringLiteral("CLAVIS_TEST_WL_COPY_ARGUMENTS"),
                         arguments);
    const KeyResult restoredFiles = runKey({
        QStringLiteral("clipboard"), QStringLiteral("restore"),
        QStringLiteral("6"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(restoredFiles.exitCode, 0);
    QFile argumentFile(arguments);
    QVERIFY(argumentFile.open(QIODevice::ReadOnly));
    QCOMPARE(argumentFile.readAll(),
             QByteArrayLiteral("--type\nx-special/gnome-copied-files"));

    const KeyResult cut = runKey({
        QStringLiteral("clipboard"), QStringLiteral("inspect"),
        QStringLiteral("5"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(cut.exitCode, 0);
    QCOMPARE(cut.json.value(QStringLiteral("fileOperation")).toString(),
             QStringLiteral("cut"));
    const QJsonObject sourceFile =
        cut.json.value(QStringLiteral("files")).toArray().first().toObject();
    QCOMPARE(sourceFile.value(QStringLiteral("category")).toString(),
             QStringLiteral("source-code"));
    QCOMPARE(sourceFile.value(QStringLiteral("icon")).toString(),
             QStringLiteral("code"));

    const KeyResult uriList = runKey({
        QStringLiteral("clipboard"), QStringLiteral("inspect"),
        QStringLiteral("4"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(uriList.exitCode, 0);
    QCOMPARE(uriList.json.value(QStringLiteral("fileCount")).toInt(), 3);
    QCOMPARE(uriList.json.value(QStringLiteral("mimeType")).toString(),
             QStringLiteral("text/uri-list"));

    const KeyResult directory = runKey({
        QStringLiteral("clipboard"), QStringLiteral("inspect"),
        QStringLiteral("3"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(directory.exitCode, 0);
    const QJsonObject folder =
        directory.json.value(QStringLiteral("files")).toArray().first().toObject();
    QCOMPARE(folder.value(QStringLiteral("category")).toString(),
             QStringLiteral("folder"));
    QCOMPARE(folder.value(QStringLiteral("icon")).toString(),
             QStringLiteral("folder"));
}

void KeyIntegrationTest::clipboardReportsDecodeAndCopyFailures()
{
    m_environment.insert(QStringLiteral("CLAVIS_TEST_CLIPHIST_DECODE_FAIL"),
                         QStringLiteral("1"));
    const KeyResult decode = runKey({
        QStringLiteral("clipboard"), QStringLiteral("restore"),
        QStringLiteral("9"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(decode.exitCode, 1);
    QCOMPARE(decode.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("cliphist_decode_failed"));
    m_environment.remove(QStringLiteral("CLAVIS_TEST_CLIPHIST_DECODE_FAIL"));

    m_environment.insert(QStringLiteral("CLAVIS_TEST_WL_COPY_FAIL"),
                         QStringLiteral("1"));
    const KeyResult copy = runKey({
        QStringLiteral("clipboard"), QStringLiteral("restore"),
        QStringLiteral("9"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(copy.exitCode, 1);
    QCOMPARE(copy.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("wl_copy_failed"));
}

void KeyIntegrationTest::clipboardPreviewCacheIsCleaned()
{
    const KeyResult preview = runKey({
        QStringLiteral("clipboard"), QStringLiteral("preview"),
        QStringLiteral("8"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(preview.exitCode, 0);
    const QString previewPath =
        QUrl(preview.json.value(QStringLiteral("previewUrl")).toString())
            .toLocalFile();
    QVERIFY(QFileInfo::exists(previewPath));
    QCOMPARE(runKey({
        QStringLiteral("clipboard"), QStringLiteral("delete"),
        QStringLiteral("8"), QStringLiteral("--format"), QStringLiteral("json"),
    }).exitCode, 0);
    QVERIFY(!QFileInfo::exists(previewPath));

    const KeyResult secondPreview = runKey({
        QStringLiteral("clipboard"), QStringLiteral("preview"),
        QStringLiteral("8"), QStringLiteral("--format"), QStringLiteral("json"),
    });
    QCOMPARE(secondPreview.exitCode, 0);
    const QString secondPath =
        QUrl(secondPreview.json.value(QStringLiteral("previewUrl")).toString())
            .toLocalFile();
    QVERIFY(QFileInfo::exists(secondPath));
    QCOMPARE(runKey({
        QStringLiteral("clipboard"), QStringLiteral("clear"),
        QStringLiteral("--format"), QStringLiteral("json"),
    }).exitCode, 0);
    QVERIFY(!QFileInfo::exists(secondPath));
}

void KeyIntegrationTest::clipboardDeleteAndClearAreSafe()
{
    const QString trace =
        m_temporary->filePath(QStringLiteral("clipboard-trace"));
    m_environment.insert(QStringLiteral("CLAVIS_TEST_CLIPBOARD_TRACE"), trace);
    QCOMPARE(runKey({
        QStringLiteral("clipboard"),
        QStringLiteral("delete"),
        QStringLiteral("9"),
        QStringLiteral("--format"),
        QStringLiteral("json"),
    }).exitCode, 0);
    QCOMPARE(runKey({
        QStringLiteral("clipboard"),
        QStringLiteral("clear"),
        QStringLiteral("--format"),
        QStringLiteral("json"),
    }).exitCode, 0);
    QFile traceFile(trace);
    QVERIFY(traceFile.open(QIODevice::ReadOnly));
    QCOMPARE(traceFile.readAll(), QByteArrayLiteral("delete:9\nwipe\n"));
}

void KeyIntegrationTest::clipboardReportsMissingDependencies()
{
    const QString emptyPath =
        m_temporary->filePath(QStringLiteral("clipboard-empty-path"));
    QVERIFY(QDir().mkpath(emptyPath));
    m_environment.insert(QStringLiteral("PATH"), emptyPath);
    const KeyResult result = runKey({
        QStringLiteral("clipboard"),
        QStringLiteral("list"),
        QStringLiteral("--format"),
        QStringLiteral("json"),
    });
    QCOMPARE(result.exitCode, 3);
    QCOMPARE(result.json.value(QStringLiteral("available")).toBool(), false);
    QCOMPARE(result.json.value(QStringLiteral("entries")).toArray().size(), 0);
    QCOMPARE(result.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("cliphist_unavailable"));
}

void KeyIntegrationTest::clipboardReportsInactiveWatcher()
{
    m_environment.insert(
        QStringLiteral("CLAVIS_CLIPBOARD_WATCHER_RUNNING"),
        QStringLiteral("0"));
    const KeyResult result = runKey({
        QStringLiteral("clipboard"),
        QStringLiteral("status"),
        QStringLiteral("--format"),
        QStringLiteral("json"),
    });
    QCOMPARE(result.exitCode, 3);
    QCOMPARE(result.json.value(QStringLiteral("available")).toBool(), false);
    QCOMPARE(
        result.json.value(QStringLiteral("watcherRunning")).toBool(),
        false);
    QCOMPARE(result.json.value(QStringLiteral("error")).toObject()
                 .value(QStringLiteral("code")).toString(),
             QStringLiteral("cliphist_watcher_inactive"));
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
