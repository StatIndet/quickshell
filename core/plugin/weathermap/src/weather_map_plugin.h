#pragma once

#include "weather_map_provider.h"

#include <QObject>
#include <QtQml/qqmlregistration.h>

class WeatherMapPlugin : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool apiConfigured READ apiConfigured NOTIFY apiConfiguredChanged)
    Q_PROPERTY(bool mapTilerConfigured READ mapTilerConfigured NOTIFY mapTilerConfiguredChanged)
    Q_PROPERTY(bool credentialsReady READ credentialsReady NOTIFY credentialsReadyChanged)
    Q_PROPERTY(bool credentialBusy READ credentialBusy NOTIFY credentialBusyChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY statusChanged)
    Q_PROPERTY(QString mapTilerStatus READ mapTilerStatus NOTIFY mapTilerStatusChanged)
    Q_PROPERTY(QString radarStatus READ radarStatus NOTIFY radarStatusChanged)
    Q_PROPERTY(QString radarErrorMessage READ radarErrorMessage NOTIFY radarStatusChanged)
    Q_PROPERTY(QString radarTileUrl READ radarTileUrl NOTIFY radarFrameChanged)
    Q_PROPERTY(qint64 radarFrameTime READ radarFrameTime NOTIFY radarFrameChanged)

  public:
    explicit WeatherMapPlugin(QObject *parent = nullptr);

    bool active() const;
    void setActive(bool active);
    bool apiConfigured() const;
    bool mapTilerConfigured() const;
    bool credentialsReady() const;
    bool credentialBusy() const;
    bool busy() const;
    QString status() const;
    QString errorMessage() const;
    QString mapTilerStatus() const;
    QString radarStatus() const;
    QString radarErrorMessage() const;
    QString radarTileUrl() const;
    qint64 radarFrameTime() const;

    Q_INVOKABLE QVariantMap storeApiKey(const QString &apiKey);
    Q_INVOKABLE QVariantMap clearApiKey();
    Q_INVOKABLE QVariantMap storeMapTilerApiKey(const QString &apiKey);
    Q_INVOKABLE QVariantMap clearMapTilerApiKey();
    Q_INVOKABLE void reloadCredentials();
    Q_INVOKABLE QString mapTilerStyleUrl(const QString &styleId) const;
    Q_INVOKABLE QString openWeatherTileUrl(const QString &layerId) const;
    Q_INVOKABLE void validateMapTilerStyle(const QString &styleId);
    Q_INVOKABLE void validateOpenWeatherLayer(const QString &layerId);
    Q_INVOKABLE void refreshRadarMetadata();

  signals:
    void activeChanged();
    void apiConfiguredChanged();
    void mapTilerConfiguredChanged();
    void credentialsReadyChanged();
    void credentialBusyChanged();
    void apiKeyChanged();
    void mapTilerApiKeyChanged();
    void mapTilerStatusChanged();
    void credentialOperationFinished(const QString &operation, bool success, const QString &message);
    void busyChanged();
    void statusChanged();
    void radarStatusChanged();
    void radarFrameChanged();

  private:
    WeatherMapProvider m_provider;
};
