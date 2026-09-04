#include "weather_map_plugin.h"

WeatherMapPlugin::WeatherMapPlugin(QObject *parent) : QObject(parent), m_provider(this)
{
    connect(&m_provider, &WeatherMapProvider::activeChanged, this, &WeatherMapPlugin::activeChanged);
    connect(&m_provider, &WeatherMapProvider::apiConfiguredChanged, this,
            &WeatherMapPlugin::apiConfiguredChanged);
    connect(&m_provider, &WeatherMapProvider::mapTilerConfiguredChanged, this,
            &WeatherMapPlugin::mapTilerConfiguredChanged);
    connect(&m_provider, &WeatherMapProvider::credentialsReadyChanged, this,
            &WeatherMapPlugin::credentialsReadyChanged);
    connect(&m_provider, &WeatherMapProvider::credentialBusyChanged, this,
            &WeatherMapPlugin::credentialBusyChanged);
    connect(&m_provider, &WeatherMapProvider::apiKeyChanged, this, &WeatherMapPlugin::apiKeyChanged);
    connect(&m_provider, &WeatherMapProvider::mapTilerApiKeyChanged, this,
            &WeatherMapPlugin::mapTilerApiKeyChanged);
    connect(&m_provider, &WeatherMapProvider::mapTilerStatusChanged, this,
            &WeatherMapPlugin::mapTilerStatusChanged);
    connect(&m_provider, &WeatherMapProvider::credentialOperationFinished, this,
            &WeatherMapPlugin::credentialOperationFinished);
    connect(&m_provider, &WeatherMapProvider::busyChanged, this, &WeatherMapPlugin::busyChanged);
    connect(&m_provider, &WeatherMapProvider::statusChanged, this, &WeatherMapPlugin::statusChanged);
    connect(&m_provider, &WeatherMapProvider::radarStatusChanged, this,
            &WeatherMapPlugin::radarStatusChanged);
    connect(&m_provider, &WeatherMapProvider::radarFrameChanged, this, &WeatherMapPlugin::radarFrameChanged);
}

bool WeatherMapPlugin::active() const { return m_provider.active(); }

void WeatherMapPlugin::setActive(bool active) { m_provider.setActive(active); }

bool WeatherMapPlugin::apiConfigured() const { return m_provider.apiConfigured(); }

bool WeatherMapPlugin::mapTilerConfigured() const { return m_provider.mapTilerConfigured(); }

bool WeatherMapPlugin::credentialsReady() const { return m_provider.credentialsReady(); }

bool WeatherMapPlugin::credentialBusy() const { return m_provider.credentialBusy(); }

bool WeatherMapPlugin::busy() const { return m_provider.busy(); }

QString WeatherMapPlugin::status() const { return m_provider.status(); }

QString WeatherMapPlugin::errorMessage() const { return m_provider.errorMessage(); }

QString WeatherMapPlugin::mapTilerStatus() const { return m_provider.mapTilerStatus(); }

QString WeatherMapPlugin::radarStatus() const { return m_provider.radarStatus(); }

QString WeatherMapPlugin::radarErrorMessage() const { return m_provider.radarErrorMessage(); }

QString WeatherMapPlugin::radarTileUrl() const { return m_provider.radarTileUrl(); }

qint64 WeatherMapPlugin::radarFrameTime() const { return m_provider.radarFrameTime(); }

QVariantMap WeatherMapPlugin::storeApiKey(const QString &apiKey) { return m_provider.storeApiKey(apiKey); }

QVariantMap WeatherMapPlugin::clearApiKey() { return m_provider.clearApiKey(); }

QVariantMap WeatherMapPlugin::storeMapTilerApiKey(const QString &apiKey)
{
    return m_provider.storeMapTilerApiKey(apiKey);
}

QVariantMap WeatherMapPlugin::clearMapTilerApiKey() { return m_provider.clearMapTilerApiKey(); }

void WeatherMapPlugin::reloadCredentials() { m_provider.reloadCredentials(); }

QString WeatherMapPlugin::mapTilerStyleUrl(const QString &styleId) const
{
    return m_provider.mapTilerStyleUrl(styleId);
}

QString WeatherMapPlugin::openWeatherTileUrl(const QString &layerId) const
{
    return m_provider.openWeatherTileUrl(layerId);
}

void WeatherMapPlugin::validateMapTilerStyle(const QString &styleId)
{
    m_provider.validateMapTilerStyle(styleId);
}

void WeatherMapPlugin::validateOpenWeatherLayer(const QString &layerId)
{
    m_provider.validateOpenWeatherLayer(layerId);
}

void WeatherMapPlugin::refreshRadarMetadata() { m_provider.refreshRadarMetadata(); }
