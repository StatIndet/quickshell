#include "openmeteo_client.h"
#include "weather_climate_normals.h"
#include "weather_normals_cache.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QTest>
#include <QUrlQuery>

class WeatherClimateNormalsTest : public QObject {
    Q_OBJECT

  private slots:
    void aggregatesMonthlyTemperaturesAndIgnoresMissingValues();
    void cacheRoundTripAndMismatch();
    void buildsStableHistoricalRequest();
};

void WeatherClimateNormalsTest::aggregatesMonthlyTemperaturesAndIgnoresMissingValues()
{
    QJsonObject daily;
    daily["time"] = QJsonArray{"1991-01-01", "1991-01-02", "1991-02-01", "1991-02-02"};
    daily["temperature_2m_max"] = QJsonArray{10.0, 14.0, QJsonValue::Null, 20.0};
    daily["temperature_2m_min"] = QJsonArray{2.0, QJsonValue::Null, 6.0, 8.0};
    const WeatherClimateNormals normals =
        WeatherClimateNormalsAggregator::aggregate(QJsonObject{{"daily", daily}}, 34.0522, -118.2437);

    QVERIFY(normals.valid);
    QCOMPARE(normals.months.value(1).daytimeTemperatureC, 12.0);
    QCOMPARE(normals.months.value(1).nighttimeTemperatureC, 2.0);
    QCOMPARE(normals.months.value(2).daytimeTemperatureC, 20.0);
    QCOMPARE(normals.months.value(2).nighttimeTemperatureC, 7.0);
    QVERIFY(!normals.months.contains(3));
}

void WeatherClimateNormalsTest::cacheRoundTripAndMismatch()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath("weather-normals.json");

    WeatherClimateNormals normals;
    normals.valid = true;
    normals.latitude = 34.0522341;
    normals.longitude = -118.2436849;
    for (int month = 1; month <= 12; ++month) {
        MonthlyTemperatureNormal normal;
        normal.daytimeValid = true;
        normal.nighttimeValid = true;
        normal.daytimeTemperatureC = 20.0 + month;
        normal.nighttimeTemperatureC = 10.0 + month;
        normals.months.insert(month, normal);
    }
    QVERIFY(WeatherNormalsCache::save(path, normals));

    const WeatherClimateNormals loaded = WeatherNormalsCache::load(path, 34.0522342, -118.2436848);
    QVERIFY(loaded.valid);
    QCOMPARE(loaded.months.size(), 12);
    QCOMPARE(loaded.periodStartYear, 1991);
    QCOMPARE(loaded.periodEndYear, 2020);
    QCOMPARE(loaded.model, QStringLiteral("era5_land"));
    QCOMPARE(loaded.months.value(12).daytimeTemperatureC, 32.0);

    QVERIFY(!WeatherNormalsCache::load(path, 35.0522, -118.2437).valid);
    QVERIFY(!WeatherNormalsCache::load(path, 34.0522, -118.2437, 1981, 2010).valid);
    QVERIFY(!WeatherNormalsCache::load(path, 34.0522, -118.2437, 1991, 2020, QStringLiteral("era5")).valid);

    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadOnly));
    QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    file.close();
    root["schemaVersion"] = WeatherClimateNormals::SchemaVersion + 1;
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
    file.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
    file.close();
    QVERIFY(!WeatherNormalsCache::load(path, 34.0522, -118.2437).valid);
}

void WeatherClimateNormalsTest::buildsStableHistoricalRequest()
{
    const QUrl url = OpenMeteoClient::climateNormalsUrl(34.0522, -118.2437);
    QCOMPARE(url.scheme(), QStringLiteral("https"));
    QCOMPARE(url.host(), QStringLiteral("archive-api.open-meteo.com"));
    QCOMPARE(url.path(), QStringLiteral("/v1/archive"));
    const QUrlQuery query(url);
    QCOMPARE(query.queryItemValue("start_date"), QStringLiteral("1991-01-01"));
    QCOMPARE(query.queryItemValue("end_date"), QStringLiteral("2020-12-31"));
    QCOMPARE(query.queryItemValue("models"), QStringLiteral("era5_land"));
    QCOMPARE(query.queryItemValue("daily"), QStringLiteral("temperature_2m_max,temperature_2m_min"));
    QCOMPARE(query.queryItemValue("timezone"), QStringLiteral("auto"));
    QCOMPARE(query.queryItemValue("temperature_unit"), QStringLiteral("celsius"));
}

QTEST_MAIN(WeatherClimateNormalsTest)
#include "weather_climate_normals_test.moc"
