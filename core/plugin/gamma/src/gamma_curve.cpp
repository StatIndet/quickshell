#include "gamma_curve.h"
#include <algorithm>
#include <cmath>
namespace GammaCurve {
bool Parameters::valid() const
{
    return std::isfinite(gamma) && gamma >= 0.5 && gamma <= 2.0 && std::isfinite(contrast) &&
           contrast >= 0.5 && contrast <= 2.0 && temperature >= 1000 && temperature <= 10000 &&
           std::isfinite(dimming) && dimming >= 0.25 && dimming <= 1.0;
}
bool Parameters::neutral() const
{
    return gamma == 1 && contrast == 1 && temperature == 6500 && dimming == 1;
}
bool Parameters::operator==(const Parameters &p) const
{
    return gamma == p.gamma && contrast == p.contrast && temperature == p.temperature && dimming == p.dimming;
}

// Integrate the Planck spectrum against the CIE 1931 analytic fits from
// Wyman, Sloan & Shirley (2013), equation 4: https://jcgt.org/published/0002/02/01/
// This avoids silently clamping the UI's 1000K end to a chromaticity fit whose
// validity starts at 1667K. Normalize relative to 6500K below, not a measured ICC
// whitepoint. The scalar spectrum normalization cancels when dividing by Y.
static double gaussian(double wavelength, double center, double left, double right)
{
    const double position = (wavelength - center) * (wavelength < center ? left : right);
    return std::exp(-0.5 * position * position);
}
static std::array<double, 3> whitepoint(int temperature)
{
    double X = 0, Y = 0, Z = 0;
    for (double wavelength = 360; wavelength <= 830; wavelength += 5) {
        const double spectrum =
            std::pow(560 / wavelength, 5) / std::expm1(1.438776877e7 / (wavelength * temperature));
        X += spectrum * (1.056 * gaussian(wavelength, 599.8, 0.0264, 0.0323) +
                         0.362 * gaussian(wavelength, 442, 0.0624, 0.0374) -
                         0.065 * gaussian(wavelength, 501.1, 0.0490, 0.0382));
        Y += spectrum * (0.821 * gaussian(wavelength, 568.8, 0.0213, 0.0247) +
                         0.286 * gaussian(wavelength, 530.9, 0.0613, 0.0322));
        Z += spectrum * (1.217 * gaussian(wavelength, 437, 0.0845, 0.0278) +
                         0.681 * gaussian(wavelength, 459, 0.0385, 0.0725));
    }
    X /= Y;
    Z /= Y;
    return {std::max(0.0, 3.2404542 * X - 1.5371385 - 0.4985314 * Z),
            std::max(0.0, -0.9692660 * X + 1.8760108 + 0.0415560 * Z),
            std::max(0.0, 0.0556434 * X - 0.2040259 + 1.0572252 * Z)};
}
QVector<quint16> generate(quint32 size, const Parameters &p)
{
    if (!p.valid() || size < 2 || size > 65536)
        return {};
    auto white = whitepoint(p.temperature);
    const auto neutral = whitepoint(6500);
    for (int c = 0; c < 3; ++c)
        white[c] /= neutral[c];
    const double maximum = *std::max_element(white.begin(), white.end());
    for (double &channel : white)
        channel = std::pow(channel / maximum, 1.0 / 2.2);
    QVector<quint16> result(size * 3);
    for (quint32 i = 0; i < size; ++i) {
        const double value = std::clamp((double(i) / (size - 1) - 0.5) * p.contrast + 0.5, 0.0, 1.0);
        for (quint32 c = 0; c < 3; ++c)
            result[c * size + i] = quint16(std::lround(
                std::clamp(std::pow(value * white[c], 1.0 / p.gamma) * p.dimming, 0.0, 1.0) * 65535));
    }
    return result;
}
} // namespace GammaCurve
