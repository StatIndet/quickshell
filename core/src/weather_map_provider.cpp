#include "weather_map_provider.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QHash>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <qt6keychain/keychain.h>

namespace {
constexpr auto kKeychainService = "Clavis.Quickshell.WeatherMap";
constexpr auto kOpenWeatherKeychainEntry = "openweather-api-key";
constexpr auto kMapTilerKeychainEntry = "maptiler-api-key";
constexpr auto kRadarMetadataUrl = "https://api.rainviewer.com/public/weather-maps.json";
constexpr auto kUserAgent = "ClavisWeatherMap/2.0 (MapLibre Native Qt)";
constexpr int kRadarRefreshIntervalMs = 10 * 60 * 1000;
} // namespace

WeatherMapProvider::WeatherMapProvider(QObject *parent) : QObject(parent)
{
    m_radarRefreshTimer.setInterval(kRadarRefreshIntervalMs);
    m_radarRefreshTimer.setSingleShot(false);
    connect(&m_radarRefreshTimer, &QTimer::timeout, this, &WeatherMapProvider::refreshRadarMetadata);
    loadCredentials();
}

bool WeatherMapProvider::active() const { return m_active; }

void WeatherMapProvider::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    if (m_active) {
        refreshRadarMetadata();
        m_radarRefreshTimer.start();
    } else {
        m_radarRefreshTimer.stop();
        if (m_radarReply) {
            disconnect(m_radarReply, nullptr, this, nullptr);
            m_radarReply->abort();
            m_radarReply->deleteLater();
            m_radarReply = nullptr;
            emit busyChanged();
        }
        for (QNetworkReply **reply : {&m_mapTilerValidationReply, &m_openWeatherValidationReply}) {
            if (!*reply)
                continue;
            disconnect(*reply, nullptr, this, nullptr);
            (*reply)->abort();
            (*reply)->deleteLater();
            *reply = nullptr;
            emit busyChanged();
        }
    }
    emit activeChanged();
}

bool WeatherMapProvider::apiConfigured() const { return !m_apiKey.isEmpty(); }
bool WeatherMapProvider::mapTilerConfigured() const { return !m_mapTilerApiKey.isEmpty(); }
bool WeatherMapProvider::credentialsReady() const { return m_credentialsReady; }
bool WeatherMapProvider::credentialBusy() const { return m_credentialBusy; }
bool WeatherMapProvider::busy() const
{
    return m_credentialBusy || m_radarReply || m_mapTilerValidationReply || m_openWeatherValidationReply;
}
QString WeatherMapProvider::status() const { return m_status; }
QString WeatherMapProvider::errorMessage() const { return m_errorMessage; }
QString WeatherMapProvider::mapTilerStatus() const { return m_mapTilerStatus; }
QString WeatherMapProvider::radarStatus() const { return m_radarStatus; }
QString WeatherMapProvider::radarErrorMessage() const { return m_radarErrorMessage; }
QString WeatherMapProvider::radarTileUrl() const { return m_radarTileUrl; }
qint64 WeatherMapProvider::radarFrameTime() const { return m_radarFrameTime; }

bool WeatherMapProvider::validApiKey(const QString &apiKey)
{
    const QString value = apiKey.trimmed();
    if (value.size() < 16 || value.size() > 128)
        return false;
    for (const QChar character : value) {
        if (!character.isLetterOrNumber() && character != QLatin1Char('-') && character != QLatin1Char('_'))
            return false;
    }
    return true;
}

QString WeatherMapProvider::openWeatherLayerName(const QString &layerId)
{
    static const QHash<QString, QString> layers{
        {QStringLiteral("temperature"), QStringLiteral("temp_new")},
        {QStringLiteral("precipitation"), QStringLiteral("precipitation_new")},
        {QStringLiteral("clouds"), QStringLiteral("clouds_new")},
        {QStringLiteral("wind"), QStringLiteral("wind_new")},
        {QStringLiteral("pressure"), QStringLiteral("pressure_new")},
    };
    return layers.value(layerId);
}

QString WeatherMapProvider::mapTilerStyleUrl(const QString &styleId) const
{
    if (m_mapTilerApiKey.isEmpty())
        return {};
    const QString style = styleId == QStringLiteral("dataviz-dark") ? QStringLiteral("dataviz-dark")
                                                                    : QStringLiteral("dataviz");
    QUrl url(QStringLiteral("https://api.maptiler.com/maps/%1/style.json").arg(style));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("key"), QString::fromUtf8(m_mapTilerApiKey));
    url.setQuery(query);
    return url.toString(QUrl::FullyEncoded);
}

