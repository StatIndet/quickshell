#include "weather_climate_normals.h"

#include <QDate>
#include <QJsonArray>
#include <QtMath>

WeatherClimateNormals WeatherClimateNormalsAggregator::aggregate(const QJsonObject &response, double latitude,
                                                                 double longitude)
{
    WeatherClimateNormals result;
    result.latitude = latitude;
    result.longitude = longitude;

    const QJsonObject daily = response.value("daily").toObject();
    const QJsonArray times = daily.value("time").toArray();
    const QJsonArray maxima = daily.value("temperature_2m_max").toArray();
    const QJsonArray minima = daily.value("temperature_2m_min").toArray();
    if (times.isEmpty())
        return result;

    struct Accumulator {
        double daytimeSum = 0.0;
        double nighttimeSum = 0.0;
        int daytimeCount = 0;
        int nighttimeCount = 0;
    };
    QMap<int, Accumulator> accumulators;

    for (int i = 0; i < times.size(); ++i) {
        const QDate date = QDate::fromString(times.at(i).toString(), Qt::ISODate);
        if (!date.isValid() || date.year() < WeatherClimateNormals::PeriodStartYear ||
            date.year() > WeatherClimateNormals::PeriodEndYear)
            continue;

        Accumulator &accumulator = accumulators[date.month()];
        if (i < maxima.size() && maxima.at(i).isDouble()) {
            const double value = maxima.at(i).toDouble(qQNaN());
            if (qIsFinite(value)) {
                accumulator.daytimeSum += value;
                ++accumulator.daytimeCount;
            }
        }
        if (i < minima.size() && minima.at(i).isDouble()) {
            const double value = minima.at(i).toDouble(qQNaN());
            if (qIsFinite(value)) {
                accumulator.nighttimeSum += value;
                ++accumulator.nighttimeCount;
            }
        }
    }

    for (int month = 1; month <= 12; ++month) {
        const Accumulator accumulator = accumulators.value(month);
        MonthlyTemperatureNormal normal;
        if (accumulator.daytimeCount > 0) {
            normal.daytimeValid = true;
            normal.daytimeTemperatureC = accumulator.daytimeSum / accumulator.daytimeCount;
        }
        if (accumulator.nighttimeCount > 0) {
            normal.nighttimeValid = true;
            normal.nighttimeTemperatureC = accumulator.nighttimeSum / accumulator.nighttimeCount;
        }
        if (normal.daytimeValid || normal.nighttimeValid)
            result.months.insert(month, normal);
    }
    result.valid = !result.months.isEmpty();
    return result;
}
