#include "keyboard_lock_plugin.h"
#include "runtime/keyboard_led_state.h"
#include "runtime/udev_monitor.h"

#include <QDebug>
#include <QFileInfo>
#include <QFile>
#include <cstring>
#include <QSocketNotifier>
#include <cerrno>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>

struct KeyboardLockState::Device {
    int fd = -1;
    QSocketNotifier *notifier = nullptr;
    KeyboardLedState state;
    ~Device()
    {
        delete notifier;
        if (fd >= 0)
            close(fd);
    }
    bool snapshot()
    {
        unsigned long leds = 0;
        if (ioctl(fd, EVIOCGLED(sizeof(leds)), &leds) < 0)
            return false;
        state = {bool(leds & (1UL << LED_CAPSL)), bool(leds & (1UL << LED_NUML)), false};
        return true;
    }
};

KeyboardLockState::KeyboardLockState(QObject *parent)
    : QObject(parent), m_monitor(new UdevMonitor("input", this))
{
    connect(m_monitor, &UdevMonitor::changed, this, &KeyboardLockState::refresh);
    refresh();
}
KeyboardLockState::~KeyboardLockState() = default;

void KeyboardLockState::refresh()
{
    const auto paths = m_monitor->devicePaths("ID_INPUT_KEYBOARD");
    m_scanError.clear();
    for (auto it = m_devices.begin(); it != m_devices.end();) {
        if (!paths.contains(it->first))
            it = m_devices.erase(it);
        else
            ++it;
    }
    for (const auto &path : paths) {
        const auto name = QFileInfo(path).fileName();
        if (!name.startsWith(QStringLiteral("event")))
            continue;
        QFile capabilities(path + QStringLiteral("/device/capabilities/led"));
        if (capabilities.open(QIODevice::ReadOnly)) {
            bool ok = false;
            const auto bits = capabilities.readAll().trimmed().split(' ').last().toULongLong(&ok, 16);
            if (ok && !(bits & ((1UL << LED_CAPSL) | (1UL << LED_NUML))))
                continue;
        }
        if (m_devices.count(path)) {
            if (!m_devices.at(path)->snapshot()) {
                m_devices.erase(path);
                m_scanError = QStringLiteral("Cannot read keyboard LED state: ") + path;
            }
            continue;
        }
        auto device = std::make_unique<Device>();
        const auto node = QStringLiteral("/dev/input/") + name;
        device->fd = open(node.toLocal8Bit().constData(), O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (device->fd < 0) {
            m_scanError = QStringLiteral("Cannot open keyboard input device: ") + node +
                          QStringLiteral(": ") + QString::fromLocal8Bit(strerror(errno));
            continue;
        }
        unsigned long leds = 0;
        if (ioctl(device->fd, EVIOCGBIT(EV_LED, sizeof(leds)), &leds) < 0 ||
            !(leds & ((1UL << LED_CAPSL) | (1UL << LED_NUML))))
            continue;
        if (!device->snapshot()) {
            m_scanError = QStringLiteral("Cannot read keyboard LED state: ") + node;
            continue;
        }
        // Exclude keystrokes and scan codes from this client's queue when supported.
        // Older kernels may reject the mask; those events are still ignored below.
        unsigned char emptyMask[KEY_CNT / 8] = {};
        for (const unsigned int type : {EV_KEY, EV_MSC, EV_REP}) {
            input_mask mask{type, sizeof(emptyMask), reinterpret_cast<quint64>(emptyMask)};
            ioctl(device->fd, EVIOCSMASK, &mask);
        }
        device->notifier = new QSocketNotifier(device->fd, QSocketNotifier::Read, this);
        connect(device->notifier, &QSocketNotifier::activated, this, [this, path] { readEvents(path); });
        m_devices.emplace(path, std::move(device));
    }
    publish();
}

void KeyboardLockState::readEvents(const QString &path)
{
    auto &device = *m_devices.at(path);
    input_event events[32];
    bool failed = false;
    while (true) {
        const auto size = read(device.fd, events, sizeof(events));
        if (size < 0 && errno == EINTR)
            continue;
        if (size < 0 && errno == EAGAIN)
            break;
        if (size <= 0) {
            failed = true;
            break;
        }
        for (size_t i = 0; i < size_t(size) / sizeof(input_event); ++i) {
            if (device.state.consume(events[i]) && !device.snapshot()) {
                failed = true;
                break;
            }
        }
        if (failed)
            break;
    }
    if (failed) {
        m_devices.erase(path);
        m_scanError = QStringLiteral("Keyboard input stream unavailable: ") + path;
    }
    publish();
}

void KeyboardLockState::publish()
{
    bool caps = false;
    bool num = false;
    for (const auto &[path, device] : m_devices) {
        caps |= device->state.caps;
        num |= device->state.num;
    }
    // A partial set of keyboards cannot establish that a lock is off.
    const bool available = m_monitor->active() && !m_devices.empty() && m_scanError.isEmpty();
    const QString error = !m_monitor->active()     ? QStringLiteral("Keyboard udev monitor unavailable")
                          : !m_scanError.isEmpty() ? m_scanError
                          : m_devices.empty()      ? QStringLiteral("No readable keyboard LED devices")
                                                   : QString();
    const bool availabilityChangedValue = available != m_available || error != m_error;
    const bool stateChanged = caps != m_capsLock || num != m_numLock;
    m_available = available;
    m_capsLock = caps;
    m_numLock = num;
    m_error = error;
    // Consumers reset their OSD baseline before receiving a recovery snapshot.
    if (availabilityChangedValue) {
        if (!error.isEmpty())
            qWarning().noquote() << "KeyboardLockState:" << error;
        emit availabilityChanged();
    }
    if (stateChanged)
        emit lockStateChanged();
}