QString WeatherMapProvider::openWeatherTileUrl(const QString &layerId) const
{
    const QString layer = openWeatherLayerName(layerId);
    if (m_apiKey.isEmpty() || layer.isEmpty())
        return {};
    QUrl url(QStringLiteral("https://tile.openweathermap.org/map/%1/{z}/{x}/{y}.png").arg(layer));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("appid"), QString::fromUtf8(m_apiKey));
    url.setQuery(query);
    QString tileTemplate = url.toString(QUrl::FullyEncoded);
    tileTemplate.replace(QStringLiteral("%7Bz%7D"), QStringLiteral("{z}"));
    tileTemplate.replace(QStringLiteral("%7Bx%7D"), QStringLiteral("{x}"));
    tileTemplate.replace(QStringLiteral("%7By%7D"), QStringLiteral("{y}"));
    return tileTemplate;
}

void WeatherMapProvider::validateMapTilerStyle(const QString &styleId)
{
    if (!m_active || m_mapTilerApiKey.isEmpty() || m_mapTilerValidationReply)
        return;
    const QUrl url(mapTilerStyleUrl(styleId));
    if (!url.isValid())
        return;

    setMapTilerStatus(QStringLiteral("loading"));
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QString::fromLatin1(kUserAgent));
    m_mapTilerValidationReply = m_network.get(request);
    emit busyChanged();
    connect(m_mapTilerValidationReply, &QNetworkReply::finished, this, [this] {
        QNetworkReply *reply = m_mapTilerValidationReply;
        m_mapTilerValidationReply = nullptr;
        emit busyChanged();
        if (!reply)
            return;

        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const bool networkFailure =
            reply->error() != QNetworkReply::NoError || statusCode < 200 || statusCode >= 300;
        reply->deleteLater();
        if (networkFailure) {
            if (statusCode == 401 || statusCode == 403)
                setMapTilerStatus(QStringLiteral("invalid_key"));
            else if (statusCode == 429)
                setMapTilerStatus(QStringLiteral("rate_limited"));
            else
                setMapTilerStatus(QStringLiteral("network_error"));
            return;
        }

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
        setMapTilerStatus(parseError.error == QJsonParseError::NoError && document.isObject()
                              ? QStringLiteral("ready")
                              : QStringLiteral("invalid_response"));
    });
}

void WeatherMapProvider::validateOpenWeatherLayer(const QString &layerId)
{
    if (!m_active || m_apiKey.isEmpty() || m_openWeatherValidationReply)
        return;
    QString tileUrl = openWeatherTileUrl(layerId);
    tileUrl.replace(QStringLiteral("{z}"), QStringLiteral("0"));
    tileUrl.replace(QStringLiteral("{x}"), QStringLiteral("0"));
    tileUrl.replace(QStringLiteral("{y}"), QStringLiteral("0"));
    const QUrl url(tileUrl);
    if (!url.isValid())
        return;

    setStatus(QStringLiteral("loading"));
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QString::fromLatin1(kUserAgent));
    m_openWeatherValidationReply = m_network.get(request);
    emit busyChanged();
    connect(m_openWeatherValidationReply, &QNetworkReply::finished, this, [this] {
        QNetworkReply *reply = m_openWeatherValidationReply;
        m_openWeatherValidationReply = nullptr;
        emit busyChanged();
        if (!reply)
            return;

        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const bool networkFailure =
            reply->error() != QNetworkReply::NoError || statusCode < 200 || statusCode >= 300;
        reply->deleteLater();
        if (networkFailure) {
            if (statusCode == 401 || statusCode == 403)
                setStatus(QStringLiteral("invalid_key"), QStringLiteral("OpenWeather 密钥无效"));
            else if (statusCode == 429)
                setStatus(QStringLiteral("rate_limited"), QStringLiteral("OpenWeather 请求过于频繁"));
            else
                setStatus(QStringLiteral("network_error"), QStringLiteral("OpenWeather 暂时不可用"));
            return;
        }

        if (!body.startsWith("\x89PNG") && !body.startsWith("\xff\xd8")) {
            setStatus(QStringLiteral("invalid_response"), QStringLiteral("OpenWeather 返回了无效图层"));
            return;
        }
        setStatus(QStringLiteral("ready"));
    });
}

