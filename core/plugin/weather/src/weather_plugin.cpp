#include "weather_plugin.h"

#include <QtMath>

WeatherPlugin::WeatherPlugin(QObject *parent)
    : QObject(parent), m_backend(this), m_hourly(this), m_daily(this), m_dailyTrend(this), m_minutely(this)
{
    connect(&m_backend, &WeatherBackend::snapshotChanged, this, [this]() {
        syncModels();
        emit dataChanged();
    });
    connect(&m_backend, &WeatherBackend::loadingChanged, this, &WeatherPlugin::loadingChanged);
    connect(&m_backend, &WeatherBackend::normalsChanged, this, &WeatherPlugin::normalsChanged);
    connect(&m_backend, &WeatherBackend::normalsLoadingChanged, this, &WeatherPlugin::normalsLoadingChanged);
    syncModels();
}

bool WeatherPlugin::loading() const { return m_backend.loading(); }
bool WeatherPlugin::normalsAvailable() const { return m_backend.climateNormals().valid; }
bool WeatherPlugin::normalsLoading() const { return m_backend.normalsLoading(); }
int WeatherPlugin::normalsPeriodStartYear() const { return m_backend.climateNormals().periodStartYear; }
int WeatherPlugin::normalsPeriodEndYear() const { return m_backend.climateNormals().periodEndYear; }
QString WeatherPlugin::normalsModel() const { return m_backend.climateNormals().model; }
bool WeatherPlugin::hasValidData() const { return m_backend.snapshot().valid; }
bool WeatherPlugin::hasManualLocation() const { return m_backend.hasManualLocation(); }
QString WeatherPlugin::status() const { return m_backend.snapshot().status; }
QString WeatherPlugin::errorMessage() const { return m_backend.snapshot().errorMessage; }
QString WeatherPlugin::locationName() const { return m_backend.snapshot().locationName; }
double WeatherPlugin::latitude() const { return m_backend.snapshot().latitude; }
double WeatherPlugin::longitude() const { return m_backend.snapshot().longitude; }
QString WeatherPlugin::lastUpdated() const { return m_backend.snapshot().lastUpdated.toString(Qt::ISODate); }
QString WeatherPlugin::nextRefreshAt() const
{
    return m_backend.snapshot().nextRefreshAt.toString(Qt::ISODate);
}

double WeatherPlugin::currentTemperatureC() const { return currentValue("temperatureC", 0.0).toDouble(); }
double WeatherPlugin::currentFeelsLikeC() const
{
    return currentValue("feelsLikeC", currentTemperatureC()).toDouble();
}
int WeatherPlugin::currentWeatherCode() const { return currentValue("weatherCode", -1).toInt(); }
QString WeatherPlugin::currentWeatherText() const
{
    return currentValue("weatherText", "Unknown").toString();
}
QString WeatherPlugin::currentIconName() const { return currentValue("iconName", "cloud").toString(); }
double WeatherPlugin::currentWindSpeedMs() const { return currentValue("windSpeedMs", 0.0).toDouble(); }
double WeatherPlugin::currentWindDirection() const { return currentValue("windDirection", 0.0).toDouble(); }
double WeatherPlugin::currentWindGustsMs() const { return currentValue("windGustsMs", 0.0).toDouble(); }
double WeatherPlugin::currentUvIndex() const { return currentValue("uvIndex", 0.0).toDouble(); }
double WeatherPlugin::currentRelativeHumidity() const
{
    return currentValue("relativeHumidity", 0.0).toDouble();
}
double WeatherPlugin::currentDewPointC() const { return currentValue("dewPointC", 0.0).toDouble(); }
double WeatherPlugin::currentPressureHpa() const { return currentValue("pressureHpa", 0.0).toDouble(); }
double WeatherPlugin::currentCloudCover() const { return currentValue("cloudCover", 0.0).toDouble(); }
double WeatherPlugin::currentVisibilityM() const { return currentValue("visibilityM", 0.0).toDouble(); }
QVariantMap WeatherPlugin::currentAirQuality() const { return currentValue("airQuality").toMap(); }

WeatherListModel *WeatherPlugin::hourlyForecast() { return &m_hourly; }
WeatherListModel *WeatherPlugin::dailyForecast() { return &m_daily; }
WeatherListModel *WeatherPlugin::dailyTrendForecast() { return &m_dailyTrend; }
WeatherListModel *WeatherPlugin::minutelyForecast() { return &m_minutely; }

void WeatherPlugin::refresh() { m_backend.refresh(); }
void WeatherPlugin::setManualLocation(double latitude, double longitude, const QString &name)
{
    m_backend.setManualLocation(latitude, longitude, name);
}
void WeatherPlugin::clearManualLocation() { m_backend.clearManualLocation(); }
QVariantMap WeatherPlugin::current() const { return m_backend.snapshot().current; }

double WeatherPlugin::normalDaytimeTemperatureC(int month) const
{
    const MonthlyTemperatureNormal normal = m_backend.climateNormals().months.value(month);
    return normal.daytimeValid ? normal.daytimeTemperatureC : qQNaN();
}

double WeatherPlugin::normalNighttimeTemperatureC(int month) const
{
    const MonthlyTemperatureNormal normal = m_backend.climateNormals().months.value(month);
    return normal.nighttimeValid ? normal.nighttimeTemperatureC : qQNaN();
}

QVariant WeatherPlugin::currentValue(const QString &key, const QVariant &fallback) const
{
    return m_backend.snapshot().current.value(key, fallback);
}

void WeatherPlugin::syncModels()
{
    const auto &snapshot = m_backend.snapshot();
    m_hourly.setItems(snapshot.hourly);
    m_daily.setItems(snapshot.daily);
    m_dailyTrend.setItems(snapshot.dailyTrend);
    m_minutely.setItems(snapshot.minutely);
}
