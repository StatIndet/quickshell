#include "weather_map_provider.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrlQuery>
#include <QtMath>
#include <qt6keychain/keychain.h>

namespace {
constexpr auto kOsmTileHost = "https://tile.openstreetmap.org";
constexpr auto kOpenWeatherTileHost = "https://tile.openweathermap.org";
constexpr auto kOpenMeteoAirQualityHost = "https://air-quality-api.open-meteo.com";
constexpr auto kUserAgent = "ClavisWeatherMap/1.0 (native Quickshell weather map)";
constexpr auto kKeychainService = "Clavis.Quickshell.WeatherMap";
constexpr auto kKeychainEntry = "openweather-api-key";

qint64 cacheControlMaxAge(const QByteArray &header)
{
    const QList<QByteArray> directives = header.split(',');
    for (QByteArray directive : directives) {
        directive = directive.trimmed();
        if (!directive.startsWith("max-age="))
            continue;

        bool ok = false;
        const qint64 seconds = directive.mid(8).toLongLong(&ok);
        if (ok && seconds >= 0)
            return seconds;
    }
    return -1;
}
}

WeatherMapProvider::WeatherMapProvider(QObject *parent)
    : QObject(parent)
{
    const QString genericCache = QStandardPaths::writableLocation(
        QStandardPaths::GenericCacheLocation
    );
    m_cacheRoot = (genericCache.isEmpty()
        ? QDir::homePath() + QStringLiteral("/.cache")
        : genericCache)
        + QStringLiteral("/quickshell/weather-map");
    QDir().mkpath(m_cacheRoot);

    m_status = QStringLiteral("loading_credentials");
    loadApiKey();
}

bool WeatherMapProvider::active() const
{
    return m_active;
}

void WeatherMapProvider::setActive(bool active)
{
    if (m_active == active)
        return;

    m_active = active;
    if (!m_active) {
        m_subscribers.clear();
        m_gridSubscribers.clear();
        while (!m_queue.isEmpty()) {
            m_pendingKeys.remove(m_queue.dequeue().key);
        }
        while (!m_gridQueue.isEmpty()) {
            m_pendingKeys.remove(m_gridQueue.dequeue().key);
        }
        updateBusy();
    } else if (!m_credentialsReady) {
        setStatus(QStringLiteral("loading_credentials"));
    } else if (m_apiKey.isEmpty()) {
        setStatus(
            QStringLiteral("not_configured"),
            QStringLiteral("地图服务未配置")
        );
    }
    emit activeChanged();
}

bool WeatherMapProvider::apiConfigured() const
{
    return !m_apiKey.isEmpty();
}

bool WeatherMapProvider::credentialsReady() const
{
    return m_credentialsReady;
}

bool WeatherMapProvider::credentialBusy() const
{
    return m_credentialBusy;
}

bool WeatherMapProvider::busy() const
{
    return m_busy;
}

QString WeatherMapProvider::status() const
{
    return m_status;
}

QString WeatherMapProvider::errorMessage() const
{
    return m_errorMessage;
}

void WeatherMapProvider::beginViewport(int generation)
{
    if (m_generation == generation)
        return;

    m_generation = generation;
    for (auto iterator = m_subscribers.begin(); iterator != m_subscribers.end();) {
        QList<TileSubscriber> current;
        for (const TileSubscriber &subscriber : std::as_const(iterator.value())) {
            if (subscriber.generation == m_generation)
                current.append(subscriber);
        }
        if (current.isEmpty())
            iterator = m_subscribers.erase(iterator);
        else {
            iterator.value() = current;
            ++iterator;
        }
    }
    for (auto iterator = m_gridSubscribers.begin();
        iterator != m_gridSubscribers.end();) {
        QList<GridSubscriber> current;
        for (const GridSubscriber &subscriber : std::as_const(iterator.value())) {
            if (subscriber.generation == m_generation)
                current.append(subscriber);
        }
        if (current.isEmpty())
            iterator = m_gridSubscribers.erase(iterator);
        else {
            iterator.value() = current;
            ++iterator;
        }
    }
    pruneObsoleteQueue();
}