void WeatherMapProvider::refreshRadarMetadata()
{
    if (!m_active || m_radarReply)
        return;
    setRadarStatus(QStringLiteral("loading"));
    QNetworkRequest request(QUrl(QString::fromLatin1(kRadarMetadataUrl)));
    request.setHeader(QNetworkRequest::UserAgentHeader, QString::fromLatin1(kUserAgent));
    m_radarReply = m_network.get(request);
    emit busyChanged();
    connect(m_radarReply, &QNetworkReply::finished, this, [this] {
        QNetworkReply *reply = m_radarReply;
        m_radarReply = nullptr;
        emit busyChanged();
        if (!reply)
            return;

        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const bool networkFailure =
            reply->error() != QNetworkReply::NoError || statusCode < 200 || statusCode >= 300;
        reply->deleteLater();
        if (networkFailure) {
            setRadarStatus(statusCode == 429 ? QStringLiteral("rate_limited")
                                             : QStringLiteral("network_error"),
                           QStringLiteral("天气图层暂时不可用"));
            return;
        }

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
        const QJsonObject root = document.object();
        const QJsonArray past =
            root.value(QStringLiteral("radar")).toObject().value(QStringLiteral("past")).toArray();
        const QString host = root.value(QStringLiteral("host")).toString();
        if (parseError.error != QJsonParseError::NoError || host.isEmpty() || past.isEmpty()) {
            setRadarStatus(QStringLiteral("invalid_response"), QStringLiteral("天气图层暂时不可用"));
            return;
        }

        const QJsonObject frame = past.last().toObject();
        const QString path = frame.value(QStringLiteral("path")).toString();
        const qint64 frameTime = frame.value(QStringLiteral("time")).toInteger();
        if (!path.startsWith(QLatin1Char('/')) || frameTime <= 0) {
            setRadarStatus(QStringLiteral("invalid_response"), QStringLiteral("天气图层暂时不可用"));
            return;
        }

        const QString tileUrl = host + path + QStringLiteral("/256/{z}/{x}/{y}/2/1_1.png");
        const bool frameChanged = m_radarTileUrl != tileUrl || m_radarFrameTime != frameTime;
        m_radarTileUrl = tileUrl;
        m_radarFrameTime = frameTime;
        setRadarStatus(QStringLiteral("ready"));
        if (frameChanged)
            emit radarFrameChanged();
    });
}

QVariantMap WeatherMapProvider::storeApiKey(const QString &apiKey)
{
    QVariantMap result{{QStringLiteral("ok"), false}, {QStringLiteral("pending"), false}};
    const QString normalized = apiKey.trimmed();
    if (!validApiKey(normalized)) {
        result.insert(QStringLiteral("message"), QStringLiteral("请输入有效的 OpenWeather API key"));
        return result;
    }
    if (m_credentialBusy) {
        result.insert(QStringLiteral("message"), QStringLiteral("系统密钥环正在处理另一项操作"));
        return result;
    }
    auto *job = new QKeychain::WritePasswordJob(QString::fromLatin1(kKeychainService), this);
    job->setKey(QString::fromLatin1(kOpenWeatherKeychainEntry));
    job->setTextData(normalized);
    job->setInsecureFallback(false);
    connect(job, &QKeychain::Job::finished, this, [this, normalized](QKeychain::Job *finishedJob) {
        const bool success = finishedJob->error() == QKeychain::NoError;
        if (success) {
            replaceApiKey(normalized.toUtf8());
            setCredentialsReady(true);
            setStatus(QStringLiteral("ready"));
        }
        finishCredentialOperation();
        emit credentialOperationFinished(QStringLiteral("openweather_store"), success,
                                         success ? QStringLiteral("OpenWeather 密钥已保存")
                                                 : QStringLiteral("无法保存 OpenWeather 密钥"));
    });
    setCredentialBusy(true);
    job->start();
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("pending"), true);
    result.insert(QStringLiteral("message"), QStringLiteral("正在安全保存到系统密钥环"));
    return result;
}

