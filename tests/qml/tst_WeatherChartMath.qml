import QtQuick 2.15
import QtTest 1.3
import "../../Modules/Sidebars/Left/WeatherChartMath.js" as WeatherChartMath

TestCase {
    function test_temperatureDomainPadsSmallRange() {
        const domain = WeatherChartMath.temperatureDomain([18, 18, 17, 17, 17, 16], NaN, NaN);
        verify(domain[0] < 16);
        verify(domain[1] > 18);
    }

    function test_temperatureDomainIncludesNormalsBeforePadding() {
        const domain = WeatherChartMath.temperatureDomain([16, 18], 25, 9);
        verify(domain[0] < 9);
        verify(domain[1] > 25);
    }

    function test_zeroRainProducesNoBars() {
        compare(WeatherChartMath.rainMaximum([0, 0, 0, 0]), 0);
        compare(WeatherChartMath.rainBarHeight(0, 0, 40), 0);
    }

    function test_rainUsesIndependentProportionalScale() {
        const maximum = WeatherChartMath.rainMaximum([0, 0.2, 1, 5]);
        compare(maximum, 5);
        compare(WeatherChartMath.rainBarHeight(5, maximum, 40), 40);
        compare(WeatherChartMath.rainBarHeight(1, maximum, 40), 8);
        compare(WeatherChartMath.rainBarHeight(0.01, maximum, 40), 3);
    }

}
