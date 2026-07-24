import QtQuick
import QtTest
import "../../Modules/Sidebars/Left/system/SystemGridLayout.js" as GridLayout

TestCase {
    name: "SystemGridLayout"

    function serialized(layout) {
        return GridLayout.serializeLayout(layout);
    }

    function test_defaultLayoutIsValid() {
        const layout = GridLayout.defaultLayout();
        verify(GridLayout.validateLayout(layout));
        compare(layout.length, 9);

        let area = 0;
        for (let index = 0; index < layout.length; index += 1)
            area += layout[index].columnSpan * layout[index].rowSpan;
        compare(area, 16);

        compare(
            GridLayout.placementFor(layout, "time").column,
            0
        );
        compare(
            GridLayout.placementFor(layout, "battery").column,
            2
        );
        compare(
            GridLayout.placementFor(layout, "time").rowSpan,
            2
        );
        compare(
            GridLayout.placementFor(layout, "battery").rowSpan,
            2
        );
        compare(
            GridLayout.placementFor(layout, "calendar").columnSpan,
            1
        );
        compare(
            GridLayout.placementFor(layout, "calendar").rowSpan,
            1
        );
    }

    function test_serializationRoundTrip() {
        const layout = GridLayout.defaultLayout();
        const serialized = GridLayout.serializeLayout(layout);
        compare(serialized.version, 5);
        compare(serialized.tiles.length, 9);

        const hydrated = GridLayout.hydrateSaved(serialized);
        verify(GridLayout.validateLayout(hydrated));
        compare(
            JSON.stringify(GridLayout.serializeLayout(hydrated)),
            JSON.stringify(serialized)
        );
    }

    function test_invalidSavedLayoutsFallBack() {
        const duplicate = {
            version: 5,
            tiles: [
                { id: "time", column: 0, row: 0 },
                { id: "time", column: 2, row: 0 }
            ]
        };
        const outOfBounds = GridLayout.serializeLayout(
            GridLayout.defaultLayout()
        );
        outOfBounds.tiles[0].column = 2;

        compare(
            JSON.stringify(
                serialized(GridLayout.hydrateSaved(duplicate))
            ),
            JSON.stringify(
                serialized(GridLayout.defaultLayout())
            )
        );
        compare(
            JSON.stringify(
                serialized(GridLayout.hydrateSaved(outOfBounds))
            ),
            JSON.stringify(
                serialized(GridLayout.defaultLayout())
            )
        );
    }

    function test_smallTileMovesIntoEmptyCell() {
        const moved = GridLayout.moveLayout(
            GridLayout.defaultLayout(),
            "memoryUsed",
            2,
            5
        );
        verify(moved !== null);
        verify(GridLayout.validateLayout(moved));
        compare(
            GridLayout.placementFor(moved, "memoryUsed").column,
            2
        );
        compare(
            GridLayout.placementFor(moved, "memoryUsed").row,
            5
        );
    }

    function test_largeTileCollisionReflows() {
        const moved = GridLayout.moveLayout(
            GridLayout.defaultLayout(),
            "time",
            1,
            0
        );
        verify(moved !== null);
        verify(GridLayout.validateLayout(moved));
        compare(GridLayout.placementFor(moved, "time").column, 1);
        compare(GridLayout.placementFor(moved, "time").row, 0);
        compare(
            GridLayout.placementFor(moved, "battery").column,
            0
        );
    }

    function test_wideTileCollisionReflows() {
        const moved = GridLayout.moveLayout(
            GridLayout.defaultLayout(),
            "network",
            1,
            4
        );
        verify(moved !== null);
        verify(GridLayout.validateLayout(moved));
        compare(
            GridLayout.placementFor(moved, "network").column,
            1
        );
        compare(
            GridLayout.placementFor(moved, "network").row,
            4
        );
    }

    function test_storageSpansFullGridWidth() {
        const storage = GridLayout.placementFor(
            GridLayout.defaultLayout(),
            "storage"
        );
        compare(storage.column, 0);
        compare(storage.columnSpan, GridLayout.columnCount);
        compare(
            GridLayout.clampAnchor(storage, 2, storage.row).column,
            0
        );
    }

    function test_solverIsDeterministic() {
        const first = GridLayout.moveLayout(
            GridLayout.defaultLayout(),
            "battery",
            0,
            2
        );
        const second = GridLayout.moveLayout(
            GridLayout.defaultLayout(),
            "battery",
            0,
            2
        );
        verify(first !== null);
        verify(second !== null);
        compare(
            JSON.stringify(serialized(first)),
            JSON.stringify(serialized(second))
        );
    }

    function test_targetIsClampedToGrid() {
        const moved = GridLayout.moveLayout(
            GridLayout.defaultLayout(),
            "time",
            99,
            99
        );
        verify(moved !== null);
        verify(GridLayout.validateLayout(moved));
        compare(GridLayout.placementFor(moved, "time").column, 1);
        compare(GridLayout.placementFor(moved, "time").row, 5);
    }

    function test_everyLegalAnchorCanBeSolved() {
        const definitions = GridLayout.definitions();
        for (let index = 0; index < definitions.length; index += 1) {
            const definition = definitions[index];
            for (let row = 0;
                    row <= GridLayout.rowCount - definition.rowSpan;
                    row += 1) {
                for (let column = 0;
                        column <= GridLayout.columnCount
                            - definition.columnSpan;
                        column += 1) {
                    const moved = GridLayout.moveLayout(
                        GridLayout.defaultLayout(),
                        definition.id,
                        column,
                        row
                    );
                    verify(
                        moved !== null,
                        definition.id + " could not move to "
                            + column + "," + row
                    );
                    verify(GridLayout.validateLayout(moved));
                }
            }
        }
    }
}