QVariantMap WeatherMapProvider::requestTile(
    const QString &kind,
    const QString &layer,
    int zoom,
    int x,
    int y,
    int generation,
    bool forceRefresh
)
{
    QVariantMap result;
    result.insert(QStringLiteral("state"), QStringLiteral("invalid"));

    const bool osm = kind == QStringLiteral("base");
    const bool weather = kind == QStringLiteral("weather");
    const QString safeLayer = weather ? normalizedLayer(layer) : QString();

    if ((!osm && !weather)
        || (weather && safeLayer.isEmpty())
        || !validTileCoordinate(zoom, y)) {
        result.insert(QStringLiteral("errorCode"), QStringLiteral("invalid_request"));
        return result;
    }

    x = wrappedX(x, zoom);
    TileTask task;
    task.kind = osm ? QStringLiteral("base") : QStringLiteral("weather");
    task.layer = safeLayer;
    task.zoom = zoom;
    task.x = x;
    task.y = y;
    task.osm = osm;
    task.key = taskKey(task.kind, task.layer, zoom, x, y);
    task.cachePath = tileCachePath(task.kind, task.layer, zoom, x, y);
    task.remoteUrl = remoteTileUrl(task.kind, task.layer, zoom, x, y);

    const bool hasCache = QFileInfo::exists(task.cachePath);
    const bool fresh = hasCache && cacheIsFresh(task);
    if (hasCache)
        result = cacheResult(task, !fresh);

    if (weather && !m_credentialsReady) {
        result.insert(
            QStringLiteral("state"),
            hasCache ? QStringLiteral("stale") : QStringLiteral("loading")
        );
        result.insert(
            QStringLiteral("errorCode"),
            QStringLiteral("credentials_loading")
        );
        return result;
    }

    if (weather && m_apiKey.isEmpty()) {
        result.insert(QStringLiteral("state"), hasCache
            ? QStringLiteral("stale")
            : QStringLiteral("not_configured"));
        result.insert(QStringLiteral("errorCode"), QStringLiteral("not_configured"));
        setStatus(
            QStringLiteral("not_configured"),
            QStringLiteral("地图服务未配置")
        );
        return result;
    }

    if (!m_active
        || generation != m_generation
        || (fresh && !forceRefresh)) {
        return result;
    }

    TileSubscriber subscriber;
    subscriber.kind = task.kind;
    subscriber.layer = task.layer;
    subscriber.zoom = task.zoom;
    subscriber.x = task.x;
    subscriber.y = task.y;
    subscriber.generation = generation;
    enqueue(task, subscriber);
    result.insert(QStringLiteral("state"), hasCache
        ? QStringLiteral("stale")
        : QStringLiteral("loading"));
    return result;
}

QVariantMap WeatherMapProvider::requestGrid(
    const QString &kind,
    const QVariantList &points,
    int generation,
    bool forceRefresh
)
{
    QVariantMap result;
    result.insert(QStringLiteral("state"), QStringLiteral("invalid"));

    const QString safeKind = normalizedGridKind(kind);
    const QList<GridPoint> safePoints = normalizedGridPoints(points);
    if (safeKind.isEmpty() || safePoints.size() < 2) {
        result.insert(QStringLiteral("errorCode"), QStringLiteral("invalid_request"));
        return result;
    }

    GridTask task;
    task.kind = safeKind;
    task.points = safePoints;
    task.cachePath = gridCachePath(safeKind, safePoints);
    task.remoteUrl = remoteGridUrl(safeKind, safePoints);
    task.key = QStringLiteral("grid:%1:%2")
        .arg(safeKind, QFileInfo(task.cachePath).baseName());

    const QVariantMap cache = readGridCache(task.cachePath);
    const bool hasCache = !cache
        .value(QStringLiteral("samples"))
        .toList()
        .isEmpty();
    const bool fresh = hasCache && gridCacheIsFresh(task);
    if (hasCache) {
        result = cache;
        result.insert(
            QStringLiteral("state"),
            fresh ? QStringLiteral("ready") : QStringLiteral("stale")
        );
        result.insert(QStringLiteral("cached"), true);
        result.insert(QStringLiteral("stale"), !fresh);
    }

    if (!m_active
        || generation != m_generation
        || (fresh && !forceRefresh)) {
        return result;
    }

    GridSubscriber subscriber;
    subscriber.kind = safeKind;
    subscriber.generation = generation;
    enqueueGrid(task, subscriber);
    result.insert(
        QStringLiteral("state"),
        hasCache ? QStringLiteral("stale") : QStringLiteral("loading")
    );
    return result;
}

QVariantMap WeatherMapProvider::storeApiKey(const QString &apiKey)
{
    QVariantMap result {
        { QStringLiteral("ok"), false },
        { QStringLiteral("pending"), false }
    };

    const QString normalized = apiKey.trimmed();
    if (!validApiKey(normalized)) {
        result.insert(
            QStringLiteral("message"),
            QStringLiteral("请输入有效的 OpenWeather API key")
        );
        return result;
    }

    if (m_credentialBusy) {
        result.insert(
            QStringLiteral("message"),
            QStringLiteral("系统密钥环正在处理另一项操作")
        );
        return result;
    }

    auto *job = new QKeychain::WritePasswordJob(
        QString::fromLatin1(kKeychainService),
        this
    );
    job->setKey(QString::fromLatin1(kKeychainEntry));
    job->setTextData(normalized);
    job->setInsecureFallback(false);
    connect(
        job,
        &QKeychain::Job::finished,
        this,
        [this, normalized](QKeychain::Job *finishedJob) {
            if (finishedJob->error() != QKeychain::NoError) {
                finishCredentialOperation();
                emit credentialOperationFinished(
                    QStringLiteral("store"),
                    false,
                    QStringLiteral("无法将密钥写入系统密钥环")
                );
                return;
            }

            setCredentialsReady(true);
            setStatus(QStringLiteral("idle"));
            replaceApiKey(normalized.toUtf8(), true);
            finishCredentialOperation();
            emit credentialOperationFinished(
                QStringLiteral("store"),
                true,
                QStringLiteral("密钥已安全保存并立即生效")
            );
        }
    );
    setCredentialBusy(true);
    job->start();

    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("pending"), true);
    result.insert(
        QStringLiteral("message"),
        QStringLiteral("正在安全保存到系统密钥环")
    );
    return result;
}

