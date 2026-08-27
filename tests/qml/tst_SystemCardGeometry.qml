import QtQuick 2.15
import QtTest 1.3
import "../../Modules/SystemCards/SystemCardCatalog.js" as Catalog
import "../../Modules/SystemCards/SystemCardGeometry.js" as Geometry

TestCase {
    function test_sidebarAndDesktopUseTheSameCanonicalSize() {
        Catalog.ids().forEach(function(id) {
            const definition = Catalog.definitionFor(id);
            const size = Geometry.sizeFor(id);
            compare(size.width, Geometry.widthForSpan(definition.columnSpan));
            compare(size.height, Geometry.heightForSpan(definition.rowSpan));
        });
    }

    function test_knownCardSpans() {
        compare(Geometry.sizeFor("cpu").width, 152);
        compare(Geometry.sizeFor("cpu").height, 160);
        compare(Geometry.sizeFor("battery").width, 152);
        compare(Geometry.sizeFor("battery").height, 328);
        compare(Geometry.sizeFor("network").width, 312);
        compare(Geometry.sizeFor("network").height, 160);
        compare(Geometry.sizeFor("storage").width, 472);
        compare(Geometry.sizeFor("storage").height, 160);
        compare(Geometry.sizeFor("weather").width, 312);
        compare(Geometry.sizeFor("weather").height, 328);
    }

    function test_originalSurfaceCardCatalog() {
        ["time", "battery", "cpu", "gpu", "memoryUsed", "wifi", "weather"].forEach(function(id) {
            compare(Catalog.definitionFor(id).preserveDefaultSurface, true);
        });
        ["network", "storage", "calendar"].forEach(function(id) {
            compare(Catalog.definitionFor(id).preserveDefaultSurface, undefined);
        });
    }

    name: "SystemCardGeometry"
}
