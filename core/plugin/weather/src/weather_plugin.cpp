#include "weather_plugin.h"

WeatherPlugin::WeatherPlugin(QObject *parent)
    : QObject(parent),
      m_backend(this),
      m_hourly(this),
      m_daily(this),
      m_dailyTrend(this),
      m_minutely(this)
{
    connect(&m_backend, &WeatherBackend::snapshotChanged, this, [this]() {
        syncModels();
        emit dataChanged();
    });
    connect(&m_backend, &WeatherBackend::loadingChanged, this, &WeatherPlugin::loadingChanged);
    connect(&m_backend, &WeatherBackend::locationSearchChanged,
            this, &WeatherPlugin::locationSearchChanged);
    syncModels();
}

bool WeatherPlugin::loading() const { return m_backend.loading(); }
bool WeatherPlugin::hasValidData() const { return m_backend.snapshot().valid; }
bool WeatherPlugin::hasManualLocation() const { return m_backend.hasManualLocation(); }
QString WeatherPlugin::status() const { return m_backend.snapshot().status; }
QString WeatherPlugin::errorMessage() const { return m_backend.snapshot().errorMessage; }
QString WeatherPlugin::locationName() const { return m_backend.snapshot().locationName; }
double WeatherPlugin::latitude() const { return m_backend.snapshot().latitude; }
double WeatherPlugin::longitude() const { return m_backend.snapshot().longitude; }
QString WeatherPlugin::lastUpdated() const { return m_backend.snapshot().lastUpdated.toString(Qt::ISODate); }
QString WeatherPlugin::nextRefreshAt() const { return m_backend.snapshot().nextRefreshAt.toString(Qt::ISODate); }
bool WeatherPlugin::locationSearchLoading() const { return m_backend.locationSearchLoading(); }
QVariantList WeatherPlugin::locationSearchResults() const { return m_backend.locationSearchResults(); }
QString WeatherPlugin::locationSearchError() const { return m_backend.locationSearchError(); }

double WeatherPlugin::currentTemperatureC() const { return currentValue("temperatureC", 0.0).toDouble(); }
double WeatherPlugin::currentFeelsLikeC() const { return currentValue("feelsLikeC", currentTemperatureC()).toDouble(); }
int WeatherPlugin::currentWeatherCode() const { return currentValue("weatherCode", -1).toInt(); }
QString WeatherPlugin::currentWeatherText() const { return currentValue("weatherText", "Unknown").toString(); }
QString WeatherPlugin::currentIconName() const { return currentValue("iconName", "cloud").toString(); }
double WeatherPlugin::currentWindSpeedMs() const { return currentValue("windSpeedMs", 0.0).toDouble(); }
double WeatherPlugin::currentWindDirection() const { return currentValue("windDirection", 0.0).toDouble(); }
double WeatherPlugin::currentWindGustsMs() const { return currentValue("windGustsMs", 0.0).toDouble(); }
double WeatherPlugin::currentUvIndex() const { return currentValue("uvIndex", 0.0).toDouble(); }
double WeatherPlugin::currentRelativeHumidity() const { return currentValue("relativeHumidity", 0.0).toDouble(); }
double WeatherPlugin::currentDewPointC() const { return currentValue("dewPointC", 0.0).toDouble(); }
double WeatherPlugin::currentPressureHpa() const { return currentValue("pressureHpa", 0.0).toDouble(); }
double WeatherPlugin::currentCloudCover() const { return currentValue("cloudCover", 0.0).toDouble(); }
double WeatherPlugin::currentVisibilityM() const { return currentValue("visibilityM", 0.0).toDouble(); }
QVariantMap WeatherPlugin::currentAirQuality() const { return currentValue("airQuality").toMap(); }

WeatherListModel* WeatherPlugin::hourlyForecast() { return &m_hourly; }
WeatherListModel* WeatherPlugin::dailyForecast() { return &m_daily; }
WeatherListModel* WeatherPlugin::dailyTrendForecast() { return &m_dailyTrend; }
WeatherListModel* WeatherPlugin::minutelyForecast() { return &m_minutely; }

void WeatherPlugin::refresh() { m_backend.refresh(); }
void WeatherPlugin::setManualLocation(double latitude, double longitude, const QString &name) { m_backend.setManualLocation(latitude, longitude, name); }
void WeatherPlugin::clearManualLocation() { m_backend.clearManualLocation(); }
void WeatherPlugin::searchLocations(const QString &query) { m_backend.searchLocations(query); }
QVariantMap WeatherPlugin::current() const { return m_backend.snapshot().current; }

QVariant WeatherPlugin::currentValue(const QString &key, const QVariant &fallback) const {
    return m_backend.snapshot().current.value(key, fallback);
}

void WeatherPlugin::syncModels() {
    const auto &snapshot = m_backend.snapshot();
    m_hourly.setItems(snapshot.hourly);
    m_daily.setItems(snapshot.daily);
    m_dailyTrend.setItems(snapshot.dailyTrend);
    m_minutely.setItems(snapshot.minutely);
}
