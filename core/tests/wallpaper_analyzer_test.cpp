#include "wallpaper_analyzer.h"

#include <QImage>
#include <QPointer>
#include <QTemporaryDir>
#include <QTest>

class WallpaperAnalyzerTest final : public QObject {
    Q_OBJECT

  private slots:
    void findsLowAndHighBusyRegions();
    void staleGenerationCannotPublish();
    void invalidWallpaperFallsBackGracefully();
    void pathologicalCanvasAspectIsBounded();
    void releasesResultsAndCoalescesCachedRequests();
};

void WallpaperAnalyzerTest::findsLowAndHighBusyRegions()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString path = directory.filePath(QStringLiteral("synthetic.png"));
    QImage image(240, 120, QImage::Format_RGB32);
    for (int y = 0; y < image.height(); ++y) {
        for (int x = 0; x < image.width(); ++x) {
            if (x < image.width() / 2)
                image.setPixel(x, y, qRgb(220, 220, 220));
            else
                image.setPixel(x, y, qRgb((x % 2) ? 0 : 255, 0, 0));
        }
    }
    QVERIFY(image.save(path));

    WallpaperAnalyzer analyzer;
    WallpaperAnalysisResult *result = nullptr;
    connect(&analyzer, &WallpaperAnalyzer::analysisReady, this,
            [&](const QString &, int, WallpaperAnalysisResult *value) { result = value; });

    analyzer.request(QStringLiteral("busy-test"), 1, path, 240, 120, QStringLiteral("Stretch"), 240, 120);
    QTRY_VERIFY_WITH_TIMEOUT(result != nullptr, 5000);
    QTRY_COMPARE_WITH_TIMEOUT(analyzer.pendingCount(), 0, 5000);

    QVERIFY(result->valid());
    QVERIFY(result->minBusyScore() >= 0.0);
    QVERIFY(result->maxBusyScore() <= 1.0);
    QVERIFY2(
        result->maxBusyScore() > result->minBusyScore(),
        qPrintable(QStringLiteral("min=%1 max=%2").arg(result->minBusyScore()).arg(result->maxBusyScore())));
    qInfo().noquote() << "[DesktopCards] analyzer test busy range" << result->minBusyScore()
                      << result->maxBusyScore();
    const double calm = result->busyScore(0, 0, 110, 120);
    const double busy = result->busyScore(130, 0, 110, 120);
    QVERIFY2(busy > calm, qPrintable(QStringLiteral("busy=%1 calm=%2").arg(busy).arg(calm)));
}

void WallpaperAnalyzerTest::staleGenerationCannotPublish()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());

    const QString path = directory.filePath(QStringLiteral("stale.png"));
    QImage image(320, 180, QImage::Format_RGB32);
    image.fill(qRgb(100, 140, 180));
    QVERIFY(image.save(path));

    WallpaperAnalyzer analyzer;
    QList<int> generations;
    connect(
        &analyzer, &WallpaperAnalyzer::analysisReady, this,
        [&](const QString &, int generation, WallpaperAnalysisResult *) { generations.append(generation); });

    analyzer.request(QStringLiteral("same-request"), 1, path, 320, 180, QStringLiteral("Stretch"), 320, 180);
    analyzer.request(QStringLiteral("same-request"), 2, path, 320, 180, QStringLiteral("Stretch"), 320, 180);

    QTRY_VERIFY_WITH_TIMEOUT(generations.contains(2), 5000);
    QTRY_COMPARE_WITH_TIMEOUT(analyzer.pendingCount(), 0, 5000);
    QVERIFY(!generations.contains(1));
}

void WallpaperAnalyzerTest::invalidWallpaperFallsBackGracefully()
{
    WallpaperAnalyzer analyzer;
    WallpaperAnalysisResult *result = nullptr;
    connect(&analyzer, &WallpaperAnalyzer::analysisReady, this,
            [&](const QString &, int, WallpaperAnalysisResult *value) { result = value; });

    analyzer.request(QStringLiteral("invalid-test"), 1, QStringLiteral("/path/that/does/not/exist.png"), 1920,
                     1080, QStringLiteral("Fill"), 0, 0);
    QTRY_VERIFY_WITH_TIMEOUT(result != nullptr, 5000);
    QVERIFY(!result->valid());
    QCOMPARE(result->canvasWidth(), 1920.0);
    QCOMPARE(result->canvasHeight(), 1080.0);
    QCOMPARE(result->busyScore(0, 0, 100, 100), 0.0);
}

void WallpaperAnalyzerTest::pathologicalCanvasAspectIsBounded()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("wallpaper.png"));
    QImage image(1, 540, QImage::Format_RGB32);
    image.fill(Qt::gray);
    QVERIFY(image.save(path));

    WallpaperAnalyzer analyzer;
    WallpaperAnalysisResult *result = nullptr;
    connect(&analyzer, &WallpaperAnalyzer::analysisReady, this,
            [&](const QString &, int, WallpaperAnalysisResult *value) { result = value; });
    analyzer.request(QStringLiteral("pathological"), 1, path, 2000000, 1, QStringLiteral("panorama"), 64, 64);
    QTRY_VERIFY_WITH_TIMEOUT(result != nullptr, 5000);
    QVERIFY(result->valid());
    QVERIFY(result->analysisWidth() <= 4096);
    QVERIFY(result->analysisHeight() <= 540);
}

void WallpaperAnalyzerTest::releasesResultsAndCoalescesCachedRequests()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("wallpaper.png"));
    QImage image(32, 32, QImage::Format_RGB32);
    image.fill(Qt::gray);
    QVERIFY(image.save(path));
    WallpaperAnalyzer analyzer;
    QPointer<WallpaperAnalysisResult> result;
    QList<int> generations;
    connect(&analyzer, &WallpaperAnalyzer::analysisReady, this,
            [&](const QString &, int generation, WallpaperAnalysisResult *value) {
                result = value;
                generations.append(generation);
            });
    analyzer.request("screen", 1, path, 32, 32, "Fill", 32, 32);
    QTRY_COMPARE(generations.size(), 1);
    QPointer<WallpaperAnalysisResult> previous = result;
    for (int generation = 2; generation <= 100; ++generation)
        analyzer.request("screen", generation, path, 32, 32, "Fill", 32, 32);
    QCOMPARE(analyzer.pendingCount(), 1);
    QTRY_COMPARE(generations, QList<int>({1, 100}));
    QTRY_VERIFY(previous.isNull());
    QVERIFY(result && result->valid());
    analyzer.release("screen");
    QTRY_VERIFY(result.isNull());
    analyzer.request("screen", 101, path, 32, 32, "Fill", 32, 32);
    analyzer.release("screen");
    QCoreApplication::processEvents();
    QCOMPARE(generations, QList<int>({1, 100}));
    QCOMPARE(analyzer.pendingCount(), 0);
}

QTEST_MAIN(WallpaperAnalyzerTest)
#include "wallpaper_analyzer_test.moc"
