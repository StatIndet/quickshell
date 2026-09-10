#pragma once

#include <QObject>
#include <QStringList>

struct udev;
struct udev_monitor;
class QSocketNotifier;

// One event subscription per subsystem; callers re-read authoritative device state.
class UdevMonitor : public QObject {
    Q_OBJECT
  public:
    explicit UdevMonitor(const char *subsystem, QObject *parent = nullptr);
    ~UdevMonitor() override;
    bool active() const { return m_notifier != nullptr; }
    QStringList devicePaths(const char *property = nullptr) const;
  signals:
    void changed();

  private:
    QByteArray m_subsystem;
    udev *m_context = nullptr;
    udev_monitor *m_monitor = nullptr;
    QSocketNotifier *m_notifier = nullptr;
};