QVariantMap WeatherMapProvider::clearApiKey()
{
    QVariantMap result {
        { QStringLiteral("ok"), false },
        { QStringLiteral("pending"), false }
    };

    if (m_credentialBusy) {
        result.insert(
            QStringLiteral("message"),
            QStringLiteral("系统密钥环正在处理另一项操作")
        );
        return result;
    }

    auto *job = new QKeychain::DeletePasswordJob(
        QString::fromLatin1(kKeychainService),
        this
    );
    job->setKey(QString::fromLatin1(kKeychainEntry));
    job->setInsecureFallback(false);
    connect(
        job,
        &QKeychain::Job::finished,
        this,
        [this](QKeychain::Job *finishedJob) {
            if (finishedJob->error() != QKeychain::NoError
                && finishedJob->error() != QKeychain::EntryNotFound) {
                finishCredentialOperation();
                emit credentialOperationFinished(
                    QStringLiteral("clear"),
                    false,
                    QStringLiteral("无法从系统密钥环清除密钥")
                );
                return;
            }

            setCredentialsReady(true);
            setStatus(
                QStringLiteral("not_configured"),
                QStringLiteral("地图服务未配置")
            );
            replaceApiKey({}, true);
            finishCredentialOperation();
            emit credentialOperationFinished(
                QStringLiteral("clear"),
                true,
                QStringLiteral("已从系统密钥环清除密钥")
            );
        }
    );
    setCredentialBusy(true);
    job->start();

    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("pending"), true);
    result.insert(
        QStringLiteral("message"),
        QStringLiteral("正在从系统密钥环清除密钥")
    );
    return result;
}

void WeatherMapProvider::reloadCredentials()
{
    if (m_credentialBusy) {
        m_reloadCredentialsPending = true;
        return;
    }
    loadApiKey(true);
}

int WeatherMapProvider::wrappedX(int x, int zoom)
{
    const int count = 1 << zoom;
    return ((x % count) + count) % count;
}

bool WeatherMapProvider::validTileCoordinate(int zoom, int y)
{
    if (zoom < 0 || zoom > 20)
        return false;
    const int count = 1 << zoom;
    return y >= 0 && y < count;
}

QString WeatherMapProvider::normalizedLayer(const QString &layer)
{
    static const QSet<QString> allowed {
        QStringLiteral("temp_new"),
        QStringLiteral("precipitation_new")
    };
    return allowed.contains(layer) ? layer : QString();
}

QString WeatherMapProvider::normalizedGridKind(const QString &kind)
{
    return kind == QStringLiteral("aqi") ? kind : QString();
}

bool WeatherMapProvider::validApiKey(const QString &apiKey)
{
    if (apiKey.size() < 16 || apiKey.size() > 128)
        return false;
    for (const QChar character : apiKey) {
        const ushort value = character.unicode();
        if (value < 0x21 || value > 0x7e)
            return false;
    }
    return true;
}

QString WeatherMapProvider::tileCachePath(
    const QString &kind,
    const QString &layer,
    int zoom,
    int x,
    int y
) const
{
    if (kind == QStringLiteral("base")) {
        return QStringLiteral("%1/tiles/osm/%2/%3/%4.png")
            .arg(m_cacheRoot)
            .arg(zoom)
            .arg(x)
            .arg(y);
    }

    return QStringLiteral("%1/tiles/weather/%2/%3/%4/%5.png")
        .arg(m_cacheRoot, layer)
        .arg(zoom)
        .arg(x)
        .arg(y);
}

QString WeatherMapProvider::localFileUrl(const QString &path) const
{
    const QFileInfo info(path);
    QString url = QUrl::fromLocalFile(info.absoluteFilePath()).toString();
    if (info.exists())
        url += QStringLiteral("?v=%1").arg(info.lastModified().toMSecsSinceEpoch());
    return url;
}

QString WeatherMapProvider::taskKey(
    const QString &kind,
    const QString &layer,
    int zoom,
    int x,
    int y
) const
{
    return QStringLiteral("%1:%2:%3:%4:%5")
        .arg(kind, layer)
        .arg(zoom)
        .arg(x)
        .arg(y);
}

QUrl WeatherMapProvider::remoteTileUrl(
    const QString &kind,
    const QString &layer,
    int zoom,
    int x,
    int y
) const
{
    if (kind == QStringLiteral("base")) {
        return QUrl(QStringLiteral("%1/%2/%3/%4.png")
            .arg(QString::fromLatin1(kOsmTileHost))
            .arg(zoom)
            .arg(x)
            .arg(y));
    }

    QUrl url(QStringLiteral("%1/map/%2/%3/%4/%5.png")
        .arg(QString::fromLatin1(kOpenWeatherTileHost), layer)
        .arg(zoom)
        .arg(x)
        .arg(y));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("appid"), QString::fromUtf8(m_apiKey));
    url.setQuery(query);
    return url;
}

QString WeatherMapProvider::gridCachePath(
    const QString &kind,
    const QList<GridPoint> &points
) const
{
    QByteArray identity = kind.toUtf8();
    for (const GridPoint &point : points) {
        identity += '|';
        identity += QByteArray::number(point.latitude, 'f', 4);
        identity += ',';
        identity += QByteArray::number(point.longitude, 'f', 4);
    }
    const QByteArray digest = QCryptographicHash::hash(
        identity,
        QCryptographicHash::Sha256
    ).toHex();
    return QStringLiteral("%1/grids/%2/%3.json")
        .arg(m_cacheRoot, kind, QString::fromLatin1(digest));
}

