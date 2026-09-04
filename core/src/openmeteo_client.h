#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
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
    using JsonCallback = std::function<void(bool, const QJsonObject &, const QString &)>;

    void requestIpLocation(LocationCallback callback);
    void requestForecast(double latitude, double longitude, JsonCallback callback);
    void requestAirQuality(double latitude, double longitude, JsonCallback callback);
    void requestClimateNormals(double latitude, double longitude, JsonCallback callback);

    static QUrl climateNormalsUrl(double latitude, double longitude);

  private:
    QNetworkAccessManager m_manager;
    void getJson(const QUrl &url, JsonCallback callback);
};
