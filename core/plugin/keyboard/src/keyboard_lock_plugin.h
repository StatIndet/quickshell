#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <map>
#include <memory>

class UdevMonitor;
class KeyboardLockState : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(KeyboardLockState)
    QML_SINGLETON
    Q_PROPERTY(bool numLock READ numLock NOTIFY lockStateChanged)
    Q_PROPERTY(bool capsLock READ capsLock NOTIFY lockStateChanged)
    Q_PROPERTY(bool available READ available NOTIFY availabilityChanged)
    Q_PROPERTY(QString error READ error NOTIFY availabilityChanged)
  public:
    explicit KeyboardLockState(QObject *parent = nullptr);
    ~KeyboardLockState() override;
    bool numLock() const { return m_numLock; }
    bool capsLock() const { return m_capsLock; }
    bool available() const { return m_available; }
    QString error() const { return m_error; }
    Q_INVOKABLE void refresh();
  signals:
    void lockStateChanged();
    void availabilityChanged();

  private:
    struct Device;
    void readEvents(const QString &path);
    void publish();
    UdevMonitor *m_monitor;
    std::map<QString, std::unique_ptr<Device>> m_devices;
    QString m_scanError;
    QString m_error;
    bool m_available = false;
    bool m_numLock = false;
    bool m_capsLock = false;
};
