#include "weather_backend.h"

#include "weather_cache.h"
#include "weather_calculator.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QSettings>
#include <QTimeZone>
#include <QtMath>

namespace {
double variantDouble(const QVariant &value, double fallback = qQNaN()) {
    bool ok = false;
    const double number = value.toDouble(&ok);
    return ok ? number : fallback;
}

double numberAt(const QJsonObject &object, const QString &key, int index, double fallback = 0.0) {
    const auto array = object.value(key).toArray();
    if (index < 0 || index >= array.size() || array.at(index).isNull()) return fallback;
    return array.at(index).toDouble();
}

int intAt(const QJsonObject &object, const QString &key, int index, int fallback = 0) {
    return qRound(numberAt(object, key, index, fallback));
}

qint64 timeAt(const QJsonObject &object, int index) {
    const auto array = object.value("time").toArray();
    if (index < 0 || index >= array.size()) return 0;
    return array.at(index).toVariant().toLongLong();
}

QVariantMap airAt(const QJsonObject &hourly, int index) {
    QVariantMap air;
    air["pm10"] = numberAt(hourly, "pm10", index, qQNaN());
    air["pm25"] = numberAt(hourly, "pm2_5", index, qQNaN());
    air["carbonMonoxide"] = numberAt(hourly, "carbon_monoxide", index, qQNaN());
    air["nitrogenDioxide"] = numberAt(hourly, "nitrogen_dioxide", index, qQNaN());
    air["sulphurDioxide"] = numberAt(hourly, "sulphur_dioxide", index, qQNaN());
    air["ozone"] = numberAt(hourly, "ozone", index, qQNaN());
    return air;
}

}

WeatherBackend::WeatherBackend(QObject *parent)
    : QObject(parent),
      m_cachePath(WeatherCache::defaultPath())
{
    loadSettings();
    m_snapshot = WeatherCache::load(m_cachePath);
    if (m_snapshot.valid) emit snapshotChanged();

    connect(&m_forecastTimer, &QTimer::timeout, this, &WeatherBackend::refresh);
    connect(&m_airTimer, &QTimer::timeout, this, &WeatherBackend::refresh);
    scheduleTimers();
    QTimer::singleShot(0, this, &WeatherBackend::refresh);
}

void WeatherBackend::refresh() {
    if (m_loading) return;
    setLoading(true);
    if (m_hasManualLocation) {
        startFetch(m_manualLocation);
        return;
    }
    m_client.requestIpLocation([this](bool ok, const WeatherLocation &location, const QString &error) {
        if (!ok) {
            m_snapshot.status = m_snapshot.valid ? "stale" : "error";
            m_snapshot.errorMessage = error;
            setLoading(false);
            emit snapshotChanged();
            return;
        }
        startFetch(location);
    });
}

void WeatherBackend::setManualLocation(double latitude, double longitude, const QString &name) {
    m_manualLocation.latitude = latitude;
    m_manualLocation.longitude = longitude;
    m_manualLocation.name = name.isEmpty() ? QStringLiteral("Manual location") : name;
    m_hasManualLocation = true;
    saveSettings();
    refresh();
}

void WeatherBackend::clearManualLocation() {
    m_hasManualLocation = false;
    saveSettings();
    refresh();
}

void WeatherBackend::setLoading(bool loading) {
    if (m_loading == loading) return;
    m_loading = loading;
    emit loadingChanged();
}

void WeatherBackend::startFetch(const WeatherLocation &location) {
    m_client.requestForecast(location.latitude, location.longitude, [this, location](bool forecastOk, const QJsonObject &forecast, const QString &forecastError) {
        if (!forecastOk) {
            m_snapshot.status = m_snapshot.valid ? "stale" : "error";
            m_snapshot.errorMessage = forecastError;
            setLoading(false);
            emit snapshotChanged();
            return;
        }
        m_client.requestAirQuality(location.latitude, location.longitude, [this, location, forecast](bool airOk, const QJsonObject &air, const QString &airError) {
            applyForecast(location, forecast, airOk ? air : QJsonObject(), airOk ? QString() : airError);
            setLoading(false);
        });
    });
}

