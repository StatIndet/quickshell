#pragma once
#include <QObject>
#include <QtQml/qqmlregistration.h>

class UdevMonitor;
class BacklightState : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(BacklightState)
    QML_SINGLETON
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY changed)
    Q_PROPERTY(double brightness READ brightness NOTIFY changed)
    Q_PROPERTY(int maxBrightness READ maxBrightness NOTIFY changed)
  public:
    explicit BacklightState(QObject *parent = nullptr);
    bool available() const { return m_available; }
    QString error() const { return m_error; }
    QString deviceName() const { return m_deviceName; }
    double brightness() const { return m_brightness; }
    int maxBrightness() const { return m_maxBrightness; }
    Q_INVOKABLE void refresh();
  signals:
    void changed();

  private:
    UdevMonitor *m_monitor;
    bool m_available = false;
    QString m_error;
    QString m_deviceName;
    double m_brightness = 0;
    int m_maxBrightness = 0;
};