QVariantMap WeatherMapProvider::clearApiKey()
{
    QVariantMap result{{QStringLiteral("ok"), false}, {QStringLiteral("pending"), false}};
    if (m_credentialBusy) {
        result.insert(QStringLiteral("message"), QStringLiteral("系统密钥环正在处理另一项操作"));
        return result;
    }
    auto *job = new QKeychain::DeletePasswordJob(QString::fromLatin1(kKeychainService), this);
    job->setKey(QString::fromLatin1(kOpenWeatherKeychainEntry));
    job->setInsecureFallback(false);
    connect(job, &QKeychain::Job::finished, this, [this](QKeychain::Job *finishedJob) {
        const bool success =
            finishedJob->error() == QKeychain::NoError || finishedJob->error() == QKeychain::EntryNotFound;
        if (success) {
            replaceApiKey({});
            setStatus(QStringLiteral("not_configured"));
        }
        finishCredentialOperation();
        emit credentialOperationFinished(QStringLiteral("openweather_clear"), success,
                                         success ? QStringLiteral("OpenWeather 密钥已清除")
                                                 : QStringLiteral("无法清除 OpenWeather 密钥"));
    });
    setCredentialBusy(true);
    job->start();
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("pending"), true);
    result.insert(QStringLiteral("message"), QStringLiteral("正在从系统密钥环清除密钥"));
    return result;
}

QVariantMap WeatherMapProvider::storeMapTilerApiKey(const QString &apiKey)
{
    QVariantMap result{{QStringLiteral("ok"), false}, {QStringLiteral("pending"), false}};
    const QString normalized = apiKey.trimmed();
    if (!validApiKey(normalized)) {
        result.insert(QStringLiteral("message"), QStringLiteral("请输入有效的 MapTiler API key"));
        return result;
    }
    if (m_credentialBusy) {
        result.insert(QStringLiteral("message"), QStringLiteral("系统密钥环正在处理另一项操作"));
        return result;
    }
    auto *job = new QKeychain::WritePasswordJob(QString::fromLatin1(kKeychainService), this);
    job->setKey(QString::fromLatin1(kMapTilerKeychainEntry));
    job->setTextData(normalized);
    job->setInsecureFallback(false);
    connect(job, &QKeychain::Job::finished, this, [this, normalized](QKeychain::Job *finishedJob) {
        const bool success = finishedJob->error() == QKeychain::NoError;
        if (success) {
            replaceMapTilerApiKey(normalized.toUtf8());
            setCredentialsReady(true);
            setMapTilerStatus(QStringLiteral("ready"));
        } else {
            setMapTilerStatus(QStringLiteral("keychain_error"));
        }
        finishCredentialOperation();
        emit credentialOperationFinished(QStringLiteral("maptiler_store"), success,
                                         success ? QStringLiteral("MapTiler 密钥已保存")
                                                 : QStringLiteral("无法保存 MapTiler 密钥"));
    });
    setCredentialBusy(true);
    job->start();
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("pending"), true);
    result.insert(QStringLiteral("message"), QStringLiteral("正在安全保存到系统密钥环"));
    return result;
}

QVariantMap WeatherMapProvider::clearMapTilerApiKey()
{
    QVariantMap result{{QStringLiteral("ok"), false}, {QStringLiteral("pending"), false}};
    if (m_credentialBusy) {
        result.insert(QStringLiteral("message"), QStringLiteral("系统密钥环正在处理另一项操作"));
        return result;
    }
    auto *job = new QKeychain::DeletePasswordJob(QString::fromLatin1(kKeychainService), this);
    job->setKey(QString::fromLatin1(kMapTilerKeychainEntry));
    job->setInsecureFallback(false);
    connect(job, &QKeychain::Job::finished, this, [this](QKeychain::Job *finishedJob) {
        const bool success =
            finishedJob->error() == QKeychain::NoError || finishedJob->error() == QKeychain::EntryNotFound;
        if (success) {
            replaceMapTilerApiKey({});
            setMapTilerStatus(QStringLiteral("not_configured"));
        } else {
            setMapTilerStatus(QStringLiteral("keychain_error"));
        }
        finishCredentialOperation();
        emit credentialOperationFinished(QStringLiteral("maptiler_clear"), success,
                                         success ? QStringLiteral("MapTiler 密钥已清除")
                                                 : QStringLiteral("无法清除 MapTiler 密钥"));
    });
    setCredentialBusy(true);
    job->start();
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("pending"), true);
    result.insert(QStringLiteral("message"), QStringLiteral("正在从系统密钥环清除密钥"));
    return result;
}

