#include "weather_map_plugin.h"

WeatherMapPlugin::WeatherMapPlugin(QObject *parent)
    : QObject(parent),
      m_provider(this)
{
    connect(
        &m_provider,
        &WeatherMapProvider::activeChanged,
        this,
        &WeatherMapPlugin::activeChanged
    );
    connect(
        &m_provider,
        &WeatherMapProvider::apiConfiguredChanged,
        this,
        &WeatherMapPlugin::apiConfiguredChanged
    );
    connect(
        &m_provider,
        &WeatherMapProvider::credentialsReadyChanged,
        this,
        &WeatherMapPlugin::credentialsReadyChanged
    );
    connect(
        &m_provider,
        &WeatherMapProvider::credentialBusyChanged,
        this,
        &WeatherMapPlugin::credentialBusyChanged
    );
    connect(
        &m_provider,
        &WeatherMapProvider::apiKeyChanged,
        this,
        &WeatherMapPlugin::apiKeyChanged
    );
    connect(
        &m_provider,
        &WeatherMapProvider::credentialOperationFinished,
        this,
        &WeatherMapPlugin::credentialOperationFinished
    );
    connect(
        &m_provider,
        &WeatherMapProvider::busyChanged,
        this,
        &WeatherMapPlugin::busyChanged
    );
    connect(
        &m_provider,
        &WeatherMapProvider::statusChanged,
        this,
        &WeatherMapPlugin::statusChanged
    );
    connect(
        &m_provider,
        &WeatherMapProvider::tileReady,
        this,
        &WeatherMapPlugin::tileReady
    );
    connect(
        &m_provider,
        &WeatherMapProvider::tileFailed,
        this,
        &WeatherMapPlugin::tileFailed
    );
    connect(
        &m_provider,
        &WeatherMapProvider::tileActivity,
        this,
        &WeatherMapPlugin::tileActivity
    );
    connect(
        &m_provider,
        &WeatherMapProvider::gridReady,
        this,
        &WeatherMapPlugin::gridReady
    );
    connect(
        &m_provider,
        &WeatherMapProvider::gridFailed,
        this,
        &WeatherMapPlugin::gridFailed
    );
}

bool WeatherMapPlugin::active() const
{
    return m_provider.active();
}

void WeatherMapPlugin::setActive(bool active)
{
    m_provider.setActive(active);
}

bool WeatherMapPlugin::apiConfigured() const
{
    return m_provider.apiConfigured();
}

bool WeatherMapPlugin::credentialsReady() const
{
    return m_provider.credentialsReady();
}

bool WeatherMapPlugin::credentialBusy() const
{
    return m_provider.credentialBusy();
}

bool WeatherMapPlugin::busy() const
{
    return m_provider.busy();
}

QString WeatherMapPlugin::status() const
{
    return m_provider.status();
}

QString WeatherMapPlugin::errorMessage() const
{
    return m_provider.errorMessage();
}

void WeatherMapPlugin::beginViewport(int generation)
{
    m_provider.beginViewport(generation);
}

QVariantMap WeatherMapPlugin::requestTile(
    const QString &kind,
    const QString &layer,
    int zoom,
    int x,
    int y,
    int generation,
    bool forceRefresh
)
{
    return m_provider.requestTile(
        kind,
        layer,
        zoom,
        x,
        y,
        generation,
        forceRefresh
    );
}

QVariantMap WeatherMapPlugin::requestGrid(
    const QString &kind,
    const QVariantList &points,
    int generation,
    bool forceRefresh
)
{
    return m_provider.requestGrid(
        kind,
        points,
        generation,
        forceRefresh
    );
}

QVariantMap WeatherMapPlugin::storeApiKey(const QString &apiKey)
{
    return m_provider.storeApiKey(apiKey);
}

QVariantMap WeatherMapPlugin::clearApiKey()
{
    return m_provider.clearApiKey();
}

void WeatherMapPlugin::reloadCredentials()
{
    m_provider.reloadCredentials();
}
