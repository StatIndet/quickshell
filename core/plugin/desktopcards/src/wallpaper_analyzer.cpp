#include "wallpaper_analyzer.h"

#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QTimer>
#include <QPainter>
#include <QThreadPool>
#include <QUrl>
#include <QtGlobal>

#include <algorithm>
#include <cmath>
#include <utility>

struct WallpaperAnalysisData {
    bool valid = false;
    int analysisWidth = 0;
    int analysisHeight = 0;
    double canvasWidth = 1.0;
    double canvasHeight = 1.0;
    double minBusyScore = 0.0;
    double maxBusyScore = 0.0;
    QString errorString;
    QVector<double> sum;
    QVector<double> squareSum;
    QVector<double> edgeSum;

    int stride() const { return analysisWidth + 1; }

    double integralValue(const QVector<double> &integral, int x, int y) const
    {
        if (x < 0 || y < 0 || x > analysisWidth || y > analysisHeight)
            return 0.0;
        return integral.at(y * stride() + x);
    }

    double rectangleSum(const QVector<double> &integral, int x, int y, int width, int height) const
    {
        const int left = std::clamp(x, 0, analysisWidth);
        const int top = std::clamp(y, 0, analysisHeight);
        const int right = std::clamp(x + width, 0, analysisWidth);
        const int bottom = std::clamp(y + height, 0, analysisHeight);
        if (right <= left || bottom <= top)
            return 0.0;
        return integralValue(integral, right, bottom) - integralValue(integral, left, bottom) -
               integralValue(integral, right, top) + integralValue(integral, left, top);
    }

    double busyScore(double x, double y, double width, double height) const
    {
        if (!valid || analysisWidth <= 0 || analysisHeight <= 0)
            return 0.0;

        const int left =
            std::clamp(static_cast<int>(std::floor(x / std::max(1.0, canvasWidth) * analysisWidth)), 0,
                       analysisWidth - 1);
        const int top =
            std::clamp(static_cast<int>(std::floor(y / std::max(1.0, canvasHeight) * analysisHeight)), 0,
                       analysisHeight - 1);
        const int right = std::clamp(static_cast<int>(std::ceil((x + std::max(1.0, width)) /
                                                                std::max(1.0, canvasWidth) * analysisWidth)),
                                     left + 1, analysisWidth);
        const int bottom =
            std::clamp(static_cast<int>(std::ceil((y + std::max(1.0, height)) / std::max(1.0, canvasHeight) *
                                                  analysisHeight)),
                       top + 1, analysisHeight);
        const int sampleWidth = right - left;
        const int sampleHeight = bottom - top;
        const double area = static_cast<double>(sampleWidth * sampleHeight);
        const double sumValue = rectangleSum(sum, left, top, sampleWidth, sampleHeight);
        const double squareValue = rectangleSum(squareSum, left, top, sampleWidth, sampleHeight);
        const double edgeValue = rectangleSum(edgeSum, left, top, sampleWidth, sampleHeight);
        const double mean = sumValue / area;
        const double variance = std::max(0.0, squareValue / area - mean * mean);
        const double normalizedVariance = std::clamp(variance / (255.0 * 255.0), 0.0, 1.0);
        const double normalizedEdge = std::clamp(edgeValue / area / 255.0, 0.0, 1.0);
        // Variance follows end-4's original signal; the gradient term makes
        // a high-contrast edge busy even when its luminance histogram is
        // otherwise narrow.
        return normalizedVariance * 0.72 + normalizedEdge * 0.28;
    }
};

