#pragma once

#include "weather_backend.h"
#include "weather_list_model.h"

#include <QObject>
#include <QtQml/qqmlregistration.h>

class WeatherPlugin : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasValidData READ hasValidData NOTIFY dataChanged)
    Q_PROPERTY(bool hasManualLocation READ hasManualLocation NOTIFY dataChanged)
    Q_PROPERTY(QString status READ status NOTIFY dataChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY dataChanged)
    Q_PROPERTY(QString locationName READ locationName NOTIFY dataChanged)
    Q_PROPERTY(double latitude READ latitude NOTIFY dataChanged)
    Q_PROPERTY(double longitude READ longitude NOTIFY dataChanged)
    Q_PROPERTY(QString lastUpdated READ lastUpdated NOTIFY dataChanged)
    Q_PROPERTY(QString nextRefreshAt READ nextRefreshAt NOTIFY dataChanged)
    Q_PROPERTY(bool locationSearchLoading READ locationSearchLoading NOTIFY locationSearchChanged)
    Q_PROPERTY(QVariantList locationSearchResults READ locationSearchResults NOTIFY locationSearchChanged)
    Q_PROPERTY(QString locationSearchError READ locationSearchError NOTIFY locationSearchChanged)

    Q_PROPERTY(double currentTemperatureC READ currentTemperatureC NOTIFY dataChanged)
    Q_PROPERTY(double currentFeelsLikeC READ currentFeelsLikeC NOTIFY dataChanged)
    Q_PROPERTY(int currentWeatherCode READ currentWeatherCode NOTIFY dataChanged)
    Q_PROPERTY(QString currentWeatherText READ currentWeatherText NOTIFY dataChanged)
    Q_PROPERTY(QString currentIconName READ currentIconName NOTIFY dataChanged)
    Q_PROPERTY(double currentWindSpeedMs READ currentWindSpeedMs NOTIFY dataChanged)
    Q_PROPERTY(double currentWindDirection READ currentWindDirection NOTIFY dataChanged)
    Q_PROPERTY(double currentWindGustsMs READ currentWindGustsMs NOTIFY dataChanged)
    Q_PROPERTY(double currentUvIndex READ currentUvIndex NOTIFY dataChanged)
    Q_PROPERTY(double currentRelativeHumidity READ currentRelativeHumidity NOTIFY dataChanged)
    Q_PROPERTY(double currentDewPointC READ currentDewPointC NOTIFY dataChanged)
    Q_PROPERTY(double currentPressureHpa READ currentPressureHpa NOTIFY dataChanged)
    Q_PROPERTY(double currentCloudCover READ currentCloudCover NOTIFY dataChanged)
    Q_PROPERTY(double currentVisibilityM READ currentVisibilityM NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap currentAirQuality READ currentAirQuality NOTIFY dataChanged)

    Q_PROPERTY(WeatherListModel* hourlyForecast READ hourlyForecast CONSTANT)
    Q_PROPERTY(WeatherListModel* dailyForecast READ dailyForecast CONSTANT)
    Q_PROPERTY(WeatherListModel* dailyTrendForecast READ dailyTrendForecast CONSTANT)
    Q_PROPERTY(WeatherListModel* minutelyForecast READ minutelyForecast CONSTANT)

public:
    explicit WeatherPlugin(QObject *parent = nullptr);

    bool loading() const;
    bool hasValidData() const;
    bool hasManualLocation() const;
    QString status() const;
    QString errorMessage() const;
    QString locationName() const;
    double latitude() const;
    double longitude() const;
    QString lastUpdated() const;
    QString nextRefreshAt() const;
    bool locationSearchLoading() const;
    QVariantList locationSearchResults() const;
    QString locationSearchError() const;

    double currentTemperatureC() const;
    double currentFeelsLikeC() const;
    int currentWeatherCode() const;
    QString currentWeatherText() const;
    QString currentIconName() const;
    double currentWindSpeedMs() const;
    double currentWindDirection() const;
    double currentWindGustsMs() const;
    double currentUvIndex() const;
    double currentRelativeHumidity() const;
    double currentDewPointC() const;
    double currentPressureHpa() const;
    double currentCloudCover() const;
    double currentVisibilityM() const;
    QVariantMap currentAirQuality() const;

    WeatherListModel* hourlyForecast();
    WeatherListModel* dailyForecast();
    WeatherListModel* dailyTrendForecast();
    WeatherListModel* minutelyForecast();

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setManualLocation(double latitude, double longitude, const QString &name);
    Q_INVOKABLE void clearManualLocation();
    Q_INVOKABLE void searchLocations(const QString &query);
    Q_INVOKABLE QVariantMap current() const;

signals:
    void dataChanged();
    void loadingChanged();
    void locationSearchChanged();

private:
    WeatherBackend m_backend;
    WeatherListModel m_hourly;
    WeatherListModel m_daily;
    WeatherListModel m_dailyTrend;
    WeatherListModel m_minutely;

    QVariant currentValue(const QString &key, const QVariant &fallback = {}) const;
    void syncModels();
};