void WeatherMapProvider::reloadCredentials()
{
    if (m_credentialBusy) {
        m_reloadCredentialsPending = true;
        return;
    }
    loadCredentials();
}

void WeatherMapProvider::loadCredentials()
{
    setCredentialsReady(false);
    setCredentialBusy(true);
    setStatus(QStringLiteral("loading_credentials"));
    setMapTilerStatus(QStringLiteral("loading_credentials"));
    loadOpenWeatherApiKey();
}

void WeatherMapProvider::loadOpenWeatherApiKey()
{
    auto *job = new QKeychain::ReadPasswordJob(QString::fromLatin1(kKeychainService), this);
    job->setKey(QString::fromLatin1(kOpenWeatherKeychainEntry));
    job->setInsecureFallback(false);
    connect(job, &QKeychain::Job::finished, this, [this](QKeychain::Job *finishedJob) {
        const auto *readJob = static_cast<QKeychain::ReadPasswordJob *>(finishedJob);
        if (finishedJob->error() == QKeychain::NoError && validApiKey(readJob->textData())) {
            replaceApiKey(readJob->textData().trimmed().toUtf8());
            setStatus(QStringLiteral("ready"));
        } else {
            replaceApiKey({});
            setStatus(finishedJob->error() == QKeychain::EntryNotFound ? QStringLiteral("not_configured")
                                                                       : QStringLiteral("keychain_error"));
        }
        loadMapTilerApiKey();
    });
    job->start();
}

void WeatherMapProvider::loadMapTilerApiKey()
{
    auto *job = new QKeychain::ReadPasswordJob(QString::fromLatin1(kKeychainService), this);
    job->setKey(QString::fromLatin1(kMapTilerKeychainEntry));
    job->setInsecureFallback(false);
    connect(job, &QKeychain::Job::finished, this, [this](QKeychain::Job *finishedJob) {
        const auto *readJob = static_cast<QKeychain::ReadPasswordJob *>(finishedJob);
        if (finishedJob->error() == QKeychain::NoError && validApiKey(readJob->textData())) {
            replaceMapTilerApiKey(readJob->textData().trimmed().toUtf8());
            setMapTilerStatus(QStringLiteral("ready"));
        } else {
            replaceMapTilerApiKey({});
            setMapTilerStatus(finishedJob->error() == QKeychain::EntryNotFound
                                  ? QStringLiteral("not_configured")
                                  : QStringLiteral("keychain_error"));
        }
        setCredentialsReady(true);
        finishCredentialOperation();
    });
    job->start();
}

void WeatherMapProvider::finishCredentialOperation()
{
    setCredentialBusy(false);
    if (!m_reloadCredentialsPending)
        return;
    m_reloadCredentialsPending = false;
    loadCredentials();
}

void WeatherMapProvider::replaceApiKey(const QByteArray &apiKey)
{
    if (m_apiKey == apiKey)
        return;
    const bool wasConfigured = apiConfigured();
    m_apiKey = apiKey;
    if (wasConfigured != apiConfigured())
        emit apiConfiguredChanged();
    emit apiKeyChanged();
}

void WeatherMapProvider::replaceMapTilerApiKey(const QByteArray &apiKey)
{
    if (m_mapTilerApiKey == apiKey)
        return;
    const bool wasConfigured = mapTilerConfigured();
    m_mapTilerApiKey = apiKey;
    if (wasConfigured != mapTilerConfigured())
        emit mapTilerConfiguredChanged();
    emit mapTilerApiKeyChanged();
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
    emit busyChanged();
}

void WeatherMapProvider::setMapTilerStatus(const QString &status)
{
    if (m_mapTilerStatus == status)
        return;
    m_mapTilerStatus = status;
    emit mapTilerStatusChanged();
}

void WeatherMapProvider::setStatus(const QString &status, const QString &message)
{
    if (m_status == status && m_errorMessage == message)
        return;
    m_status = status;
    m_errorMessage = message;
    emit statusChanged();
}

void WeatherMapProvider::setRadarStatus(const QString &status, const QString &message)
{
    if (m_radarStatus == status && m_radarErrorMessage == message)
        return;
    m_radarStatus = status;
    m_radarErrorMessage = message;
    emit radarStatusChanged();
}