QUrl WeatherMapProvider::remoteGridUrl(
    const QString &kind,
    const QList<GridPoint> &points
) const
{
    QUrl url(
        QString::fromLatin1(kOpenMeteoAirQualityHost)
        + QStringLiteral("/v1/air-quality")
    );
    QStringList latitudes;
    QStringList longitudes;
    latitudes.reserve(points.size());
    longitudes.reserve(points.size());
    for (const GridPoint &point : points) {
        latitudes.append(QString::number(point.latitude, 'f', 4));
        longitudes.append(QString::number(point.longitude, 'f', 4));
    }

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("latitude"), latitudes.join(','));
    query.addQueryItem(QStringLiteral("longitude"), longitudes.join(','));
    query.addQueryItem(QStringLiteral("timezone"), QStringLiteral("GMT"));
    query.addQueryItem(
        QStringLiteral("current"),
        QStringLiteral("us_aqi,pm2_5")
    );
    url.setQuery(query);
    return url;
}

QList<WeatherMapProvider::GridPoint>
WeatherMapProvider::normalizedGridPoints(const QVariantList &points) const
{
    QList<GridPoint> normalized;
    normalized.reserve(qMin(points.size(), 35));
    for (const QVariant &value : points) {
        if (normalized.size() >= 35)
            break;

        const QVariantMap point = value.toMap();
        bool latitudeOk = false;
        bool longitudeOk = false;
        const double latitude = point
            .value(QStringLiteral("latitude"))
            .toDouble(&latitudeOk);
        const double longitude = point
            .value(QStringLiteral("longitude"))
            .toDouble(&longitudeOk);
        if (!latitudeOk
            || !longitudeOk
            || !qIsFinite(latitude)
            || !qIsFinite(longitude)
            || latitude < -85.05112878
            || latitude > 85.05112878
            || longitude < -180.0
            || longitude > 180.0) {
            continue;
        }

        normalized.append({
            qRound64(latitude * 10000.0) / 10000.0,
            qRound64(longitude * 10000.0) / 10000.0
        });
    }
    return normalized;
}

bool WeatherMapProvider::cacheIsFresh(const TileTask &task) const
{
    const QFileInfo info(task.cachePath);
    if (!info.exists())
        return false;

    const QDateTime now = QDateTime::currentDateTimeUtc();
    if (!task.osm)
        return info.lastModified().toUTC().secsTo(now) < kWeatherTileTtlSeconds;

    const QVariantMap metadata = readMetadata(task.cachePath);
    const QDateTime expiresAt = QDateTime::fromString(
        metadata.value(QStringLiteral("expiresAt")).toString(),
        Qt::ISODate
    );
    if (expiresAt.isValid())
        return now < expiresAt;

    return info.lastModified().toUTC().secsTo(now) < kOsmFallbackTtlSeconds;
}

QVariantMap WeatherMapProvider::cacheResult(
    const TileTask &task,
    bool stale
) const
{
    QVariantMap result {
        {QStringLiteral("url"), localFileUrl(task.cachePath)},
        {QStringLiteral("state"), stale
            ? QStringLiteral("stale")
            : QStringLiteral("ready")},
        {QStringLiteral("cached"), true},
        {QStringLiteral("stale"), stale}
    };
    if (!task.osm) {
        result.insert(
            QStringLiteral("hasSignal"),
            cachedWeatherTileHasSignal(task)
        );
    }
    return result;
}

void WeatherMapProvider::enqueue(
    const TileTask &task,
    const TileSubscriber &subscriber
)
{
    QList<TileSubscriber> &subscribers = m_subscribers[task.key];
    bool duplicate = false;
    for (const TileSubscriber &existing : std::as_const(subscribers)) {
        if (existing.generation == subscriber.generation
            && existing.kind == subscriber.kind
            && existing.layer == subscriber.layer
            && existing.zoom == subscriber.zoom
            && existing.x == subscriber.x
            && existing.y == subscriber.y) {
            duplicate = true;
            break;
        }
    }
    if (!duplicate)
        subscribers.append(subscriber);

    if (!m_pendingKeys.contains(task.key)) {
        m_pendingKeys.insert(task.key);
        m_queue.enqueue(task);
    }
    setStatus(QStringLiteral("loading"));
    startQueuedRequests();
}

void WeatherMapProvider::enqueueGrid(
    const GridTask &task,
    const GridSubscriber &subscriber
)
{
    QList<GridSubscriber> &subscribers = m_gridSubscribers[task.key];
    bool duplicate = false;
    for (const GridSubscriber &existing : std::as_const(subscribers)) {
        if (existing.generation == subscriber.generation
            && existing.kind == subscriber.kind) {
            duplicate = true;
            break;
        }
    }
    if (!duplicate)
        subscribers.append(subscriber);

    if (!m_pendingKeys.contains(task.key)) {
        m_pendingKeys.insert(task.key);
        m_gridQueue.enqueue(task);
    }
    setStatus(QStringLiteral("loading"));
    startQueuedRequests();
}