namespace {

// The wallpaper canvas is a coordinate space and may legitimately be wider
// than a texture.  The analysis bitmap is not: bounding it prevents a
// transient or malformed scene aspect ratio from allocating hundreds of
// megabytes in QImage::scaled().
constexpr int kMaximumAnalysisWidth = 4096;
constexpr int kMaximumAnalysisHeight = 540;

QString localPath(const QString &sourcePath)
{
    const QString value = sourcePath.trimmed();
    if (value.startsWith(QStringLiteral("file://")))
        return QUrl(value).toLocalFile();
    return value;
}

QSharedPointer<WallpaperAnalysisData> invalidResult(int canvasWidth, int canvasHeight, const QString &message)
{
    auto result = QSharedPointer<WallpaperAnalysisData>::create();
    result->canvasWidth = std::max(1, canvasWidth);
    result->canvasHeight = std::max(1, canvasHeight);
    result->errorString = message;
    return result;
}

QImage renderForAnalysis(const QImage &source, int width, int height, const QString &fillMode)
{
    const QSize targetSize(std::max(1, width), std::max(1, height));
    const QString mode = fillMode.toLower();

    // Keep the analysis canvas faithful for the non-cropped QML image modes
    // as well.  The decoded source is already bounded to the analysis
    // resolution, so these loops stay small even for an 8K wallpaper.
    if (mode == QStringLiteral("tile") || mode == QStringLiteral("tilevertically") ||
        mode == QStringLiteral("tilehorizontally") || mode == QStringLiteral("pad")) {
        QImage result(targetSize, QImage::Format_RGB32);
        result.fill(Qt::black);
        QPainter painter(&result);
        if (mode == QStringLiteral("pad")) {
            painter.drawImage(0, 0, source);
            return result;
        }

        const int sourceWidth = std::max(1, source.width());
        const int sourceHeight = std::max(1, source.height());
        const bool repeatX = mode != QStringLiteral("tilevertically");
        const bool repeatY = mode != QStringLiteral("tilehorizontally");
        const int maxX = repeatX ? targetSize.width() : std::min(sourceWidth, targetSize.width());
        const int maxY = repeatY ? targetSize.height() : std::min(sourceHeight, targetSize.height());
        for (int y = 0; y < maxY; y += repeatY ? sourceHeight : maxY) {
            for (int x = 0; x < maxX; x += repeatX ? sourceWidth : maxX)
                painter.drawImage(x, y, source);
        }
        return result;
    }

    if (fillMode.compare(QStringLiteral("Stretch"), Qt::CaseInsensitive) == 0) {
        return source.scaled(targetSize, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    }

    if (fillMode.compare(QStringLiteral("Fit"), Qt::CaseInsensitive) == 0 ||
        fillMode.compare(QStringLiteral("PreserveAspectFit"), Qt::CaseInsensitive) == 0) {
        QImage result(targetSize, QImage::Format_RGB32);
        result.fill(Qt::black);
        const QImage fitted = source.scaled(targetSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        QPainter painter(&result);
        painter.drawImage((targetSize.width() - fitted.width()) / 2,
                          (targetSize.height() - fitted.height()) / 2, fitted);
        return result;
    }

    // Fill, PreserveAspectCrop and panorama all expose the visible rendered
    // canvas.  The caller supplies the panorama canvas aspect, so this crop
    // also remains valid for a complete wide canvas rather than a viewport.
    QImage result(targetSize, QImage::Format_RGB32);
    if (result.isNull())
        return {};
    result.fill(Qt::black);
    const double scale = std::max(double(width) / source.width(), double(height) / source.height());
    const double cropWidth = width / scale;
    const double cropHeight = height / scale;
    const QRectF crop((source.width() - cropWidth) / 2, (source.height() - cropHeight) / 2, cropWidth,
                      cropHeight);
    QPainter painter(&result);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    painter.drawImage(QRectF(QPointF(0, 0), QSizeF(targetSize)), source, crop);
    return result;
}

QSharedPointer<WallpaperAnalysisData> analyzeImage(const QString &sourcePath, int canvasWidth,
                                                   int canvasHeight, const QString &fillMode, int imageWidth,
                                                   int imageHeight, const QString &errorFallback)
{
    const int safeCanvasWidth = std::max(1, canvasWidth);
    const int safeCanvasHeight = std::max(1, canvasHeight);
    const int analysisHeight = std::clamp(safeCanvasHeight, 1, kMaximumAnalysisHeight);
    const double requestedAnalysisWidth =
        static_cast<double>(safeCanvasWidth) / static_cast<double>(safeCanvasHeight) * analysisHeight;
    const int analysisWidth =
        std::clamp(static_cast<int>(std::lround(
                       std::min(requestedAnalysisWidth, static_cast<double>(kMaximumAnalysisWidth)))),
                   1, kMaximumAnalysisWidth);
    Q_UNUSED(imageWidth);
    Q_UNUSED(imageHeight);

    const QString path = localPath(sourcePath);
    if (path.isEmpty() || path.startsWith(QLatin1Char('#')))
        return invalidResult(safeCanvasWidth, safeCanvasHeight, QStringLiteral("no-image-source"));

    QImageReader reader(path);
    if (!reader.canRead())
        return invalidResult(safeCanvasWidth, safeCanvasHeight,
                             errorFallback.isEmpty() ? QStringLiteral("image-not-readable") : errorFallback);

    const QSize sourceSize = reader.size();
    if (sourceSize.isValid()) {
        const int decodedHeight = std::clamp(sourceSize.height(), 1, kMaximumAnalysisHeight);
        const double requestedDecodedWidth = static_cast<double>(sourceSize.width()) /
                                             static_cast<double>(sourceSize.height()) * decodedHeight;
        const int decodedWidth =
            std::clamp(static_cast<int>(std::lround(
                           std::min(requestedDecodedWidth, static_cast<double>(kMaximumAnalysisWidth)))),
                       1, kMaximumAnalysisWidth);
        reader.setScaledSize(QSize(decodedWidth, decodedHeight));
    }
    QImage source = reader.read();
    if (source.isNull())
        return invalidResult(safeCanvasWidth, safeCanvasHeight, reader.errorString());

    QImage rendered = renderForAnalysis(source, analysisWidth, analysisHeight, fillMode)
                          .convertToFormat(QImage::Format_RGB32);
    if (rendered.isNull())
        return invalidResult(safeCanvasWidth, safeCanvasHeight, QStringLiteral("analysis-render-failed"));

    auto result = QSharedPointer<WallpaperAnalysisData>::create();
    result->valid = true;
    result->analysisWidth = rendered.width();
    result->analysisHeight = rendered.height();
    result->canvasWidth = safeCanvasWidth;
    result->canvasHeight = safeCanvasHeight;
    const int stride = result->stride();
    const int integralSize = (result->analysisWidth + 1) * (result->analysisHeight + 1);
    result->sum.fill(0.0, integralSize);
    result->squareSum.fill(0.0, integralSize);
    result->edgeSum.fill(0.0, integralSize);

    for (int y = 1; y <= result->analysisHeight; ++y) {
        double rowSum = 0.0;
        double rowSquareSum = 0.0;
        double rowEdgeSum = 0.0;
        for (int x = 1; x <= result->analysisWidth; ++x) {
            const QRgb pixel = rendered.pixel(x - 1, y - 1);
            const double luminance = 0.2126 * qRed(pixel) + 0.7152 * qGreen(pixel) + 0.0722 * qBlue(pixel);
            const QRgb leftPixel = rendered.pixel(std::max(0, x - 2), y - 1);
            const QRgb topPixel = rendered.pixel(x - 1, std::max(0, y - 2));
            const double leftLuminance =
                0.2126 * qRed(leftPixel) + 0.7152 * qGreen(leftPixel) + 0.0722 * qBlue(leftPixel);
            const double topLuminance =
                0.2126 * qRed(topPixel) + 0.7152 * qGreen(topPixel) + 0.0722 * qBlue(topPixel);
            const double edge = std::abs(luminance - leftLuminance) + std::abs(luminance - topLuminance);
            rowSum += luminance;
            rowSquareSum += luminance * luminance;
            rowEdgeSum += edge * 0.5;
            const int current = y * stride + x;
            result->sum[current] = result->sum[(y - 1) * stride + x] + rowSum;
            result->squareSum[current] = result->squareSum[(y - 1) * stride + x] + rowSquareSum;
            result->edgeSum[current] = result->edgeSum[(y - 1) * stride + x] + rowEdgeSum;
        }
    }

    // Expose a compact diagnostic range without retaining another per-pixel
    // map.  The solver still queries the integral image directly.
    result->minBusyScore = 1.0;
    result->maxBusyScore = 0.0;
    constexpr int diagnosticGrid = 8;
    for (int row = 0; row < diagnosticGrid; ++row) {
        for (int column = 0; column < diagnosticGrid; ++column) {
            const double x = static_cast<double>(column) / diagnosticGrid * result->canvasWidth;
            const double y = static_cast<double>(row) / diagnosticGrid * result->canvasHeight;
            const double width = result->canvasWidth / diagnosticGrid;
            const double height = result->canvasHeight / diagnosticGrid;
            const double score = result->busyScore(x, y, width, height);
            result->minBusyScore = std::min(result->minBusyScore, score);
            result->maxBusyScore = std::max(result->maxBusyScore, score);
        }
    }
    return result;
}

class AnalysisRunnable final : public QRunnable {
  public:
    AnalysisRunnable(WallpaperAnalyzer *owner, QString cacheKey, QString sourcePath, int canvasWidth,
                     int canvasHeight, QString fillMode, int imageWidth, int imageHeight)
        : m_owner(owner), m_cacheKey(std::move(cacheKey)), m_sourcePath(std::move(sourcePath)),
          m_canvasWidth(canvasWidth), m_canvasHeight(canvasHeight), m_fillMode(std::move(fillMode)),
          m_imageWidth(imageWidth), m_imageHeight(imageHeight)
    {
        setAutoDelete(true);
    }

    void run() override
    {
        const auto result = analyzeImage(m_sourcePath, m_canvasWidth, m_canvasHeight, m_fillMode,
                                         m_imageWidth, m_imageHeight, QString());
        QMetaObject::invokeMethod(
            m_owner, [owner = m_owner, cacheKey = m_cacheKey, result]() { owner->finish(cacheKey, result); },
            Qt::QueuedConnection);
    }

  private:
    WallpaperAnalyzer *m_owner;
    QString m_cacheKey;
    QString m_sourcePath;
    int m_canvasWidth;
    int m_canvasHeight;
    QString m_fillMode;
    int m_imageWidth;
    int m_imageHeight;
};

} // namespace

WallpaperAnalysisResult::WallpaperAnalysisResult(const QSharedPointer<const WallpaperAnalysisData> &data,
                                                 QObject *parent)
    : QObject(parent), m_data(data)
{}

bool WallpaperAnalysisResult::valid() const { return m_data && m_data->valid; }

int WallpaperAnalysisResult::analysisWidth() const { return m_data ? m_data->analysisWidth : 0; }

int WallpaperAnalysisResult::analysisHeight() const { return m_data ? m_data->analysisHeight : 0; }

double WallpaperAnalysisResult::canvasWidth() const { return m_data ? m_data->canvasWidth : 0.0; }

double WallpaperAnalysisResult::canvasHeight() const { return m_data ? m_data->canvasHeight : 0.0; }

double WallpaperAnalysisResult::minBusyScore() const { return m_data ? m_data->minBusyScore : 0.0; }

double WallpaperAnalysisResult::maxBusyScore() const { return m_data ? m_data->maxBusyScore : 0.0; }

QString WallpaperAnalysisResult::errorString() const { return m_data ? m_data->errorString : QString(); }

double WallpaperAnalysisResult::busyScore(double x, double y, double width, double height) const
{
    return m_data ? m_data->busyScore(x, y, width, height) : 0.0;
}

WallpaperAnalyzer::WallpaperAnalyzer(QObject *parent) : QObject(parent)
{
    // Requests are already generation-coalesced.  Serial execution also
    // avoids multiplying Qt's own image-scaling worker fan-out when screen
    // geometry and decoded image size settle during shell startup.
    m_threadPool.setMaxThreadCount(1);
    m_threadPool.setExpiryTimeout(5000);
}

WallpaperAnalyzer::~WallpaperAnalyzer() { m_threadPool.waitForDone(); }

int WallpaperAnalyzer::pendingCount() const { return m_pending.size() + (m_running ? 1 : 0); }

QString WallpaperAnalyzer::cacheKey(const QString &sourcePath, int canvasWidth, int canvasHeight,
                                    const QString &fillMode, int imageWidth, int imageHeight) const
{
    const QString path = localPath(sourcePath);
    const QFileInfo info(path);
    return path + QLatin1Char('|') + QString::number(info.lastModified().toMSecsSinceEpoch()) +
           QLatin1Char('|') + QString::number(info.size()) + QLatin1Char('|') + QString::number(canvasWidth) +
           QLatin1Char('x') + QString::number(canvasHeight) + QLatin1Char('|') + fillMode + QLatin1Char('|') +
           QString::number(imageWidth) + QLatin1Char('x') + QString::number(imageHeight);
}

void WallpaperAnalyzer::request(const QString &requestKey, int generation, const QString &sourcePath,
                                int canvasWidth, int canvasHeight, const QString &fillMode, int imageWidth,
                                int imageHeight)
{
    release(requestKey);
    m_pending.insert(requestKey,
                     {cacheKey(sourcePath, canvasWidth, canvasHeight, fillMode, imageWidth, imageHeight),
                      sourcePath, fillMode, generation, canvasWidth, canvasHeight, imageWidth, imageHeight});
    emit pendingCountChanged();
    scheduleNext();
}

void WallpaperAnalyzer::release(const QString &requestKey)
{
    if (auto *result = m_results.take(requestKey))
        result->deleteLater();
    if (m_pending.remove(requestKey))
        emit pendingCountChanged();
}

void WallpaperAnalyzer::scheduleNext()
{
    if (m_running || m_scheduled || m_pending.isEmpty())
        return;
    m_scheduled = true;
    QTimer::singleShot(0, this, [this]() {
        m_scheduled = false;
        processNext();
    });
}

void WallpaperAnalyzer::processNext()
{
    if (m_running || m_pending.isEmpty())
        return;
    const QString requestKey = m_pending.constBegin().key();
    const PendingRequest request = m_pending.value(requestKey);
    if (const auto *cached = m_cache.object(request.key)) {
        auto *result = new WallpaperAnalysisResult(*cached, this);
        m_pending.remove(requestKey);
        m_results.insert(requestKey, result);
        emit analysisReady(requestKey, request.generation, result);
        emit pendingCountChanged();
        scheduleNext();
        return;
    }
    m_running = true;
    emit pendingCountChanged();
    m_threadPool.start(new AnalysisRunnable(this, request.key, request.sourcePath, request.canvasWidth,
                                            request.canvasHeight, request.fillMode, request.imageWidth,
                                            request.imageHeight));
}

void WallpaperAnalyzer::finish(const QString &key, const QSharedPointer<const WallpaperAnalysisData> &data)
{
    const qsizetype bytes =
        sizeof(WallpaperAnalysisData) +
        (data->sum.capacity() + data->squareSum.capacity() + data->edgeSum.capacity()) * sizeof(double);
    m_cache.insert(key, new QSharedPointer<const WallpaperAnalysisData>(data),
                   static_cast<int>((bytes + 1023) / 1024));
    m_running = false;
    emit pendingCountChanged();
    // Resolve only the latest requests, including cache hits, on the owning thread.
    scheduleNext();
}
