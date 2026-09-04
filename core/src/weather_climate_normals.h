#pragma once

#include "weather_types.h"

#include <QJsonObject>

class WeatherClimateNormalsAggregator {
  public:
    static WeatherClimateNormals aggregate(const QJsonObject &response, double latitude, double longitude);
};