void WeatherMapProvider::startQueuedRequests()
{
    while (m_active
        && m_inFlight.size() + m_gridInFlight.size()
            < kMaximumConcurrentRequests
        && (!m_gridQueue.isEmpty() || !m_queue.isEmpty())) {
        if (!m_gridQueue.isEmpty()) {
            const GridTask task = m_gridQueue.dequeue();
            if (!m_gridSubscribers.contains(task.key)) {
                m_pendingKeys.remove(task.key);
                continue;
            }

            QNetworkRequest request(task.remoteUrl);
            request.setHeader(
                QNetworkRequest::UserAgentHeader,
                QByteArray(kUserAgent)
            );
            request.setRawHeader("Accept", "application/json");
            request.setAttribute(
                QNetworkRequest::RedirectPolicyAttribute,
                QNetworkRequest::NoLessSafeRedirectPolicy
            );
            request.setTransferTimeout(15000);

            QNetworkReply *reply = m_network.get(request);
            m_gridInFlight.insert(reply, task);
            connect(reply, &QNetworkReply::finished, this, [this, reply]() {
                finishGridRequest(reply);
            });
            continue;
        }

        const TileTask task = m_queue.dequeue();
        if (!m_subscribers.contains(task.key)) {
            m_pendingKeys.remove(task.key);
            continue;
        }

        QNetworkRequest request(task.remoteUrl);
        request.setHeader(
            QNetworkRequest::UserAgentHeader,
            QByteArray(kUserAgent)
        );
        request.setRawHeader("Accept", "image/png,image/*;q=0.8");
        request.setAttribute(
            QNetworkRequest::RedirectPolicyAttribute,
            QNetworkRequest::NoLessSafeRedirectPolicy
        );
        request.setTransferTimeout(15000);

        if (task.osm && QFileInfo::exists(task.cachePath)) {
            const QVariantMap metadata = readMetadata(task.cachePath);
            const QByteArray etag = metadata
                .value(QStringLiteral("etag"))
                .toString()
                .toUtf8();
            const QByteArray modified = metadata
                .value(QStringLiteral("lastModified"))
                .toString()
                .toUtf8();
            if (!etag.isEmpty())
                request.setRawHeader("If-None-Match", etag);
            if (!modified.isEmpty())
                request.setRawHeader("If-Modified-Since", modified);
        }

        QNetworkReply *reply = m_network.get(request);
        m_inFlight.insert(reply, task);
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            finishRequest(reply);
        });
    }
    updateBusy();
}

void WeatherMapProvider::finishRequest(QNetworkReply *reply)
{
    if (!m_inFlight.contains(reply)) {
        reply->deleteLater();
        return;
    }

    const TileTask task = m_inFlight.take(reply);
    const int httpStatus = reply->attribute(
        QNetworkRequest::HttpStatusCodeAttribute
    ).toInt();
    const QByteArray body = reply->readAll();
    bool success = false;
    bool stale = false;
    QString errorCode;

    if (httpStatus == 304 && QFileInfo::exists(task.cachePath)) {
        writeMetadata(task.cachePath, reply, true);
        success = true;
    } else if (reply->error() == QNetworkReply::NoError
        && httpStatus >= 200
        && httpStatus < 300
        && responseIsImage(reply, body)
        && writeTileAtomically(task.cachePath, body)) {
        if (task.osm) {
            writeMetadata(task.cachePath, reply);
        } else {
            writeWeatherMetadata(
                task.cachePath,
                weatherTileHasSignal(task.layer, body)
            );
        }
        success = true;
    } else {
        stale = QFileInfo::exists(task.cachePath);
        if (httpStatus == 401) {
            errorCode = QStringLiteral("invalid_key");
            setStatus(
                QStringLiteral("invalid_key"),
                QStringLiteral("OpenWeather API key 无效或尚未激活")
            );
        } else if (httpStatus == 429) {
            errorCode = QStringLiteral("rate_limited");
            setStatus(
                QStringLiteral("rate_limited"),
                QStringLiteral("请求频率受限")
            );
        } else {
            errorCode = QStringLiteral("network_error");
            setStatus(
                QStringLiteral("network_error"),
                QStringLiteral("地图网络不可用，正在使用已有缓存")
            );
        }
    }

    if (success || stale)
        notifySuccess(task, stale);
    else
        notifyFailure(task, errorCode);

    m_pendingKeys.remove(task.key);
    m_subscribers.remove(task.key);
    reply->deleteLater();

    if (success && m_status == QStringLiteral("loading"))
        setStatus(QStringLiteral("ready"));

    startQueuedRequests();
    updateBusy();
}

