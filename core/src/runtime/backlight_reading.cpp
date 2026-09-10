#include "backlight_reading.h"
#include <QFile>

std::optional<BacklightReading> BacklightReading::read(const QString &sysPath)
{
    const auto readValue = [&sysPath](const QString &name) {
        QFile file(sysPath + QLatin1Char('/') + name);
        if (!file.open(QIODevice::ReadOnly))
            return -1;
        bool ok = false;
        const int value = file.readAll().trimmed().toInt(&ok);
        return ok ? value : -1;
    };
    const int actual = readValue(QStringLiteral("actual_brightness"));
    const int maximum = readValue(QStringLiteral("max_brightness"));
    if (actual < 0 || maximum <= 0 || actual > maximum)
        return std::nullopt;
    return BacklightReading{actual, maximum};
}
