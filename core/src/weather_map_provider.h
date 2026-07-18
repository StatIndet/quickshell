#pragma once

#include <QHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QQueue>
#include <QSet>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class QNetworkReply;

class WeatherMapProvider : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool apiConfigured READ apiConfigured NOTIFY apiConfiguredChanged)
    Q_PROPERTY(bool credentialsReady READ credentialsReady NOTIFY credentialsReadyChanged)
    Q_PROPERTY(bool credentialBusy READ credentialBusy NOTIFY credentialBusyChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY statusChanged)

public:
    explicit WeatherMapProvider(QObject *parent = nullptr);

    bool active() const;
    void setActive(bool active);
    bool apiConfigured() const;
    bool credentialsReady() const;
    bool credentialBusy() const;
    bool busy() const;
    QString status() const;
    QString errorMessage() const;

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
    QVariantMap requestGrid(
        const QString &kind,
        const QVariantList &points,
        int generation,
        bool forceRefresh
    );
    QVariantMap storeApiKey(const QString &apiKey);
    QVariantMap clearApiKey();
    void reloadCredentials();

signals:
    void activeChanged();
    void apiConfiguredChanged();
    void credentialsReadyChanged();
    void credentialBusyChanged();
    void apiKeyChanged();
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
    void gridReady(
        const QString &kind,
        int generation,
        const QVariantList &samples,
        const QString &updatedAt,
        bool stale
    );
    void gridFailed(
        const QString &kind,
        int generation,
        const QString &errorCode
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
        bool osm = false;
    };

    struct GridSubscriber {
        QString kind;
        int generation = 0;
    };

    struct GridPoint {
        double latitude = 0.0;
        double longitude = 0.0;
    };

    struct GridTask {
        QString key;
        QString kind;
        QString cachePath;
        QUrl remoteUrl;
        QList<GridPoint> points;
    };

    static constexpr int kMaximumConcurrentRequests = 6;
    static constexpr qint64 kWeatherTileTtlSeconds = 15 * 60;
    static constexpr qint64 kOsmFallbackTtlSeconds = 7 * 24 * 60 * 60;
    static constexpr qint64 kAirQualityGridTtlSeconds = 30 * 60;

    QNetworkAccessManager m_network;
    QQueue<TileTask> m_queue;
    QHash<QNetworkReply *, TileTask> m_inFlight;
    QQueue<GridTask> m_gridQueue;
    QHash<QNetworkReply *, GridTask> m_gridInFlight;
    QHash<QString, QList<TileSubscriber>> m_subscribers;
    QHash<QString, QList<GridSubscriber>> m_gridSubscribers;
    QSet<QString> m_pendingKeys;
    QByteArray m_apiKey;
    QString m_cacheRoot;
    QString m_status = QStringLiteral("idle");
    QString m_errorMessage;
    int m_generation = 0;
    bool m_active = false;
    bool m_busy = false;
    bool m_credentialsReady = false;
    bool m_credentialBusy = false;
    bool m_reloadCredentialsPending = false;

    static int wrappedX(int x, int zoom);
    static bool validTileCoordinate(int zoom, int y);
    static QString normalizedLayer(const QString &layer);
    static QString normalizedGridKind(const QString &kind);
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
    QString gridCachePath(
        const QString &kind,
        const QList<GridPoint> &points
    ) const;
    QUrl remoteGridUrl(
        const QString &kind,
        const QList<GridPoint> &points
    ) const;
    QList<GridPoint> normalizedGridPoints(const QVariantList &points) const;

    bool cacheIsFresh(const TileTask &task) const;
    QVariantMap cacheResult(const TileTask &task, bool stale) const;
    void enqueue(const TileTask &task, const TileSubscriber &subscriber);
    void startQueuedRequests();
    void finishRequest(QNetworkReply *reply);
    void enqueueGrid(
        const GridTask &task,
        const GridSubscriber &subscriber
    );
    void finishGridRequest(QNetworkReply *reply);
    void notifyGridSuccess(
        const GridTask &task,
        const QVariantList &samples,
        const QString &updatedAt,
        bool stale
    );
    void notifyGridFailure(
        const GridTask &task,
        const QString &errorCode
    );
    void notifySuccess(const TileTask &task, bool stale);
    void notifyFailure(const TileTask &task, const QString &errorCode);
    void pruneObsoleteQueue();
    void loadApiKey(bool forceRefresh = false);
    void finishCredentialOperation();
    void replaceApiKey(const QByteArray &apiKey, bool forceRefresh = false);
    void cancelWeatherRequests();
    void setCredentialsReady(bool ready);
    void setCredentialBusy(bool busy);
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
    QVariantMap readGridCache(const QString &path) const;
    bool writeGridCache(
        const QString &path,
        const QVariantList &samples,
        const QString &updatedAt
    ) const;
    bool gridCacheIsFresh(const GridTask &task) const;
    QVariantList parseGridResponse(
        const GridTask &task,
        const QByteArray &body,
        bool *ok
    ) const;
};
