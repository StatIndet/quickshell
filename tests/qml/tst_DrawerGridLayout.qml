import QtQuick
import QtTest
import "../../Modules/Sidebars/Left/drawer/DrawerGridLayout.js" as GridLayout
import "../../Modules/SystemCards/SystemCardCatalog.js" as Catalog

TestCase {
    name: "DrawerGridLayout"

    function test_defaultLayoutPreservesFixedCardPositions() {
        const layout = GridLayout.defaultLayout();
        verify(GridLayout.validateLayout(layout));
        compare(layout.length, 11);
        compare(GridLayout.placementFor(layout, "time").x, 0);
        compare(GridLayout.placementFor(layout, "time").y, 0);
        compare(GridLayout.placementFor(layout, "battery").x, 320);
        compare(GridLayout.placementFor(layout, "battery").y, 0);
        compare(GridLayout.placementFor(layout, "weather").x, 160);
        compare(GridLayout.placementFor(layout, "weather").y, 1008);
        const single = GridLayout.defaultLayout(["wifi"]);
        compare(single[0].x, 0);
        compare(single[0].y, 1008);
        compare(GridLayout.contentHeight(single), 1168);
    }

    function test_serializationRoundTrip() {
        const moved = GridLayout.moveLayout(GridLayout.defaultLayout(), "wifi", 24, 2400);
        const saved = GridLayout.serializeLayout(moved);
        compare(saved.version, 8);
        compare(JSON.stringify(GridLayout.serializeLayout(GridLayout.hydrateSaved(saved))), JSON.stringify(
                    saved));
    }

    function test_legacyMigration_data() {
        return [
                    {
                        tag: "v6",
                        version: 6
                    },
                    {
                        tag: "v7",
                        version: 7
                    }
                ];
    }
    function test_legacyMigration(data) {
        const legacy = {
            version: data.version,
            tiles: Catalog.ids().map(function (id) {
                const anchor = Catalog.defaultAnchorFor(id);
                return {
                    id: id,
                    column: anchor.column,
                    row: anchor.row
                };
            })
        };
        const layout = GridLayout.hydrateSaved(legacy);
        verify(GridLayout.validateLayout(layout));
        layout.forEach(function (tile) {
            const old = Catalog.defaultAnchorFor(tile.id);
            compare(tile.x, old.column * 160);
            compare(tile.y, old.row * 168);
        });
        compare(GridLayout.serializeLayout(layout).version, 8);
    }

    function test_invalidSavedLayoutsFallBack() {
        const defaults = GridLayout.defaultLayout();
        const invalid = GridLayout.serializeLayout(defaults);
        invalid.tiles[0].x = 2000;
        compare(JSON.stringify(GridLayout.hydrateSaved(invalid)), JSON.stringify(defaults));
        invalid.tiles[0].x = 0;
        invalid.tiles.push(invalid.tiles[0]);
        compare(JSON.stringify(GridLayout.hydrateSaved(invalid)), JSON.stringify(defaults));
    }

    function test_movesAreFineGrainedAndDoNotMutateCommittedLayout() {
        const original = GridLayout.defaultLayout();
        const before = JSON.stringify(original);
        const moved = GridLayout.moveLayout(original, "time", 23, 9);
        verify(GridLayout.validateLayout(moved));
        compare(GridLayout.placementFor(moved, "time").x, 24);
        compare(GridLayout.placementFor(moved, "time").y, 8);
        compare(JSON.stringify(original), before); // Cancel by discarding the preview.
        compare(JSON.stringify(GridLayout.moveLayout(original, "time", 23, 9)), JSON.stringify(moved));
    }

    function test_cardEdgesAndUnboundedHeight() {
        const moved = GridLayout.moveLayout(GridLayout.defaultLayout(), "storage", 900, 2400);
        verify(GridLayout.validateLayout(moved));
        compare(GridLayout.placementFor(moved, "storage").x, 0);
        compare(GridLayout.placementFor(moved, "storage").y, 2400);
        compare(GridLayout.contentHeight(moved), 2560);
    }

    function test_sampledTargetsAlwaysResolveWithoutOverlap() {
        const defaults = GridLayout.defaultLayout();
        defaults.forEach(function (tile) {
            for (let y = 0; y < 1900; y += 152) {
                for (let x = 0; x <= 320; x += 40) {
                    const moved = GridLayout.moveLayout(defaults, tile.id, x, y);
                    verify(GridLayout.validateLayout(moved), tile.id + " at " + x + "," + y);
                }
            }
        });
    }

    function test_existingPositionsWinBeforeReturningAndNewCards() {
        const saved = {
            version: 8,
            tiles: [
                {
                    id: "weather",
                    x: 0,
                    y: 0
                }
            ]
        };
        const active = ["time", "weather", "wifi"];
        const layout = GridLayout.hydrateSaved(saved, active, {
                                                   time: {
                                                       x: 0,
                                                       y: 0
                                                   }
                                               });
        verify(GridLayout.validateLayout(layout, active));
        compare(GridLayout.placementFor(layout, "weather").x, 0);
        compare(GridLayout.placementFor(layout, "weather").y, 0);
        compare(GridLayout.placementFor(layout, "wifi").x, 0);
        compare(GridLayout.placementFor(layout, "wifi").y, 1008);
    }

    function test_subsetKeepsPositionAndRestoresRememberedAnchor() {
        const saved = {
            version: 8,
            tiles: [
                {
                    id: "wifi",
                    x: 24,
                    y: 1200
                }
            ]
        };
        const subset = GridLayout.hydrateSaved(saved, ["wifi"]);
        compare(subset[0].y, 1200);
        const restored = GridLayout.hydrateSaved(saved, ["wifi", "time"], {
                                                     time: {
                                                         x: 8,
                                                         y: 8
                                                     }
                                                 });
        compare(GridLayout.placementFor(restored, "time").x, 8);
        compare(GridLayout.placementFor(restored, "time").y, 8);
        verify(GridLayout.validateLayout(restored, ["wifi", "time"]));
    }

    function test_emptySubsetHasMinimalHeight() {
        verify(GridLayout.validateLayout(GridLayout.defaultLayout([]), []));
        compare(GridLayout.contentHeight([]), 160);
    }
}