void WeatherMapProvider::finishGridRequest(QNetworkReply *reply)
{
    if (!m_gridInFlight.contains(reply)) {
        reply->deleteLater();
        return;
    }

    const GridTask task = m_gridInFlight.take(reply);
    const int httpStatus = reply->attribute(
        QNetworkRequest::HttpStatusCodeAttribute
    ).toInt();
    const QByteArray body = reply->readAll();
    bool parsed = false;
    QVariantList samples;
    QString updatedAt;
    bool stale = false;
    QString errorCode;

    if (reply->error() == QNetworkReply::NoError
        && httpStatus >= 200
        && httpStatus < 300) {
        samples = parseGridResponse(task, body, &parsed);
    }

    if (parsed && !samples.isEmpty()) {
        updatedAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
        writeGridCache(task.cachePath, samples, updatedAt);
        notifyGridSuccess(task, samples, updatedAt, false);
        if (m_status == QStringLiteral("loading"))
            setStatus(QStringLiteral("ready"));
    } else {
        const QVariantMap cache = readGridCache(task.cachePath);
        samples = cache.value(QStringLiteral("samples")).toList();
        updatedAt = cache.value(QStringLiteral("updatedAt")).toString();
        stale = !samples.isEmpty();

        if (httpStatus == 429) {
            errorCode = QStringLiteral("rate_limited");
            setStatus(
                QStringLiteral("rate_limited"),
                QStringLiteral("请求频率受限")
            );
        } else if (parsed && samples.isEmpty()) {
            errorCode = QStringLiteral("empty_data");
            setStatus(
                QStringLiteral("empty_data"),
                QStringLiteral("区域模型暂无可用数据")
            );
        } else {
            errorCode = QStringLiteral("network_error");
            setStatus(
                QStringLiteral("network_error"),
                QStringLiteral("地图网络不可用，正在使用已有缓存")
            );
        }

        if (stale)
            notifyGridSuccess(task, samples, updatedAt, true);
        else
            notifyGridFailure(task, errorCode);
    }

    m_pendingKeys.remove(task.key);
    m_gridSubscribers.remove(task.key);
    reply->deleteLater();
    startQueuedRequests();
    updateBusy();
}

void WeatherMapProvider::notifyGridSuccess(
    const GridTask &task,
    const QVariantList &samples,
    const QString &updatedAt,
    bool stale
)
{
    if (!m_active)
        return;

    const QList<GridSubscriber> subscribers = m_gridSubscribers.value(task.key);
    for (const GridSubscriber &subscriber : subscribers) {
        if (subscriber.generation != m_generation)
            continue;
        emit gridReady(
            subscriber.kind,
            subscriber.generation,
            samples,
            updatedAt,
            stale
        );
    }
}

void WeatherMapProvider::notifyGridFailure(
    const GridTask &task,
    const QString &errorCode
)
{
    if (!m_active)
        return;

    const QList<GridSubscriber> subscribers = m_gridSubscribers.value(task.key);
    for (const GridSubscriber &subscriber : subscribers) {
        if (subscriber.generation != m_generation)
            continue;
        emit gridFailed(
            subscriber.kind,
            subscriber.generation,
            errorCode
        );
    }
}

void WeatherMapProvider::notifySuccess(const TileTask &task, bool stale)
{
    if (!m_active)
        return;

    const QString url = localFileUrl(task.cachePath);
    const QList<TileSubscriber> subscribers = m_subscribers.value(task.key);
    for (const TileSubscriber &subscriber : subscribers) {
        if (subscriber.generation != m_generation)
            continue;
        emit tileReady(
            subscriber.kind,
            subscriber.layer,
            subscriber.zoom,
            subscriber.x,
            subscriber.y,
            subscriber.generation,
            url,
            stale
        );
        if (subscriber.kind == QStringLiteral("weather")) {
            emit tileActivity(
                subscriber.layer,
                subscriber.zoom,
                subscriber.x,
                subscriber.y,
                subscriber.generation,
                cachedWeatherTileHasSignal(task)
            );
        }
    }
}

void WeatherMapProvider::notifyFailure(
    const TileTask &task,
    const QString &errorCode
)
{
    if (!m_active)
        return;

    const QList<TileSubscriber> subscribers = m_subscribers.value(task.key);
    for (const TileSubscriber &subscriber : subscribers) {
        if (subscriber.generation != m_generation)
            continue;
        emit tileFailed(
            subscriber.kind,
            subscriber.layer,
            subscriber.zoom,
            subscriber.x,
            subscriber.y,
            subscriber.generation,
            errorCode
        );
    }
}

void WeatherMapProvider::pruneObsoleteQueue()
{
    QQueue<TileTask> current;
    while (!m_queue.isEmpty()) {
        const TileTask task = m_queue.dequeue();
        if (m_subscribers.contains(task.key))
            current.enqueue(task);
        else
            m_pendingKeys.remove(task.key);
    }
    m_queue = current;

    QQueue<GridTask> currentGrids;
    while (!m_gridQueue.isEmpty()) {
        const GridTask task = m_gridQueue.dequeue();
        if (m_gridSubscribers.contains(task.key))
            currentGrids.enqueue(task);
        else
            m_pendingKeys.remove(task.key);
    }
    m_gridQueue = currentGrids;
    updateBusy();
}

