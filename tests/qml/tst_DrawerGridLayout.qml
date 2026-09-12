import QtQuick
import QtTest
import "../../Modules/Sidebars/Dashboard/drawer/DrawerGridLayout.js" as GridLayout
import "../../Modules/SystemCards/SystemCardCatalog.js" as Catalog

TestCase {
    name: "DrawerGridLayout"

    function verifyCompacted(layout, activeIds) {
        verify(GridLayout.validateLayout(layout, activeIds));
        layout.forEach(function (tile) {
            if (tile.y === 0)
                return;
            const raised = Object.assign({}, tile, {
                                             y: tile.y - 8
                                         });
            verify(layout.some(function (other) {
                return other.id !== tile.id && GridLayout.gridOverlaps(raised, other, 8);
            }), tile.id + " has an empty slot above it");
        });
    }

    function test_defaultLayoutCompactsPartialDrawer() {
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
        compare(single[0].y, 0);
        compare(GridLayout.contentHeight(single), 160);
        verifyCompacted(layout);
    }

    function test_compactionPreservesHorizontalPositionAndVerticalOrder() {
        const active = ["cpu", "gpu", "battery", "storage"];
        const original = [GridLayout.tileAt("cpu", {
                                                x: 0,
                                                y: 160
                                            }), GridLayout.tileAt("gpu", {
                                                                      x: 0,
                                                                      y: 640
                                                                  }), GridLayout.tileAt("battery", {
                                                                                            x: 320,
                                                                                            y: 80
                                                                                        }), GridLayout.tileAt(
                              "storage", {
                                  x: 0,
                                  y: 1200
                              })];
        const before = JSON.stringify(original);
        const compacted = GridLayout.compactLayout(original, active);
        verifyCompacted(compacted, active);
        original.forEach(function (tile) {
            compare(GridLayout.placementFor(compacted, tile.id).x, tile.x);
        });
        compare(GridLayout.placementFor(compacted, "cpu").y, 0);
        compare(GridLayout.placementFor(compacted, "gpu").y, 168);
        compare(GridLayout.placementFor(compacted, "battery").y, 0);
        compare(GridLayout.placementFor(compacted, "storage").y, 336);
        compare(JSON.stringify(original), before);
        compare(JSON.stringify(GridLayout.compactLayout(compacted, active)), JSON.stringify(compacted));
        const saved = GridLayout.serializeLayout(original, active);
        compare(JSON.stringify(GridLayout.hydrateSaved(saved, active)), JSON.stringify(compacted));
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

    function test_savedGapsAreRemoved_data() {
        return [
                    {
                        tag: "v6",
                        version: 6
                    },
                    {
                        tag: "v7",
                        version: 7
                    },
                    {
                        tag: "v8",
                        version: 8
                    }
                ];
    }

    function test_savedGapsAreRemoved(data) {
        const saved = {
            version: data.version,
            tiles: data.version === 8 ? [
                                            {
                                                id: "wifi",
                                                x: 160,
                                                y: 840
                                            },
                                            {
                                                id: "cpu",
                                                x: 0,
                                                y: 1680
                                            }
                                        ] : [
                                            {
                                                id: "wifi",
                                                column: 1,
                                                row: 5
                                            },
                                            {
                                                id: "cpu",
                                                column: 0,
                                                row: 10
                                            }
                                        ]
        };
        const active = ["wifi", "cpu"];
        const layout = GridLayout.hydrateSaved(saved, active);
        verifyCompacted(layout, active);
        compare(GridLayout.placementFor(layout, "wifi").x, 160);
        compare(GridLayout.placementFor(layout, "wifi").y, 0);
        compare(GridLayout.placementFor(layout, "cpu").x, 0);
        compare(GridLayout.placementFor(layout, "cpu").y, 168);
        const written = GridLayout.serializeLayout(layout, active);
        compare(written.version, 8);
        compare(JSON.stringify(GridLayout.serializeLayout(GridLayout.hydrateSaved(written, active), active)),
                JSON.stringify(written));
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
        compare(GridLayout.placementFor(moved, "time").y, 0);
        verifyCompacted(moved);
        compare(JSON.stringify(original), before); // Cancel by discarding the preview.
        compare(JSON.stringify(GridLayout.moveLayout(original, "time", 23, 9)), JSON.stringify(moved));
    }

    function test_dropBelowContentMovesCardToBottomWithoutBlankRows() {
        const moved = GridLayout.moveLayout(GridLayout.defaultLayout(), "storage", 900, 2400);
        verify(GridLayout.validateLayout(moved));
        compare(GridLayout.placementFor(moved, "storage").x, 0);
        compare(GridLayout.placementFor(moved, "storage").y, 1176);
        compare(GridLayout.contentHeight(moved), 1336);
        verifyCompacted(moved);
    }

    function test_sampledTargetsAlwaysResolveWithoutOverlap() {
        const defaults = GridLayout.defaultLayout();
        defaults.forEach(function (tile) {
            for (let y = 0; y < 1900; y += 152) {
                for (let x = 0; x <= 320; x += 40) {
                    const moved = GridLayout.moveLayout(defaults, tile.id, x, y);
                    verifyCompacted(moved);
                    compare(JSON.stringify(GridLayout.compactLayout(moved)), JSON.stringify(moved));
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
        compare(GridLayout.placementFor(layout, "wifi").y, 672);
        verifyCompacted(layout, active);
    }

    function test_returnedAnchorPreservesHorizontalPositionWithoutRestoringGap() {
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
        compare(subset[0].x, 24);
        compare(subset[0].y, 0);
        const restored = GridLayout.hydrateSaved(saved, ["wifi", "time"], {
                                                     time: {
                                                         x: 8,
                                                         y: 8
                                                     }
                                                 });
        compare(GridLayout.placementFor(restored, "time").x, 8);
        compare(GridLayout.placementFor(restored, "time").y, 0);
        compare(GridLayout.placementFor(restored, "wifi").y, 336);
        verifyCompacted(restored, ["wifi", "time"]);
    }

    function test_removingCardClosesGapAndUpdatesSavedPositions() {
        const active = ["cpu", "gpu", "network"];
        const initial = GridLayout.defaultLayout(active);
        const saved = GridLayout.serializeLayout(initial, active);
        compare(GridLayout.placementFor(initial, "network").y, 336);
        const remaining = ["cpu", "network"];
        const removed = GridLayout.hydrateSaved(saved, remaining);
        verifyCompacted(removed, remaining);
        compare(GridLayout.placementFor(removed, "network").y, 168);
        const written = GridLayout.serializeLayout(removed, remaining);
        compare(written.tiles[1].y, 168);
        const restored = GridLayout.hydrateSaved(written, active, {
                                                     gpu: {
                                                         x: 0,
                                                         y: 504
                                                     }
                                                 });
        verifyCompacted(restored, active);
        compare(GridLayout.placementFor(restored, "network").y, 168);
        compare(GridLayout.placementFor(restored, "gpu").y, 336);
    }

    function test_emptySubsetHasMinimalHeight() {
        verify(GridLayout.validateLayout(GridLayout.defaultLayout([]), []));
        compare(GridLayout.contentHeight([]), 160);
    }
}
