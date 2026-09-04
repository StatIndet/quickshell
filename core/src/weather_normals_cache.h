#pragma once

#include "weather_types.h"

#include <QString>

class WeatherNormalsCache {
  public:
    static QString defaultPath();
    static QString key(double latitude, double longitude, int periodStartYear, int periodEndYear,
                       const QString &model);
    static WeatherClimateNormals load(const QString &path, double latitude, double longitude,
                                      int periodStartYear = WeatherClimateNormals::PeriodStartYear,
                                      int periodEndYear = WeatherClimateNormals::PeriodEndYear,
                                      const QString &model = QStringLiteral("era5_land"));
    static bool save(const QString &path, const WeatherClimateNormals &normals);
};
