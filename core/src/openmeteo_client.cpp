#include "openmeteo_client.h"

#include <QJsonDocument>
#include <QNetworkReply>
#include <QUrlQuery>

OpenMeteoClient::OpenMeteoClient(QObject *parent) : QObject(parent) {}

void OpenMeteoClient::requestIpLocation(LocationCallback callback) {
    getJson(QUrl("https://ipwho.is/?fields=success,latitude,longitude,city,region,country"), [callback](bool ok, const QJsonObject &json, const QString &error) {
        if (!ok || !json.value("success").toBool(true)) {
            callback(false, {}, error.isEmpty() ? QStringLiteral("IP location failed") : error);
            return;
        }
        WeatherLocation location;
        location.latitude = json.value("latitude").toDouble();
        location.longitude = json.value("longitude").toDouble();
        location.name = json.value("city").toString();
        if (location.name.isEmpty()) location.name = json.value("region").toString();
        if (location.name.isEmpty()) location.name = json.value("country").toString();
        if (location.name.isEmpty()) location.name = "Unknown";
        callback(location.latitude != 0.0 || location.longitude != 0.0, location, {});
    });
}

void OpenMeteoClient::requestForecast(double latitude, double longitude, JsonCallback callback) {
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
    query.addQueryItem("daily", "temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunshine_duration,uv_index_max,relative_humidity_2m_mean,relative_humidity_2m_max,relative_humidity_2m_min,dew_point_2m_mean,dew_point_2m_max,dew_point_2m_min,pressure_msl_mean,pressure_msl_max,pressure_msl_min,cloud_cover_mean,cloud_cover_max,cloud_cover_min,visibility_mean,visibility_max,visibility_min");
    query.addQueryItem("hourly", "temperature_2m,apparent_temperature,precipitation_probability,precipitation,rain,showers,snowfall,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,is_day,relative_humidity_2m,dew_point_2m,pressure_msl,cloud_cover,visibility");
    query.addQueryItem("current", "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,relative_humidity_2m,dew_point_2m,pressure_msl,cloud_cover,visibility");
    query.addQueryItem("minutely_15", "precipitation");
    url.setQuery(query);
    getJson(url, callback);
}

void OpenMeteoClient::requestAirQuality(double latitude, double longitude, JsonCallback callback) {
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

void OpenMeteoClient::getJson(const QUrl &url, JsonCallback callback) {
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "ClavisWeather/1.0");
    auto *reply = m_manager.get(request);
    QObject::connect(reply, &QNetworkReply::finished, this, [reply, callback]() {
        const QByteArray body = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || (status != 0 && status >= 400)) {
            const QString error = reply->errorString().isEmpty() ? QStringLiteral("HTTP %1").arg(status) : reply->errorString();
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
