#include "udev_monitor.h"

#include <QSocketNotifier>
#include <libudev.h>

UdevMonitor::UdevMonitor(const char *subsystem, QObject *parent)
    : QObject(parent), m_subsystem(subsystem), m_context(udev_new())
{
    if (!m_context)
        return;
    m_monitor = udev_monitor_new_from_netlink(m_context, "udev");
    if (!m_monitor || udev_monitor_filter_add_match_subsystem_devtype(m_monitor, subsystem, nullptr) < 0 ||
        udev_monitor_enable_receiving(m_monitor) < 0)
        return;
    m_notifier = new QSocketNotifier(udev_monitor_get_fd(m_monitor), QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, [this] {
        while (auto *device = udev_monitor_receive_device(m_monitor))
            udev_device_unref(device);
        emit changed();
    });
}

UdevMonitor::~UdevMonitor()
{
    delete m_notifier;
    if (m_monitor)
        udev_monitor_unref(m_monitor);
    if (m_context)
        udev_unref(m_context);
}

QStringList UdevMonitor::devicePaths(const char *property) const
{
    QStringList paths;
    if (!m_context)
        return paths;
    auto *enumeration = udev_enumerate_new(m_context);
    if (!enumeration)
        return paths;
    udev_enumerate_add_match_subsystem(enumeration, m_subsystem.constData());
    if (property)
        udev_enumerate_add_match_property(enumeration, property, "1");
    if (udev_enumerate_scan_devices(enumeration) >= 0) {
        udev_list_entry *entry;
        udev_list_entry_foreach(entry, udev_enumerate_get_list_entry(enumeration))
            paths.append(QString::fromUtf8(udev_list_entry_get_name(entry)));
    }
    udev_enumerate_unref(enumeration);
    paths.sort();
    return paths;
}
