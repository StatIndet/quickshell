#pragma once

#include <QHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QQueue>
#include <QSet>
#include <QUrl>
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

    void beginViewport(int generation);
    QVariantMap requestTile(
        const QString &kind,
        const QString &layer,
        int zoom,
        int x,
        int y,
        int generation,
        bool forceRefresh
    );
    QVariantMap storeApiKey(const QString &apiKey);
    QVariantMap clearApiKey();
    QVariantMap storeMapTilerApiKey(const QString &apiKey);
    QVariantMap clearMapTilerApiKey();
    void reloadCredentials();

signals:
    void activeChanged();
    void apiConfiguredChanged();
    void mapTilerConfiguredChanged();
    void credentialsReadyChanged();
    void credentialBusyChanged();
    void apiKeyChanged();
    void mapTilerApiKeyChanged();
    void mapTilerStatusChanged();
    void credentialOperationFinished(
        const QString &operation,
        bool success,
        const QString &message
    );
    void busyChanged();
    void statusChanged();
    void tileReady(
        const QString &kind,
        const QString &layer,
        int zoom,
        int x,
        int y,
        int generation,
        const QString &localUrl,
        bool stale
    );
    void tileFailed(
        const QString &kind,
        const QString &layer,
        int zoom,
        int x,
        int y,
        int generation,
        const QString &errorCode
    );
    void tileActivity(
        const QString &layer,
        int zoom,
        int x,
        int y,
        int generation,
        bool hasSignal
    );
private:
    struct TileSubscriber {
        QString kind;
        QString layer;
        int zoom = 0;
        int x = 0;
        int y = 0;
        int generation = 0;
    };

    struct TileTask {
        QString key;
        QString kind;
        QString layer;
        QString cachePath;
        QUrl remoteUrl;
        int zoom = 0;
        int x = 0;
        int y = 0;
        bool base = false;
    };

    static constexpr int kMaximumConcurrentRequests = 6;
    static constexpr qint64 kWeatherTileTtlSeconds = 15 * 60;
    static constexpr qint64 kBaseFallbackTtlSeconds = 7 * 24 * 60 * 60;

    QNetworkAccessManager m_network;
    QQueue<TileTask> m_queue;
    QHash<QNetworkReply *, TileTask> m_inFlight;
    QHash<QString, QList<TileSubscriber>> m_subscribers;
    QSet<QString> m_pendingKeys;
    QByteArray m_apiKey;
    QByteArray m_mapTilerApiKey;
    QString m_cacheRoot;
    QString m_status = QStringLiteral("idle");
    QString m_errorMessage;
    QString m_mapTilerStatus = QStringLiteral("loading_credentials");
    int m_generation = 0;
    bool m_active = false;
    bool m_busy = false;
    bool m_credentialsReady = false;
    bool m_credentialBusy = false;
    bool m_reloadCredentialsPending = false;

    static int wrappedX(int x, int zoom);
    static bool validTileCoordinate(int zoom, int y);
    static QString normalizedLayer(const QString &layer);
    static bool validApiKey(const QString &apiKey);

    QString tileCachePath(
        const QString &kind,
        const QString &layer,
        int zoom,
        int x,
        int y
    ) const;
    QString localFileUrl(const QString &path) const;
    QString taskKey(
        const QString &kind,
        const QString &layer,
        int zoom,
        int x,
        int y
    ) const;
    QUrl remoteTileUrl(
        const QString &kind,
        const QString &layer,
        int zoom,
        int x,
        int y
    ) const;

    bool cacheIsFresh(const TileTask &task) const;
    QVariantMap cacheResult(const TileTask &task, bool stale) const;
    void enqueue(const TileTask &task, const TileSubscriber &subscriber);
    void startQueuedRequests();
    void finishRequest(QNetworkReply *reply);
    void notifySuccess(const TileTask &task, bool stale);
    void notifyFailure(const TileTask &task, const QString &errorCode);
    void pruneObsoleteQueue();
    void loadCredentials(bool forceRefresh = false);
    void loadOpenWeatherApiKey(bool forceRefresh);
    void loadMapTilerApiKey(bool forceRefresh);
    void finishCredentialOperation();
    void replaceApiKey(const QByteArray &apiKey, bool forceRefresh = false);
    void replaceMapTilerApiKey(
        const QByteArray &apiKey,
        bool forceRefresh = false
    );
    void cancelWeatherRequests();
    void cancelBaseRequests();
    void setCredentialsReady(bool ready);
    void setCredentialBusy(bool busy);
    void setMapTilerStatus(const QString &status);
    void updateBusy();
    void setStatus(const QString &status, const QString &message = {});

    QVariantMap readMetadata(const QString &cachePath) const;
    void writeMetadata(
        const QString &cachePath,
        QNetworkReply *reply,
        bool keepExistingValidators = false
    );
    bool writeTileAtomically(const QString &path, const QByteArray &body) const;
    bool responseIsImage(QNetworkReply *reply, const QByteArray &body) const;
    bool weatherTileHasSignal(
        const QString &layer,
        const QByteArray &body
    ) const;
    bool cachedWeatherTileHasSignal(const TileTask &task) const;
    void writeWeatherMetadata(
        const QString &cachePath,
        bool hasSignal
    ) const;
};