void WeatherMapProvider::loadApiKey(bool forceRefresh)
{
    auto *job = new QKeychain::ReadPasswordJob(
        QString::fromLatin1(kKeychainService),
        this
    );
    job->setKey(QString::fromLatin1(kKeychainEntry));
    job->setInsecureFallback(false);
    connect(
        job,
        &QKeychain::Job::finished,
        this,
        [this, forceRefresh](QKeychain::Job *finishedJob) {
            const auto *readJob = static_cast<QKeychain::ReadPasswordJob *>(
                finishedJob
            );
            setCredentialsReady(true);

            if (finishedJob->error() == QKeychain::EntryNotFound) {
                replaceApiKey({}, forceRefresh);
                setStatus(
                    QStringLiteral("not_configured"),
                    QStringLiteral("地图服务未配置")
                );
                finishCredentialOperation();
                return;
            }

            if (finishedJob->error() != QKeychain::NoError) {
                replaceApiKey({}, forceRefresh);
                setStatus(
                    QStringLiteral("keychain_error"),
                    QStringLiteral("无法访问系统密钥环")
                );
                finishCredentialOperation();
                return;
            }

            const QString storedKey = readJob->textData().trimmed();
            if (!validApiKey(storedKey)) {
                replaceApiKey({}, forceRefresh);
                setStatus(
                    QStringLiteral("not_configured"),
                    QStringLiteral("地图服务未配置")
                );
                finishCredentialOperation();
                return;
            }

            setStatus(QStringLiteral("idle"));
            replaceApiKey(storedKey.toUtf8(), forceRefresh);
            finishCredentialOperation();
        }
    );
    setCredentialBusy(true);
    job->start();
}

void WeatherMapProvider::finishCredentialOperation()
{
    setCredentialBusy(false);
    if (!m_reloadCredentialsPending)
        return;

    m_reloadCredentialsPending = false;
    loadApiKey(true);
}

void WeatherMapProvider::replaceApiKey(
    const QByteArray &apiKey,
    bool forceRefresh
)
{
    if (m_apiKey == apiKey && !forceRefresh)
        return;

    const bool wasConfigured = apiConfigured();
    m_apiKey = apiKey;
    cancelWeatherRequests();
    if (wasConfigured != apiConfigured())
        emit apiConfiguredChanged();
    emit apiKeyChanged();
}

void WeatherMapProvider::cancelWeatherRequests()
{
    QQueue<TileTask> retainedQueue;
    while (!m_queue.isEmpty()) {
        const TileTask task = m_queue.dequeue();
        if (task.osm) {
            retainedQueue.enqueue(task);
            continue;
        }
        m_pendingKeys.remove(task.key);
        m_subscribers.remove(task.key);
    }
    m_queue = retainedQueue;

    for (auto iterator = m_inFlight.begin(); iterator != m_inFlight.end();) {
        if (iterator.value().osm) {
            ++iterator;
            continue;
        }

        QNetworkReply *reply = iterator.key();
        const TileTask task = iterator.value();
        iterator = m_inFlight.erase(iterator);
        m_pendingKeys.remove(task.key);
        m_subscribers.remove(task.key);
        QObject::disconnect(reply, nullptr, this, nullptr);
        reply->abort();
        reply->deleteLater();
    }
    updateBusy();
    startQueuedRequests();
}

void WeatherMapProvider::setCredentialsReady(bool ready)
{
    if (m_credentialsReady == ready)
        return;
    m_credentialsReady = ready;
    emit credentialsReadyChanged();
}

void WeatherMapProvider::setCredentialBusy(bool busy)
{
    if (m_credentialBusy == busy)
        return;
    m_credentialBusy = busy;
    emit credentialBusyChanged();
}

void WeatherMapProvider::updateBusy()
{
    const bool nextBusy = !m_queue.isEmpty()
        || !m_inFlight.isEmpty()
        || !m_gridQueue.isEmpty()
        || !m_gridInFlight.isEmpty();
    if (m_busy == nextBusy)
        return;
    m_busy = nextBusy;
    emit busyChanged();
}

void WeatherMapProvider::setStatus(
    const QString &status,
    const QString &message
)
{
    if (m_status == status && m_errorMessage == message)
        return;
    m_status = status;
    m_errorMessage = message;
    emit statusChanged();
}

QVariantMap WeatherMapProvider::readMetadata(const QString &cachePath) const
{
    QFile file(cachePath + QStringLiteral(".json"));
    if (!file.open(QIODevice::ReadOnly))
        return {};

    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    return document.isObject()
        ? document.object().toVariantMap()
        : QVariantMap();
}

void WeatherMapProvider::writeMetadata(
    const QString &cachePath,
    QNetworkReply *reply,
    bool keepExistingValidators
)
{
    QVariantMap metadata = keepExistingValidators
        ? readMetadata(cachePath)
        : QVariantMap();

    const QByteArray cacheControl = reply->rawHeader("Cache-Control");
    const qint64 maxAge = cacheControlMaxAge(cacheControl);
    QDateTime expiresAt;
    if (maxAge >= 0) {
        expiresAt = QDateTime::currentDateTimeUtc().addSecs(maxAge);
    } else {
        expiresAt = QDateTime::fromString(
            QString::fromLatin1(reply->rawHeader("Expires")),
            Qt::RFC2822Date
        ).toUTC();
    }
    if (!expiresAt.isValid()) {
        expiresAt = QDateTime::currentDateTimeUtc().addSecs(
            kOsmFallbackTtlSeconds
        );
    }

    metadata.insert(
        QStringLiteral("expiresAt"),
        expiresAt.toString(Qt::ISODate)
    );
    const QByteArray etag = reply->rawHeader("ETag");
    const QByteArray modified = reply->rawHeader("Last-Modified");
    if (!etag.isEmpty())
        metadata.insert(QStringLiteral("etag"), QString::fromLatin1(etag));
    if (!modified.isEmpty()) {
        metadata.insert(
            QStringLiteral("lastModified"),
            QString::fromLatin1(modified)
        );
    }

    QSaveFile file(cachePath + QStringLiteral(".json"));
    QDir().mkpath(QFileInfo(file.fileName()).absolutePath());
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument::fromVariant(metadata).toJson(
        QJsonDocument::Compact
    ));
    file.commit();
}

