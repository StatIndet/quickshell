#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QList>
#include <functional>

struct WeatherLocation {
    double latitude = 0.0;
    double longitude = 0.0;
    QString name;
};

class OpenMeteoClient : public QObject {
    Q_OBJECT

public:
    explicit OpenMeteoClient(QObject *parent = nullptr);

    using LocationCallback = std::function<void(bool, const WeatherLocation &, const QString &)>;
    using LocationListCallback = std::function<void(bool, const QList<WeatherLocation> &, const QString &)>;
    using JsonCallback = std::function<void(bool, const QJsonObject &, const QString &)>;

    void requestIpLocation(LocationCallback callback);
    void requestLocationSearch(const QString &query, LocationListCallback callback);
    void requestForecast(double latitude, double longitude, JsonCallback callback);
    void requestAirQuality(double latitude, double longitude, JsonCallback callback);

private:
    QNetworkAccessManager m_manager;
    void getJson(const QUrl &url, JsonCallback callback);
};
