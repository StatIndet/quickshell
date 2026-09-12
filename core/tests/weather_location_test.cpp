#include "openmeteo_client.h"
#include "weather_backend.h"
#include "weather_cache.h"

#include <QFile>
#include <QJsonDocument>
#include <QSettings>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QTest>

class WeatherClientStub : public OpenMeteoClient {
  public:
    QList<LocationCallback> ipRequests;
    QList<LocationCallback> nameRequests;
    QList<JsonCallback> forecasts;
    QList<JsonCallback> airRequests;
    QList<WeatherLocation> locations;

    void requestIpLocation(LocationCallback callback) override { ipRequests.append(callback); }
    void requestLocationName(const WeatherLocation &location, LocationCallback callback) override
    {
        locations.append(location);
        nameRequests.append(callback);
    }
    void requestForecast(double, double, JsonCallback callback) override { forecasts.append(callback); }
    void requestAirQuality(double, double, JsonCallback callback) override { airRequests.append(callback); }
    void requestClimateNormals(double, double, JsonCallback callback) override { callback(false, {}, {}); }
};

class WeatherLocationTest : public QObject {
    Q_OBJECT
    QTemporaryDir m_directory;

  private slots:
    void initTestCase()
    {
        QVERIFY(m_directory.isValid());
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_directory.path());
        qputenv("XDG_CACHE_HOME", m_directory.path().toUtf8());
    }
    void init()
    {
        QSettings("Clavis", "Weather").clear();
        QFile::remove(WeatherCache::defaultPath());
    }
    void automaticNameSurvivesForecastFailure()
    {
        WeatherClientStub client;
        WeatherBackend backend(nullptr, &client);
        QTRY_COMPARE(client.ipRequests.size(), 1);
        backend.setManualLocation(10, 20, "10, 20");
        backend.clearManualLocation();
        QVERIFY(!backend.hasManualLocation());
        QVERIFY(backend.snapshot().locationName.isEmpty());
        QCOMPARE(client.ipRequests.size(), 2);
        client.ipRequests.last()(true, {30, 40, "New city"}, {});
        QCOMPARE(backend.snapshot().locationName, "New city");
        client.forecasts.last()(false, {}, "Forecast unavailable");
        QCOMPARE(backend.snapshot().locationName, "New city");
        QCOMPARE(backend.snapshot().status, "error");
        QVERIFY(!backend.loading());
    }
    void obsoleteRepliesCannotReplaceAutomaticLocation()
    {
        WeatherClientStub client;
        WeatherBackend backend(nullptr, &client);
        QTRY_COMPARE(client.ipRequests.size(), 1);
        backend.setManualLocation(10, 20, "10, 20");
        client.forecasts.last()(true, {}, {});
        QCOMPARE(client.airRequests.size(), 1);
        backend.clearManualLocation();
        client.ipRequests.last()(true, {30, 40, "Automatic city"}, {});
        client.airRequests.first()(true, {}, {});
        client.nameRequests.first()(true, {10, 20, "Old town"}, {});
        client.ipRequests.first()(true, {50, 60, "Obsolete IP city"}, {});
        QCOMPARE(backend.snapshot().locationName, "Automatic city");
        QCOMPARE(backend.snapshot().latitude, 30.0);
        QVERIFY(backend.loading());
        client.forecasts.last()(true, {}, {});
        client.airRequests.last()(true, {}, {});
        QVERIFY(backend.snapshot().valid);
        QVERIFY(!backend.loading());
        QCOMPARE(backend.snapshot().locationName, "Automatic city");
    }
    void manualNameCanArriveBeforeOrAfterForecast()
    {
        for (bool nameFirst : {true, false}) {
            WeatherClientStub client;
            WeatherBackend backend(nullptr, &client);
            QCoreApplication::processEvents();
            backend.setManualLocation(12.345678, 23.456789, "12.345678, 23.456789");
            auto resolve = [&]() {
                client.nameRequests.last()(true, {12.345678, 23.456789, "Nearby town"}, {});
            };
            if (nameFirst)
                resolve();
            client.forecasts.last()(true, {}, {});
            client.airRequests.last()(true, {}, {});
            if (!nameFirst)
                resolve();
            QCOMPARE(backend.snapshot().locationName, "Nearby town");
            QCOMPARE(backend.snapshot().latitude, 12.345678);
            QCOMPARE(backend.snapshot().longitude, 23.456789);
            QCOMPARE(WeatherCache::load(WeatherCache::defaultPath()).locationName, "Nearby town");
        }
    }
    void failedLookupKeepsCoordinatesAndDoesNotBlockForecast()
    {
        WeatherClientStub client;
        WeatherBackend backend(nullptr, &client);
        QTRY_COMPARE(client.ipRequests.size(), 1);
        backend.setManualLocation(10, 20, "10, 20");
        client.forecasts.last()(true, {}, {});
        client.airRequests.last()(true, {}, {});
        QVERIFY(!backend.loading());
        client.nameRequests.last()(false, {10, 20, "10, 20"}, "Offline");
        QCOMPARE(backend.snapshot().locationName, "10, 20");
        QVERIFY(backend.snapshot().valid);
        backend.clearManualLocation();
        client.ipRequests.last()(false, {}, "IP unavailable");
        QVERIFY(backend.snapshot().locationName.isEmpty());
        QCOMPARE(backend.snapshot().errorMessage, "IP unavailable");
        backend.clearManualLocation();
        QVERIFY(backend.loading());
    }
    void addressFallbacks()
    {
        QCOMPARE(OpenMeteoClient::locationNameFromAddress(
                     {{"address", QJsonObject{{"city", "City"}, {"county", "County"}}}}),
                 "City");
        QCOMPARE(OpenMeteoClient::locationNameFromAddress({{"address", QJsonObject{{"town", "Town"}}}}),
                 "Town");
        QCOMPARE(OpenMeteoClient::locationNameFromAddress({{"address", QJsonObject{{"village", "Village"}}}}),
                 "Village");
        QCOMPARE(OpenMeteoClient::locationNameFromAddress(
                     {{"address", QJsonObject{{"city", " "}, {"county", "County"}}}}),
                 "County");
        QVERIFY(
            OpenMeteoClient::locationNameFromAddress({{"address", QJsonObject{{"road", "Road"}}}}).isEmpty());
        QVERIFY(OpenMeteoClient::locationNameFromAddress({{"error", "No coverage"}}).isEmpty());
    }
    void persistentNameCacheAndNegativeCache()
    {
        QTcpServer server;
        QVERIFY(server.listen(QHostAddress::LocalHost));
        qputenv("CLAVIS_GEOCODING_URL",
                QString("http://127.0.0.1:%1/reverse").arg(server.serverPort()).toUtf8());
        int requests = 0;
        QByteArray response = R"({"address":{"city":"Cached city"}})";
        connect(&server, &QTcpServer::newConnection, this, [&]() {
            auto *socket = server.nextPendingConnection();
            connect(socket, &QTcpSocket::readyRead, socket, [&, socket]() {
                socket->readAll();
                ++requests;
                socket->write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " +
                              QByteArray::number(response.size()) + "\r\nConnection: close\r\n\r\n" +
                              response);
                socket->disconnectFromHost();
            });
            connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        });
        for (bool success : {true, false}) {
            const WeatherLocation location{success ? 10.0 : 11.0, 20, "Coordinate fallback"};
            response = success ? R"({"address":{"city":"Cached city"}})" : R"({"error":"No coverage"})";
            for (int attempt = 0; attempt < 2; ++attempt) {
                OpenMeteoClient client;
                bool complete = false;
                client.requestLocationName(
                    location, [&](bool ok, const WeatherLocation &result, const QString &) {
                        QCOMPARE(ok, success);
                        QCOMPARE(result.latitude, location.latitude);
                        QCOMPARE(result.longitude, location.longitude);
                        QCOMPARE(result.name, success ? "Cached city" : "Coordinate fallback");
                        complete = true;
                    });
                QTRY_VERIFY(complete);
            }
        }
        QCOMPARE(requests, 2);
        qunsetenv("CLAVIS_GEOCODING_URL");
    }
};

QTEST_GUILESS_MAIN(WeatherLocationTest)
#include "weather_location_test.moc"