bool WeatherMapProvider::writeTileAtomically(
    const QString &path,
    const QByteArray &body
) const
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    if (file.write(body) != body.size()) {
        file.cancelWriting();
        return false;
    }
    return file.commit();
}

bool WeatherMapProvider::responseIsImage(
    QNetworkReply *reply,
    const QByteArray &body
) const
{
    const QByteArray contentType = reply->header(
        QNetworkRequest::ContentTypeHeader
    ).toByteArray().toLower();
    if (!contentType.isEmpty() && !contentType.startsWith("image/"))
        return false;

    QBuffer buffer;
    buffer.setData(body);
    if (!buffer.open(QIODevice::ReadOnly))
        return false;
    QImageReader reader(&buffer);
    return reader.canRead();
}

bool WeatherMapProvider::weatherTileHasSignal(
    const QString &layer,
    const QByteArray &body
) const
{
    if (layer != QStringLiteral("precipitation_new"))
        return true;

    const QImage image = QImage::fromData(body);
    if (image.isNull())
        return true;

    int sampled = 0;
    int activePixels = 0;
    for (int y = 2; y < image.height(); y += 4) {
        for (int x = 2; x < image.width(); x += 4) {
            ++sampled;
            if (qAlpha(image.pixel(x, y)) >= 26)
                ++activePixels;
        }
    }
    return activePixels >= qMax(8, sampled / 200);
}

bool WeatherMapProvider::cachedWeatherTileHasSignal(
    const TileTask &task
) const
{
    if (task.layer != QStringLiteral("precipitation_new"))
        return true;

    const QVariantMap metadata = readMetadata(task.cachePath);
    if (metadata.contains(QStringLiteral("hasSignal"))) {
        return metadata.value(QStringLiteral("hasSignal")).toBool();
    }

    QFile file(task.cachePath);
    if (!file.open(QIODevice::ReadOnly))
        return true;
    return weatherTileHasSignal(task.layer, file.readAll());
}

void WeatherMapProvider::writeWeatherMetadata(
    const QString &cachePath,
    bool hasSignal
) const
{
    const QVariantMap metadata {
        {QStringLiteral("hasSignal"), hasSignal}
    };
    QSaveFile file(cachePath + QStringLiteral(".json"));
    QDir().mkpath(QFileInfo(file.fileName()).absolutePath());
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(
        QJsonDocument::fromVariant(metadata).toJson(QJsonDocument::Compact)
    );
    file.commit();
}

QVariantMap WeatherMapProvider::readGridCache(const QString &path) const
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};

    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    return document.isObject()
        ? document.object().toVariantMap()
        : QVariantMap();
}

bool WeatherMapProvider::writeGridCache(
    const QString &path,
    const QVariantList &samples,
    const QString &updatedAt
) const
{
    QVariantMap cache;
    cache.insert(QStringLiteral("samples"), samples);
    cache.insert(QStringLiteral("updatedAt"), updatedAt);

    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(
        QJsonDocument::fromVariant(cache).toJson(QJsonDocument::Compact)
    );
    return file.commit();
}

bool WeatherMapProvider::gridCacheIsFresh(const GridTask &task) const
{
    const QFileInfo info(task.cachePath);
    if (!info.exists())
        return false;

    return info.lastModified()
        .toUTC()
        .secsTo(QDateTime::currentDateTimeUtc())
        < kAirQualityGridTtlSeconds;
}

QVariantList WeatherMapProvider::parseGridResponse(
    const GridTask &task,
    const QByteArray &body,
    bool *ok
) const
{
    if (ok)
        *ok = false;

    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(body, &error);
    if (error.error != QJsonParseError::NoError)
        return {};

    QJsonArray locations;
    if (document.isArray()) {
        locations = document.array();
    } else if (document.isObject()) {
        locations.append(document.object());
    } else {
        return {};
    }

    if (ok)
        *ok = true;

    QVariantList samples;
    const int count = qMin(locations.size(), task.points.size());
    samples.reserve(count);
    for (int index = 0; index < count; ++index) {
        const QJsonObject current = locations
            .at(index)
            .toObject()
            .value(QStringLiteral("current"))
            .toObject();
        QVariantMap sample;
        sample.insert(
            QStringLiteral("latitude"),
            task.points.at(index).latitude
        );
        sample.insert(
            QStringLiteral("longitude"),
            task.points.at(index).longitude
        );

        const double aqi = current
            .value(QStringLiteral("us_aqi"))
            .toDouble(qQNaN());
        const double pm25 = current
            .value(QStringLiteral("pm2_5"))
            .toDouble(qQNaN());
        if (!qIsFinite(aqi))
            continue;
        sample.insert(QStringLiteral("aqi"), aqi);
        if (qIsFinite(pm25))
            sample.insert(QStringLiteral("pm25"), pm25);
        samples.append(sample);
    }
    return samples;
}
