#include "gamma_backend.h"
#include "gamma_curve.h"
#include "qwayland-wlr-gamma-control-unstable-v1.h"
#include <QGuiApplication>
#include <QDBusConnection>
#include <QPointer>
#include <QScreen>
#include <QTemporaryFile>
#include <QTimer>
#include <QWaylandClientExtension>
#include <QtGui/qscreen_platform.h>
#include <map>
#include <functional>

namespace {
class Manager : public QWaylandClientExtensionTemplate<Manager>,
                public QtWayland::zwlr_gamma_control_manager_v1 {
  public:
    Manager() : QWaylandClientExtensionTemplate<Manager>(1) {}
    ~Manager() override
    {
        if (isInitialized())
            destroy();
    }
};
class Control : public QObject, public QtWayland::zwlr_gamma_control_v1 {
  public:
    Control(struct ::zwlr_gamma_control_v1 *object, QObject *parent)
        : QObject(parent), QtWayland::zwlr_gamma_control_v1(object)
    {}
    ~Control() override
    {
        if (isInitialized())
            destroy();
    }
    quint32 size = 0;
    bool failed = false;
    bool submitted = false;
    GammaCurve::Parameters last;
    std::function<void()> notify;
    void zwlr_gamma_control_v1_gamma_size(uint32_t value) override
    {
        if (value < 2 || value > 65536) {
            zwlr_gamma_control_v1_failed();
            return;
        }
        size = value;
        if (notify)
            notify();
    }
    void zwlr_gamma_control_v1_failed() override
    {
        failed = true;
        size = 0;
        if (isInitialized())
            destroy();
        if (notify)
            notify();
    }
};
QPointer<GammaBackend> owner;
} // namespace
struct GammaBackend::Private {
    GammaBackend *q;
    std::unique_ptr<Manager> manager;
    std::map<QScreen *, std::unique_ptr<Control>> controls;
    QHash<QScreen *, int> attempts;
    GammaCurve::Parameters parameters;
    QTimer submit;
    bool owns = false;
    explicit Private(GammaBackend *backend) : q(backend)
    {
        submit.setSingleShot(true);
        submit.setInterval(40);
        QObject::connect(&submit, &QTimer::timeout, q, [this] { sync(); });
        // Construct extensions only on the Wayland QPA platform.
        if (!QGuiApplication::platformName().startsWith(QStringLiteral("wayland")))
            return;
        manager = std::make_unique<Manager>();
        QObject::connect(manager.get(), &Manager::activeChanged, q, [this] {
            controls.clear();
            attempts.clear();
            if (!manager->isActive() && manager->isInitialized())
                manager->destroy();
            submit.start();
            emit q->changed();
        });
        QObject::connect(qGuiApp, &QGuiApplication::screenAdded, q, [this](QScreen *) { submit.start(); });
        QObject::connect(qGuiApp, &QGuiApplication::screenRemoved, q, [this](QScreen *screen) {
            controls.erase(screen);
            attempts.remove(screen);
            emit q->changed();
        });
        QObject::connect(qGuiApp, &QGuiApplication::aboutToQuit, q, [this] { release(); });
    }
    void release()
    {
        owns = false;
        submit.stop();
        controls.clear();
        attempts.clear();
        emit q->changed();
    }
    void sync()
    {
        if (!owns || !manager || !manager->isActive())
            return;
        if (parameters.neutral()) {
            controls.clear();
            attempts.clear();
            emit q->changed();
            return;
        }
        for (QScreen *screen : QGuiApplication::screens()) {
            auto *native = screen->nativeInterface<QNativeInterface::QWaylandScreen>();
            if (!native || !native->output())
                continue;
            auto it = controls.find(screen);
            if (it == controls.end()) {
                auto control = std::make_unique<Control>(manager->get_gamma_control(native->output()), q);
                auto *raw = control.get();
                QPointer<Control> guard(raw);
                QPointer<QScreen> screenGuard(screen);
                raw->notify = [this, guard, screenGuard] {
                    QTimer::singleShot(0, q, [this, guard, screenGuard] {
                        if (!guard || !screenGuard)
                            return;
                        emit q->changed();
                        if (!guard || !screenGuard)
                            return;
                        if (!guard->failed) {
                            submit.start();
                            return;
                        }
                        const int count = ++attempts[screenGuard];
                        if (count > 2)
                            return;
                        QTimer::singleShot(count * 1000, q, [this, guard, screenGuard] {
                            if (!owns || !guard || !screenGuard)
                                return;
                            auto entry = controls.find(screenGuard);
                            if (entry == controls.end() || entry->second.get() != guard.data())
                                return;
                            controls.erase(entry);
                            submit.start();
                        });
                    });
                };
                controls.emplace(screen, std::move(control));
                continue;
            }
            Control &control = *it->second;
            if (!control.size || control.failed || (control.submitted && control.last == parameters))
                continue;
            const auto ramp = GammaCurve::generate(control.size, parameters);
            QTemporaryFile file;
            if (ramp.isEmpty() || !file.open() ||
                file.write(reinterpret_cast<const char *>(ramp.constData()), ramp.size() * sizeof(quint16)) !=
                    ramp.size() * qint64(sizeof(quint16)) ||
                !file.flush() || !file.seek(0)) {
                control.zwlr_gamma_control_v1_failed();
                continue;
            }
            control.set_gamma(file.handle()); // libwayland duplicates the fd before returning.
            control.last = parameters;
            control.submitted = true; // The protocol has no success acknowledgement or readback.
        }
        emit q->changed();
    }
};
GammaBackend::GammaBackend(QObject *parent) : QObject(parent), d(std::make_unique<Private>(this))
{
    QDBusConnection::systemBus().connect(
        QStringLiteral("org.freedesktop.login1"), QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"), QStringLiteral("PrepareForSleep"), this,
        SLOT(prepareForSleep(bool)));
}
void GammaBackend::prepareForSleep(bool sleeping)
{
    if (sleeping)
        return;
    emit resumed();
    QTimer::singleShot(100, this, &GammaBackend::retry);
}
GammaBackend::~GammaBackend()
{
    d->release();
    if (owner == this)
        owner.clear();
}
bool GammaBackend::available() const { return d->manager && d->manager->isActive(); }
QVariantList GammaBackend::outputs() const
{
    QVariantList rows;
    for (QScreen *screen : QGuiApplication::screens()) {
        QString state = available() ? QStringLiteral("released") : QStringLiteral("unavailable");
        auto it = d->controls.find(screen);
        if (it != d->controls.end()) {
            const Control &c = *it->second;
            state = c.failed      ? QStringLiteral("failed")
                    : c.submitted ? QStringLiteral("submitted")
                                  : QStringLiteral("pending");
        }
        rows.append(QVariantMap{{QStringLiteral("name"), screen->name()}, {QStringLiteral("state"), state}});
    }
    return rows;
}
bool GammaBackend::apply(double gamma, double contrast, int temperature, double dimming)
{
    const GammaCurve::Parameters next{gamma, contrast, temperature, dimming};
    if (!next.valid())
        return false;
    if (owner && owner != this)
        owner->d->release();
    owner = this;
    const bool same = d->owns && next == d->parameters;
    d->owns = true;
    d->parameters = next;
    if (!same)
        d->submit.start();
    return true;
}
void GammaBackend::retry()
{
    if (!d->owns)
        return;
    d->controls.clear();
    d->attempts.clear();
    d->submit.start();
}