void WeatherBackend::applyForecast(const WeatherLocation &location, const QJsonObject &forecast, const QJsonObject &airQuality, const QString &partialError) {
    WeatherSnapshot next;
    next.valid = true;
    next.status = partialError.isEmpty() ? "fresh" : "partial";
    next.errorMessage = partialError;
    next.locationName = location.name;
    next.latitude = location.latitude;
    next.longitude = location.longitude;
    next.lastUpdated = QDateTime::currentDateTime();
    next.nextRefreshAt = next.lastUpdated.addSecs(30 * 60);

    const QJsonObject current = forecast.value("current").toObject();
    const int currentCode = current.value("weather_code").toInt(-1);
    next.current["time"] = current.value("time").toVariant().toLongLong();
    next.current["temperatureC"] = current.value("temperature_2m").toDouble();
    next.current["sourceFeelsLikeC"] = current.value("apparent_temperature").toDouble();
    next.current["feelsLikeC"] = current.value("apparent_temperature").toDouble();
    next.current["weatherCode"] = currentCode;
    next.current["weatherText"] = WeatherCalculator::weatherText(currentCode);
    next.current["iconName"] = WeatherCalculator::iconName(currentCode);
    next.current["windSpeedMs"] = current.value("wind_speed_10m").toDouble();
    next.current["windDirection"] = current.value("wind_direction_10m").toDouble();
    next.current["windGustsMs"] = current.value("wind_gusts_10m").toDouble();
    next.current["uvIndex"] = current.value("uv_index").toDouble();
    next.current["relativeHumidity"] = current.value("relative_humidity_2m").toDouble();
    next.current["dewPointC"] = current.value("dew_point_2m").toDouble();
    next.current["pressureHpa"] = current.value("pressure_msl").toDouble();
    next.current["cloudCover"] = current.value("cloud_cover").toDouble();
    next.current["visibilityM"] = current.value("visibility").toDouble();

    const QJsonObject hourly = forecast.value("hourly").toObject();
    const int hourlyCount = hourly.value("time").toArray().size();
    const QDateTime nowLocal = QDateTime::currentDateTime();
    const QDateTime hourWindowStart(nowLocal.date(), QTime(nowLocal.time().hour(), 0));
    const qint64 windowStart = hourWindowStart.toSecsSinceEpoch();
    const qint64 windowEnd = windowStart + 24 * 3600;
    const qint64 now = nowLocal.toSecsSinceEpoch();
    QList<QVariantMap> allHourly;
    for (int i = 0; i < hourlyCount; ++i) {
        const qint64 time = timeAt(hourly, i);
        QVariantMap item;
        const int code = intAt(hourly, "weather_code", i, -1);
        item["time"] = time;
        item["temperatureC"] = numberAt(hourly, "temperature_2m", i);
        item["sourceFeelsLikeC"] = numberAt(hourly, "apparent_temperature", i);
        item["feelsLikeC"] = item["sourceFeelsLikeC"];
        item["precipitationProbability"] = numberAt(hourly, "precipitation_probability", i);
        item["precipitationMm"] = numberAt(hourly, "precipitation", i);
        item["rainMm"] = numberAt(hourly, "rain", i) + numberAt(hourly, "showers", i);
        item["snowCm"] = numberAt(hourly, "snowfall", i);
        item["weatherCode"] = code;
        item["weatherText"] = WeatherCalculator::weatherText(code);
        item["iconName"] = WeatherCalculator::iconName(code);
        item["windSpeedMs"] = numberAt(hourly, "wind_speed_10m", i);
        item["windDirection"] = numberAt(hourly, "wind_direction_10m", i);
        item["windGustsMs"] = numberAt(hourly, "wind_gusts_10m", i);
        item["uvIndex"] = numberAt(hourly, "uv_index", i);
        item["isDaylight"] = intAt(hourly, "is_day", i, 1) > 0;
        item["relativeHumidity"] = numberAt(hourly, "relative_humidity_2m", i);
        item["dewPointC"] = numberAt(hourly, "dew_point_2m", i);
        item["pressureHpa"] = numberAt(hourly, "pressure_msl", i);
        item["cloudCover"] = numberAt(hourly, "cloud_cover", i);
        item["visibilityM"] = numberAt(hourly, "visibility", i);
        allHourly.append(item);
        if (time >= windowStart && time <= windowEnd) next.hourly.append(item);
    }

    const QJsonObject daily = forecast.value("daily").toObject();
    const int dailyCount = daily.value("time").toArray().size();
    QList<QVariantMap> allDaily;
    for (int i = 0; i < dailyCount; ++i) {
        QVariantMap item;
        const qint64 time = timeAt(daily, i);
        item["time"] = time;
        item["date"] = QDateTime::fromSecsSinceEpoch(time).date().toString(Qt::ISODate);
        item["temperatureMaxC"] = numberAt(daily, "temperature_2m_max", i);
        item["temperatureMinC"] = numberAt(daily, "temperature_2m_min", i);
        item["apparentTemperatureMaxC"] = numberAt(daily, "apparent_temperature_max", i);
        item["apparentTemperatureMinC"] = numberAt(daily, "apparent_temperature_min", i);
        item["sunshineDurationS"] = numberAt(daily, "sunshine_duration", i);
        item["uvIndexMax"] = numberAt(daily, "uv_index_max", i);
        item["relativeHumidityMean"] = numberAt(daily, "relative_humidity_2m_mean", i);
        item["relativeHumidityMax"] = numberAt(daily, "relative_humidity_2m_max", i);
        item["relativeHumidityMin"] = numberAt(daily, "relative_humidity_2m_min", i);
        item["dewPointMeanC"] = numberAt(daily, "dew_point_2m_mean", i);
        item["dewPointMaxC"] = numberAt(daily, "dew_point_2m_max", i);
        item["dewPointMinC"] = numberAt(daily, "dew_point_2m_min", i);
        item["pressureMeanHpa"] = numberAt(daily, "pressure_msl_mean", i);
        item["pressureMaxHpa"] = numberAt(daily, "pressure_msl_max", i);
        item["pressureMinHpa"] = numberAt(daily, "pressure_msl_min", i);
        item["cloudCoverMean"] = numberAt(daily, "cloud_cover_mean", i);
        item["cloudCoverMax"] = numberAt(daily, "cloud_cover_max", i);
        item["cloudCoverMin"] = numberAt(daily, "cloud_cover_min", i);
        item["visibilityMeanM"] = numberAt(daily, "visibility_mean", i);
        item["visibilityMaxM"] = numberAt(daily, "visibility_max", i);
        item["visibilityMinM"] = numberAt(daily, "visibility_min", i);
        allDaily.append(item);
    }
    allDaily = WeatherCalculator::completeDaily(allDaily, allHourly, location.latitude, location.longitude);
    const QDate today = QDateTime::currentDateTime().date();
    const QDate trendStart = today.addDays(-1);
    const QDate trendEnd = today.addDays(14);
    QVariantMap todayDaily;
    for (const auto &day : allDaily) {
        const QDate date = QDate::fromString(day.value("date").toString(), Qt::ISODate);
        if (date == today) todayDaily = day;
        if (date >= today) next.daily.append(day);
        if (date >= trendStart && date <= trendEnd) next.dailyTrend.append(day);
    }
    if (todayDaily.isEmpty() && !next.daily.isEmpty()) todayDaily = next.daily.first();
    if (!next.hourly.isEmpty() && !todayDaily.isEmpty()) {
        next.current = WeatherCalculator::completeCurrent(next.current, next.hourly.first(), todayDaily);
    }

    const QJsonObject minutely = forecast.value("minutely_15").toObject();
    const int minutelyCount = minutely.value("time").toArray().size();
    int added = 0;
    for (int i = 0; i < minutelyCount && added < 8; ++i) {
        const qint64 time = timeAt(minutely, i);
        if (time < now - 15 * 60) continue;
        QVariantMap item;
        item["time"] = time;
        item["minuteInterval"] = 15;
        item["precipitationIntensityMmH"] = numberAt(minutely, "precipitation", i) * 4.0;
        next.minutely.append(item);
        ++added;
    }

    const QJsonObject airHourly = airQuality.value("hourly").toObject();
    const int airCount = airHourly.value("time").toArray().size();
    QHash<qint64, QVariantMap> airByTime;
    QHash<QString, QList<QVariantMap>> dailyAir;
    for (int i = 0; i < airCount; ++i) {
        const qint64 time = timeAt(airHourly, i);
        QVariantMap air = airAt(airHourly, i);
        airByTime.insert(time, air);
        dailyAir[QDateTime::fromSecsSinceEpoch(time).date().toString(Qt::ISODate)].append(air);
    }
    for (auto &hour : next.hourly) {
        const auto air = airByTime.value(hour.value("time").toLongLong());
        if (!air.isEmpty()) hour["airQuality"] = air;
    }
    auto applyDailyAir = [&dailyAir](QList<QVariantMap> &days) {
        for (auto &day : days) {
            const auto values = dailyAir.value(day.value("date").toString());
            if (values.isEmpty()) continue;
            QVariantMap avgAir;
            QStringList airKeys{"pm10", "pm25", "carbonMonoxide", "nitrogenDioxide", "sulphurDioxide", "ozone"};
            for (const auto &key : airKeys) {
                double total = 0.0;
                int count = 0;
                for (const auto &value : values) {
                    const double n = variantDouble(value.value(key));
                    if (!qIsNaN(n)) { total += n; ++count; }
                }
                if (count > 0) avgAir[key] = total / count;
            }
            day["airQuality"] = avgAir;
        }
    };
    applyDailyAir(next.daily);
    applyDailyAir(next.dailyTrend);
    if (!next.hourly.isEmpty() && next.hourly.first().contains("airQuality")) {
        next.current["airQuality"] = next.hourly.first().value("airQuality");
    }

    m_snapshot = next;
    WeatherCache::save(m_cachePath, m_snapshot);
    scheduleTimers();
    emit snapshotChanged();
}

void WeatherBackend::scheduleTimers() {
    m_forecastTimer.start(30 * 60 * 1000);
    m_airTimer.start(60 * 60 * 1000);
}

void WeatherBackend::loadSettings() {
    QSettings settings("Clavis", "Weather");
    m_hasManualLocation = settings.value("manual/enabled", false).toBool();
    m_manualLocation.latitude = settings.value("manual/latitude", 0.0).toDouble();
    m_manualLocation.longitude = settings.value("manual/longitude", 0.0).toDouble();
    m_manualLocation.name = settings.value("manual/name", "Manual location").toString();
}

void WeatherBackend::saveSettings() {
    QSettings settings("Clavis", "Weather");
    settings.setValue("manual/enabled", m_hasManualLocation);
    settings.setValue("manual/latitude", m_manualLocation.latitude);
    settings.setValue("manual/longitude", m_manualLocation.longitude);
    settings.setValue("manual/name", m_manualLocation.name);
}
