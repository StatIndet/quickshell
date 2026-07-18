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
    Q_PROPERTY(bool credentialsReady READ credentialsReady NOTIFY credentialsReadyChanged)
    Q_PROPERTY(bool credentialBusy READ credentialBusy NOTIFY credentialBusyChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY statusChanged)

public:
    explicit WeatherMapPlugin(QObject *parent = nullptr);

    bool active() const;
    void setActive(bool active);
    bool apiConfigured() const;
    bool credentialsReady() const;
    bool credentialBusy() const;
    bool busy() const;
    QString status() const;
    QString errorMessage() const;

    Q_INVOKABLE void beginViewport(int generation);
    Q_INVOKABLE QVariantMap requestTile(
        const QString &kind,
        const QString &layer,
        int zoom,
        int x,
        int y,
        int generation,
        bool forceRefresh
    );
    Q_INVOKABLE QVariantMap requestGrid(
        const QString &kind,
        const QVariantList &points,
        int generation,
        bool forceRefresh
    );
    Q_INVOKABLE QVariantMap storeApiKey(const QString &apiKey);
    Q_INVOKABLE QVariantMap clearApiKey();
    Q_INVOKABLE void reloadCredentials();

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
    WeatherMapProvider m_provider;
};
