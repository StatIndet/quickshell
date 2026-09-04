#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QTimer>
#include <QVariantMap>

class QNetworkReply;

class WeatherMapProvider : public QObject {
    Q_OBJECT

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
    explicit WeatherMapProvider(QObject *parent = nullptr);

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

    QVariantMap storeApiKey(const QString &apiKey);
    QVariantMap clearApiKey();
    QVariantMap storeMapTilerApiKey(const QString &apiKey);
    QVariantMap clearMapTilerApiKey();
    void reloadCredentials();
    QString mapTilerStyleUrl(const QString &styleId) const;
    QString openWeatherTileUrl(const QString &layerId) const;
    void validateMapTilerStyle(const QString &styleId);
    void validateOpenWeatherLayer(const QString &layerId);
    void refreshRadarMetadata();

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
    QNetworkAccessManager m_network;
    QTimer m_radarRefreshTimer;
    QNetworkReply *m_radarReply = nullptr;
    QNetworkReply *m_mapTilerValidationReply = nullptr;
    QNetworkReply *m_openWeatherValidationReply = nullptr;
    QByteArray m_apiKey;
    QByteArray m_mapTilerApiKey;
    QString m_status = QStringLiteral("loading_credentials");
    QString m_errorMessage;
    QString m_mapTilerStatus = QStringLiteral("loading_credentials");
    QString m_radarStatus = QStringLiteral("idle");
    QString m_radarErrorMessage;
    QString m_radarTileUrl;
    qint64 m_radarFrameTime = 0;
    bool m_active = false;
    bool m_credentialsReady = false;
    bool m_credentialBusy = false;
    bool m_reloadCredentialsPending = false;

    static bool validApiKey(const QString &apiKey);
    static QString openWeatherLayerName(const QString &layerId);

    void loadCredentials();
    void loadOpenWeatherApiKey();
    void loadMapTilerApiKey();
    void finishCredentialOperation();
    void replaceApiKey(const QByteArray &apiKey);
    void replaceMapTilerApiKey(const QByteArray &apiKey);
    void setCredentialsReady(bool ready);
    void setCredentialBusy(bool busy);
    void setMapTilerStatus(const QString &status);
    void setStatus(const QString &status, const QString &message = {});
    void setRadarStatus(const QString &status, const QString &message = {});
};
