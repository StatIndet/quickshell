#include "weather_normals_cache.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

namespace {
QVariantMap readRoot(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    return document.isObject() ? document.object().toVariantMap() : QVariantMap{};
}
} // namespace

QString WeatherNormalsCache::defaultPath()
{
    const QByteArray configured = qgetenv("XDG_CACHE_HOME");
    const QString base = configured.isEmpty() ? QDir::homePath() + "/.cache" : QString::fromUtf8(configured);
    const QString cacheDir = base + "/clavis";
    QDir().mkpath(cacheDir);
    return cacheDir + "/weather-normals.json";
}

QString WeatherNormalsCache::key(double latitude, double longitude, int periodStartYear, int periodEndYear,
                                 const QString &model)
{
    return QStringLiteral("%1|%2-%3|%4|%5")
        .arg(model)
        .arg(periodStartYear)
        .arg(periodEndYear)
        .arg(latitude, 0, 'f', 3)
        .arg(longitude, 0, 'f', 3);
}

WeatherClimateNormals WeatherNormalsCache::load(const QString &path, double latitude, double longitude,
                                                int periodStartYear, int periodEndYear, const QString &model)
{
    const QVariantMap root = readRoot(path);
    if (root.value("schemaVersion").toInt() != WeatherClimateNormals::SchemaVersion)
        return {};
    const QString requestedKey = key(latitude, longitude, periodStartYear, periodEndYear, model);
    for (const QVariant &value : root.value("entries").toList()) {
        const QVariantMap entry = value.toMap();
        if (entry.value("key").toString() != requestedKey)
            continue;
        WeatherClimateNormals normals = WeatherClimateNormals::fromVariantMap(entry);
        if (normals.periodStartYear != periodStartYear || normals.periodEndYear != periodEndYear ||
            normals.model != model)
            return {};
        return normals;
    }
    return {};
}

bool WeatherNormalsCache::save(const QString &path, const WeatherClimateNormals &normals)
{
    if (!normals.valid)
        return false;

    QVariantMap root = readRoot(path);
    if (root.value("schemaVersion").toInt() != WeatherClimateNormals::SchemaVersion)
        root.clear();
    root["schemaVersion"] = WeatherClimateNormals::SchemaVersion;

    const QString entryKey = key(normals.latitude, normals.longitude, normals.periodStartYear,
                                 normals.periodEndYear, normals.model);
    QVariantList entries = root.value("entries").toList();
    QVariantMap entry = normals.toVariantMap();
    entry["key"] = entryKey;
    bool replaced = false;
    for (int i = 0; i < entries.size(); ++i) {
        if (entries.at(i).toMap().value("key").toString() == entryKey) {
            entries[i] = entry;
            replaced = true;
            break;
        }
    }
    if (!replaced)
        entries.append(entry);
    root["entries"] = entries;

    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(QJsonDocument::fromVariant(root).toJson(QJsonDocument::Compact));
    return file.commit();
}
