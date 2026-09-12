#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QQueue>
#include <QTimer>
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

    virtual void requestIpLocation(LocationCallback callback);
    virtual void requestForecast(double latitude, double longitude, JsonCallback callback);
    virtual void requestAirQuality(double latitude, double longitude, JsonCallback callback);
    virtual void requestClimateNormals(double latitude, double longitude, JsonCallback callback);

    virtual void requestLocationName(const WeatherLocation &location, LocationCallback callback);
    static QString locationNameFromAddress(const QJsonObject &response);

    static QUrl climateNormalsUrl(double latitude, double longitude);

  private:
    struct NameRequest {
        WeatherLocation location;
        LocationCallback callback;
    };
    QNetworkAccessManager m_manager;
    QQueue<NameRequest> m_nameRequests;
    QTimer m_nameTimer;
    bool m_nameRequestActive = false;
    void processNameRequest();
    void getJson(const QUrl &url, JsonCallback callback);
};
