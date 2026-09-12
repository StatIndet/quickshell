#include "openmeteo_client.h"

#include <QJsonDocument>
#include <QCryptographicHash>
#include <QDateTime>
#include <QSettings>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrlQuery>

OpenMeteoClient::OpenMeteoClient(QObject *parent) : QObject(parent)
{
    m_nameTimer.setSingleShot(true);
    connect(&m_nameTimer, &QTimer::timeout, this, &OpenMeteoClient::processNameRequest);
}

QString OpenMeteoClient::locationNameFromAddress(const QJsonObject &response)
{
    if (response.contains("error"))
        return {};
    const auto address = response.value("address").toObject();
    for (const auto *key : {"city", "town", "village", "municipality", "county", "state"}) {
        const QString name = address.value(QLatin1String(key)).toString().trimmed();
        if (!name.isEmpty())
            return name;
    }
    return {};
}

void OpenMeteoClient::requestLocationName(const WeatherLocation &location, LocationCallback callback)
{
    m_nameRequests.enqueue({location, std::move(callback)});
    if (!m_nameRequestActive && !m_nameTimer.isActive())
        m_nameTimer.start(0);
}

void OpenMeteoClient::processNameRequest()
{
    if (m_nameRequests.isEmpty())
        return;
    const auto request = m_nameRequests.dequeue();
    QUrl url(qEnvironmentVariable("CLAVIS_GEOCODING_URL", "https://nominatim.openstreetmap.org/reverse"));
    QUrlQuery query(url);
    query.addQueryItem("lat", QString::number(request.location.latitude, 'f', 6));
    query.addQueryItem("lon", QString::number(request.location.longitude, 'f', 6));
    query.addQueryItem("format", "jsonv2");
    query.addQueryItem("zoom", "10");
    query.addQueryItem("addressdetails", "1");
    url.setQuery(query);
    const QString key =
        "geocoding/" +
        QString::fromLatin1(QCryptographicHash::hash(url.toEncoded(), QCryptographicHash::Sha256).toHex());
    QSettings settings("Clavis", "Weather");
    const QString cachedName = settings.value(key + "/name").toString();
    const qint64 retryAfter = settings.value(key + "/retryAfter").toLongLong();
    if (!cachedName.isEmpty() || retryAfter > QDateTime::currentSecsSinceEpoch()) {
        auto location = request.location;
        if (!cachedName.isEmpty())
            location.name = cachedName;
        request.callback(!cachedName.isEmpty(), location, {});
        m_nameTimer.start(0);
        return;
    }
    m_nameRequestActive = true;
    getJson(url, [this, request, key](bool ok, const QJsonObject &response, const QString &error) {
        const QString name = ok ? locationNameFromAddress(response) : QString();
        QSettings settings("Clavis", "Weather");
        settings.setValue(key + "/name", name);
        // Failed/empty lookups back off for a day; successful names persist across restarts.
        settings.setValue(key + "/retryAfter", QDateTime::currentSecsSinceEpoch() + 86400);
        auto location = request.location;
        if (!name.isEmpty())
            location.name = name;
        m_nameRequestActive = false;
        // Serial requests with a cooldown also cover rapid repeated saves.
        m_nameTimer.start(1100);
        request.callback(!name.isEmpty(), location, error);
    });
}

void OpenMeteoClient::requestIpLocation(LocationCallback callback)
{
    getJson(QUrl("https://ipwho.is/?fields=success,latitude,longitude,city,region,country"),
            [callback](bool ok, const QJsonObject &json, const QString &error) {
                if (!ok || !json.value("success").toBool(true)) {
                    callback(false, {}, error.isEmpty() ? QStringLiteral("IP location failed") : error);
                    return;
                }
                WeatherLocation location;
                location.latitude = json.value("latitude").toDouble();
                location.longitude = json.value("longitude").toDouble();
                location.name = json.value("city").toString();
                if (location.name.isEmpty())
                    location.name = json.value("region").toString();
                if (location.name.isEmpty())
                    location.name = json.value("country").toString();
                if (location.name.isEmpty())
                    location.name = "Unknown";
                callback(location.latitude != 0.0 || location.longitude != 0.0, location, {});
            });
}

