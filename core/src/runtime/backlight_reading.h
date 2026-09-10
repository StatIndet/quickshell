#pragma once
#include <QString>
#include <optional>

struct BacklightReading {
    int actual;
    int maximum;
    double fraction() const { return double(actual) / maximum; }
    static std::optional<BacklightReading> read(const QString &sysPath);
};
