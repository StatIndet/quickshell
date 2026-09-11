#pragma once
#include <QVector>
#include <array>
namespace GammaCurve {
struct Parameters {
    double gamma = 1.0;
    double contrast = 1.0;
    int temperature = 6500;
    double dimming = 1.0;
    bool valid() const;
    bool neutral() const;
    bool operator==(const Parameters &other) const;
};
// Three consecutive native-endian uint16 channels, never interleaved.
QVector<quint16> generate(quint32 size, const Parameters &parameters);
} // namespace GammaCurve
