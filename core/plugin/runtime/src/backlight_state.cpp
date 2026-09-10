#include "backlight_state.h"
#include "runtime/backlight_reading.h"
#include "runtime/udev_monitor.h"
#include <QDebug>
#include <QFileInfo>
#include <algorithm>

BacklightState::BacklightState(QObject *parent)
    : QObject(parent), m_monitor(new UdevMonitor("backlight", this))
{
    connect(m_monitor, &UdevMonitor::changed, this, &BacklightState::refresh);
    refresh();
}

void BacklightState::refresh()
{
    auto paths = m_monitor->devicePaths();
    // Choose a stable device; brightnessctl writes explicitly target the same name.
    std::sort(paths.begin(), paths.end(), [](const QString &a, const QString &b) {
        return QFileInfo(a).fileName() < QFileInfo(b).fileName();
    });
    const auto name = paths.isEmpty() ? QString() : QFileInfo(paths.first()).fileName();
    const auto reading = paths.isEmpty() ? std::nullopt : BacklightReading::read(paths.first());
    const bool available = reading.has_value() && m_monitor->active();
    const auto error = !m_monitor->active() ? QStringLiteral("Backlight udev monitor unavailable")
                       : paths.isEmpty()    ? QString()
                       : !reading ? QStringLiteral("Cannot read actual backlight brightness: ") + name
                                  : QString();
    const double brightness = reading ? reading->fraction() : 0;
    const int maximum = reading ? reading->maximum : 0;
    if (available == m_available && error == m_error && name == m_deviceName && brightness == m_brightness &&
        maximum == m_maxBrightness)
        return;
    if (!error.isEmpty() && error != m_error)
        qWarning().noquote() << "BacklightState:" << error;
    m_available = available;
    m_error = error;
    m_deviceName = name;
    m_brightness = brightness;
    m_maxBrightness = maximum;
    emit changed();
}