void OpenMeteoClient::requestForecast(double latitude, double longitude, JsonCallback callback)
{
    QUrl url("https://api.open-meteo.com/v1/forecast");
    QUrlQuery query;
    query.addQueryItem("timezone", "auto");
    query.addQueryItem("timeformat", "unixtime");
    query.addQueryItem("latitude", QString::number(latitude, 'f', 6));
    query.addQueryItem("longitude", QString::number(longitude, 'f', 6));
    query.addQueryItem("models", "best_match");
    query.addQueryItem("forecast_days", "16");
    query.addQueryItem("past_days", "1");
    query.addQueryItem("windspeed_unit", "ms");
    query.addQueryItem(
        "daily",
        "temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunshine_"
        "duration,uv_index_max,relative_humidity_2m_mean,relative_humidity_2m_max,relative_humidity_2m_min,"
        "dew_point_2m_mean,dew_point_2m_max,dew_point_2m_min,pressure_msl_mean,pressure_msl_max,pressure_msl_"
        "min,cloud_cover_mean,cloud_cover_max,cloud_cover_min,visibility_mean,visibility_max,visibility_min");
    query.addQueryItem("hourly",
                       "temperature_2m,apparent_temperature,precipitation_probability,precipitation,rain,"
                       "showers,snowfall,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_"
                       "index,is_day,relative_humidity_2m,dew_point_2m,pressure_msl,cloud_cover,visibility");
    query.addQueryItem(
        "current",
        "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,"
        "uv_index,relative_humidity_2m,dew_point_2m,pressure_msl,cloud_cover,visibility");
    query.addQueryItem("minutely_15", "precipitation");
    url.setQuery(query);
    getJson(url, callback);
}

void OpenMeteoClient::requestAirQuality(double latitude, double longitude, JsonCallback callback)
{
    QUrl url("https://air-quality-api.open-meteo.com/v1/air-quality");
    QUrlQuery query;
    query.addQueryItem("timezone", "auto");
    query.addQueryItem("timeformat", "unixtime");
    query.addQueryItem("latitude", QString::number(latitude, 'f', 6));
    query.addQueryItem("longitude", QString::number(longitude, 'f', 6));
    query.addQueryItem("forecast_days", "7");
    query.addQueryItem("past_days", "1");
    query.addQueryItem("hourly", "pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone");
    url.setQuery(query);
    getJson(url, callback);
}

QUrl OpenMeteoClient::climateNormalsUrl(double latitude, double longitude)
{
    QUrl url("https://archive-api.open-meteo.com/v1/archive");
    QUrlQuery query;
    query.addQueryItem("latitude", QString::number(latitude, 'f', 6));
    query.addQueryItem("longitude", QString::number(longitude, 'f', 6));
    query.addQueryItem("start_date", "1991-01-01");
    query.addQueryItem("end_date", "2020-12-31");
    query.addQueryItem("models", "era5_land");
    query.addQueryItem("daily", "temperature_2m_max,temperature_2m_min");
    query.addQueryItem("timezone", "auto");
    query.addQueryItem("temperature_unit", "celsius");
    url.setQuery(query);
    return url;
}

void OpenMeteoClient::requestClimateNormals(double latitude, double longitude, JsonCallback callback)
{
    getJson(climateNormalsUrl(latitude, longitude), callback);
}

void OpenMeteoClient::getJson(const QUrl &url, JsonCallback callback)
{
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "ClavisWeather/1.0");
    request.setTransferTimeout(15000);
    auto *reply = m_manager.get(request);
    QTimer::singleShot(20000, reply, [reply]() {
        if (!reply->isFinished())
            reply->abort();
    });
    QObject::connect(reply, &QNetworkReply::finished, this, [reply, callback]() {
        const QByteArray body = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || (status != 0 && status >= 400)) {
            const QString error =
                reply->errorString().isEmpty() ? QStringLiteral("HTTP %1").arg(status) : reply->errorString();
            reply->deleteLater();
            callback(false, {}, error);
            return;
        }
        QJsonParseError parseError;
        const auto document = QJsonDocument::fromJson(body, &parseError);
        reply->deleteLater();
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            callback(false, {}, parseError.errorString());
            return;
        }
        callback(true, document.object(), {});
    });
}
