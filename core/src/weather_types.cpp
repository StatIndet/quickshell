#include "weather_types.h"

QVariantMap MonthlyTemperatureNormal::toVariantMap() const
{
    return {{"daytimeValid", daytimeValid},
            {"nighttimeValid", nighttimeValid},
            {"daytimeTemperatureC", daytimeTemperatureC},
            {"nighttimeTemperatureC", nighttimeTemperatureC}};
}

MonthlyTemperatureNormal MonthlyTemperatureNormal::fromVariantMap(const QVariantMap &map)
{
    MonthlyTemperatureNormal normal;
    normal.daytimeValid = map.value("daytimeValid").toBool();
    normal.nighttimeValid = map.value("nighttimeValid").toBool();
    normal.daytimeTemperatureC = map.value("daytimeTemperatureC").toDouble();
    normal.nighttimeTemperatureC = map.value("nighttimeTemperatureC").toDouble();
    return normal;
}

QVariantMap WeatherClimateNormals::toVariantMap() const
{
    QVariantList monthList;
    for (auto it = months.cbegin(); it != months.cend(); ++it) {
        QVariantMap month = it.value().toVariantMap();
        month["month"] = it.key();
        monthList.append(month);
    }
    return {{"latitude", latitude},           {"longitude", longitude}, {"periodStartYear", periodStartYear},
            {"periodEndYear", periodEndYear}, {"model", model},         {"months", monthList}};
}

WeatherClimateNormals WeatherClimateNormals::fromVariantMap(const QVariantMap &map)
{
    WeatherClimateNormals normals;
    normals.latitude = map.value("latitude").toDouble();
    normals.longitude = map.value("longitude").toDouble();
    normals.periodStartYear = map.value("periodStartYear").toInt();
    normals.periodEndYear = map.value("periodEndYear").toInt();
    normals.model = map.value("model").toString();
    for (const QVariant &value : map.value("months").toList()) {
        const QVariantMap monthMap = value.toMap();
        const int month = monthMap.value("month").toInt();
        if (month >= 1 && month <= 12)
            normals.months.insert(month, MonthlyTemperatureNormal::fromVariantMap(monthMap));
    }
    normals.valid = !normals.months.isEmpty();
    return normals;
}

QVariantMap WeatherSnapshot::toVariantMap() const
{
    QVariantMap map;
    QVariantList hourlyList;
    QVariantList dailyList;
    QVariantList dailyTrendList;
    QVariantList minutelyList;
    for (const auto &item : hourly)
        hourlyList.append(item);
    for (const auto &item : daily)
        dailyList.append(item);
    for (const auto &item : dailyTrend)
        dailyTrendList.append(item);
    for (const auto &item : minutely)
        minutelyList.append(item);

    map["valid"] = valid;
    map["status"] = status;
    map["errorMessage"] = errorMessage;
    map["locationName"] = locationName;
    map["latitude"] = latitude;
    map["longitude"] = longitude;
    map["lastUpdated"] = lastUpdated.toString(Qt::ISODate);
    map["nextRefreshAt"] = nextRefreshAt.toString(Qt::ISODate);
    map["current"] = current;
    map["hourly"] = hourlyList;
    map["daily"] = dailyList;
    map["dailyTrend"] = dailyTrendList;
    map["minutely"] = minutelyList;
    return map;
}

WeatherSnapshot WeatherSnapshot::fromVariantMap(const QVariantMap &map)
{
    WeatherSnapshot snapshot;
    snapshot.valid = map.value("valid").toBool();
    snapshot.status = map.value("status", "cache").toString();
    snapshot.errorMessage = map.value("errorMessage").toString();
    snapshot.locationName = map.value("locationName").toString();
    snapshot.latitude = map.value("latitude").toDouble();
    snapshot.longitude = map.value("longitude").toDouble();
    snapshot.lastUpdated = QDateTime::fromString(map.value("lastUpdated").toString(), Qt::ISODate);
    snapshot.nextRefreshAt = QDateTime::fromString(map.value("nextRefreshAt").toString(), Qt::ISODate);
    snapshot.current = map.value("current").toMap();

    for (const auto &value : map.value("hourly").toList())
        snapshot.hourly.append(value.toMap());
    for (const auto &value : map.value("daily").toList())
        snapshot.daily.append(value.toMap());
    for (const auto &value : map.value("dailyTrend").toList())
        snapshot.dailyTrend.append(value.toMap());
    for (const auto &value : map.value("minutely").toList())
        snapshot.minutely.append(value.toMap());
    return snapshot;
}
