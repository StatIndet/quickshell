#pragma once

#include <QDateTime>
#include <QList>
#include <QMap>
#include <QVariantMap>

struct MonthlyTemperatureNormal {
    bool daytimeValid = false;
    bool nighttimeValid = false;
    double daytimeTemperatureC = 0.0;
    double nighttimeTemperatureC = 0.0;

    QVariantMap toVariantMap() const;
    static MonthlyTemperatureNormal fromVariantMap(const QVariantMap &map);
};

struct WeatherClimateNormals {
    static constexpr int SchemaVersion = 1;
    static constexpr int PeriodStartYear = 1991;
    static constexpr int PeriodEndYear = 2020;

    bool valid = false;
    double latitude = 0.0;
    double longitude = 0.0;
    int periodStartYear = PeriodStartYear;
    int periodEndYear = PeriodEndYear;
    QString model = QStringLiteral("era5_land");
    QMap<int, MonthlyTemperatureNormal> months;

    QVariantMap toVariantMap() const;
    static WeatherClimateNormals fromVariantMap(const QVariantMap &map);
};

struct WeatherSnapshot {
    bool valid = false;
    QString status = "idle";
    QString errorMessage;
    QString locationName;
    double latitude = 0.0;
    double longitude = 0.0;
    QDateTime lastUpdated;
    QDateTime nextRefreshAt;
    QVariantMap current;
    QList<QVariantMap> hourly;
    QList<QVariantMap> daily;
    QList<QVariantMap> dailyTrend;
    QList<QVariantMap> minutely;

    QVariantMap toVariantMap() const;
    static WeatherSnapshot fromVariantMap(const QVariantMap &map);
};
