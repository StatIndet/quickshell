#pragma once

#include "openmeteo_client.h"
#include "weather_types.h"

#include <QObject>
#include <QSet>
#include <QTimer>

class WeatherBackend : public QObject {
    Q_OBJECT

  public:
    explicit WeatherBackend(QObject *parent = nullptr);

    const WeatherSnapshot &snapshot() const { return m_snapshot; }
    bool loading() const { return m_loading; }
    bool normalsLoading() const { return m_normalsLoading; }
    bool hasManualLocation() const { return m_hasManualLocation; }
    const WeatherClimateNormals &climateNormals() const { return m_climateNormals; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setManualLocation(double latitude, double longitude, const QString &name);
    Q_INVOKABLE void clearManualLocation();

  signals:
    void snapshotChanged();
    void loadingChanged();
    void normalsChanged();
    void normalsLoadingChanged();

  private:
    OpenMeteoClient m_client;
    WeatherSnapshot m_snapshot;
    WeatherClimateNormals m_climateNormals;
    QTimer m_forecastTimer;
    QTimer m_airTimer;
    bool m_loading = false;
    bool m_normalsLoading = false;
    bool m_hasManualLocation = false;
    WeatherLocation m_manualLocation;
    QString m_cachePath;
    QString m_normalsCachePath;
    QString m_activeNormalsKey;
    QSet<QString> m_attemptedNormalsKeys;

    void setLoading(bool loading);
    void setNormalsLoading(bool loading);
    void ensureClimateNormals(const WeatherLocation &location);
    void startFetch(const WeatherLocation &location);
    void applyForecast(const WeatherLocation &location, const QJsonObject &forecast,
                       const QJsonObject &airQuality, const QString &partialError);
    void scheduleTimers();
    void loadSettings();
    void saveSettings();
};
