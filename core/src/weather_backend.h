#pragma once

#include "openmeteo_client.h"
#include "weather_types.h"

#include <QObject>
#include <QTimer>
#include <QVariantList>

class WeatherBackend : public QObject {
    Q_OBJECT

public:
    explicit WeatherBackend(QObject *parent = nullptr);

    const WeatherSnapshot& snapshot() const { return m_snapshot; }
    bool loading() const { return m_loading; }
    bool hasManualLocation() const { return m_hasManualLocation; }
    bool locationSearchLoading() const { return m_locationSearchLoading; }
    QVariantList locationSearchResults() const { return m_locationSearchResults; }
    QString locationSearchError() const { return m_locationSearchError; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setManualLocation(double latitude, double longitude, const QString &name);
    Q_INVOKABLE void clearManualLocation();
    Q_INVOKABLE void searchLocations(const QString &query);

signals:
    void snapshotChanged();
    void loadingChanged();
    void locationSearchChanged();

private:
    OpenMeteoClient m_client;
    WeatherSnapshot m_snapshot;
    QTimer m_forecastTimer;
    QTimer m_airTimer;
    bool m_loading = false;
    bool m_hasManualLocation = false;
    bool m_locationSearchLoading = false;
    QVariantList m_locationSearchResults;
    QString m_locationSearchError;
    WeatherLocation m_manualLocation;
    QString m_cachePath;

    void setLoading(bool loading);
    void startFetch(const WeatherLocation &location);
    void applyForecast(const WeatherLocation &location, const QJsonObject &forecast, const QJsonObject &airQuality, const QString &partialError);
    void scheduleTimers();
    void loadSettings();
    void saveSettings();
};
