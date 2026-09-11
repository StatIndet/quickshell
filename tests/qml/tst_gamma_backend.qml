import QtQuick
import QtTest
import Clavis.Gamma

TestCase {
    name: "GammaBackendWithoutProtocol"
    GammaBackend {
        id: first
    }
    GammaBackend {
        id: second
    }
    function test_missingProtocolAndParameterValidation() {
        // CTest runs on the offscreen QPA platform. It must never acquire a
        // real output just because non-neutral preferences are requested.
        compare(first.available, false);
        verify(first.apply(1.25, 1, 6500, 1));
        compare(first.available, false);
        verify(!first.apply(NaN, 1, 6500, 1));
        verify(!first.apply(1, Infinity, 6500, 1));
        verify(!first.apply(1, 1, 0, 1));
        verify(!first.apply(1, 1, 6500, 0));
        verify(second.apply(1, 1, 6500, 1));
        first.retry();
        compare(second.available, false);
    }
}
