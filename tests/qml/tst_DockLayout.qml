import QtQuick
import QtTest
import "../../Common/functions/DockLayout.js" as DockLayout

TestCase {
    name: "DockLayout"

    function test_sideFansShowEightFilesWhenSpaceAllows() {
        for (const edge of ["left", "right"]) {
            for (const count of [8, 9, 200]) {
                const geometry = DockLayout.folderFan(edge, count, 2000, 1000, edge === "right", 64);
                compare(geometry.count, 8);
            }
        }
    }

    function test_sideFansFitAndMirror() {
        for (const width of [180, 360, 1000]) {
            for (const height of [160, 480, 1080]) {
                for (const size of [64, 96, 160]) {
                    for (const count of [0, 1, 8, 200]) {
                        const left = DockLayout.folderFan("left", count, width, height, false, size);
                        const right = DockLayout.folderFan("right", count, width, height, true, size);
                        verify(left.width <= width && left.height <= height);
                        verify(left.count <= count);
                        let previousX = -Infinity;
                        for (let position = 0; position <= left.count; position += 0.25) {
                            const a = DockLayout.folderFanSlot("left", position, left, false);
                            const b = DockLayout.folderFanSlot("right", position, right, true);
                            verify(a.x >= previousX);
                            previousX = a.x;
                            fuzzyCompare(a.x + b.x + a.width, left.width, 0.001);
                            compare(a.y, b.y);
                            compare(a.rotation, -b.rotation);
                            const cx = a.x + a.width / 2, cy = a.y + left.iconSize / 2;
                            const angle = a.rotation * Math.PI / 180;
                            for (const x of [a.x, a.x + a.width]) {
                                for (const y of [a.y, a.y + a.height]) {
                                    const rx = cx + (x - cx) * Math.cos(angle) - (y - cy) * Math.sin(angle);
                                    const ry = cy + (x - cx) * Math.sin(angle) + (y - cy) * Math.cos(angle);
                                    verify(rx >= 0 && rx <= left.width);
                                    verify(ry >= 0 && ry <= left.height);
                                }
                            }
                        }
                        if (left.count > 0) {
                            const first = DockLayout.folderFanSlot("left", 0, left, false);
                            const next = DockLayout.folderFanSlot("left", 1, left, false);
                            verify(next.x - first.x >= first.width);
                        }
                    }
                }
            }
        }
    }

    function test_folderFanFitsAvailableSpace() {
        for (const edge of ["bottom", "left", "right"]) {
            for (const count of [0, 1, 7, 200]) {
                for (const iconSize of [64, 84, 160]) {
                    const layout = DockLayout.folderFan(edge, count, 800, 600, true, iconSize);
                    compare(layout.iconSize, iconSize);
                    verify(layout.count <= count);
                    verify(layout.width <= 800 && layout.height <= 600);
                    for (const slot of layout.slots) {
                        verify(slot.x >= 0 && slot.y >= 0);
                        verify(slot.x + slot.width <= layout.width);
                        verify(slot.y + slot.height <= layout.height);
                        verify(slot.height >= iconSize);
                    }
                }
            }
        }
    }

    function fanCenter(slot, layout, labelsLeft) {
        return Qt.point(slot.x + (labelsLeft ? slot.width - layout.iconSize / 2 - 6 : layout.iconSize / 2 + 6),
                        slot.y + slot.height / 2);
    }

    function verifyFanBounds(layout, labelsLeft) {
        // Include the fixed action and fractional positions during scrolling.
        for (let position = 0; position <= layout.count; position += 0.25) {
            const slot = DockLayout.folderFanSlot("bottom", position, layout, labelsLeft);
            const center = fanCenter(slot, layout, labelsLeft);
            const angle = slot.rotation * Math.PI / 180;
            for (const x of [slot.x, slot.x + slot.width]) {
                for (const y of [slot.y, slot.y + slot.height]) {
                    const dx = x - center.x, dy = y - center.y;
                    const rotatedX = center.x + dx * Math.cos(angle) - dy * Math.sin(angle);
                    const rotatedY = center.y + dx * Math.sin(angle) + dy * Math.cos(angle);
                    verify(rotatedX >= 0 && rotatedX <= layout.width);
                    verify(rotatedY >= 0 && rotatedY <= layout.height);
                }
            }
        }
    }

    function test_fanRotatedBoundsFitAndMirror() {
        for (const width of [260, 800]) {
            for (const height of [240, 600, 1400]) {
                for (const size of [64, 84, 160]) {
                    for (const count of [0, 1, 5, 11, 200]) {
                        const layout = DockLayout.folderFan("bottom", count, width, height, true, size);
                        verify(layout.width <= width && layout.height <= height);
                        verifyFanBounds(layout, true);
                        verifyFanBounds(layout, false);
                        for (let position = 0; position <= layout.count; ++position) {
                            const left = DockLayout.folderFanSlot("bottom", position, layout, true);
                            const right = DockLayout.folderFanSlot("bottom", position, layout, false);
                            fuzzyCompare(left.x + right.x + left.width, layout.width, 0.00001);
                            compare(left.y, right.y);
                            compare(left.rotation, -right.rotation);
                        }
                    }
                }
            }
        }
    }

    function test_fanCurveAndTiltShareTangent() {
        const short = DockLayout.folderFan("bottom", 5, 1000, 1600, true, 84);
        const long = DockLayout.folderFan("bottom", 11, 1000, 1600, true, 84);
        compare(short.count, 5);
        compare(long.count, 8);
        const first = fanCenter(long.slots[0], long, true);
        const last = fanCenter(long.slots[long.count - 1], long, true);
        const shortFirst = fanCenter(short.slots[0], short, true);
        const shortLast = fanCenter(short.slots[short.count - 1], short, true);
        verify(last.x - first.x > shortLast.x - shortFirst.x);
        for (let index = 1; index < long.count; ++index) {
            const before = long.slots[index - 1], after = long.slots[index];
            const a = fanCenter(before, long, true), b = fanCenter(after, long, true);
            verify(b.x > a.x && b.y < a.y);
            verify(Math.hypot(b.x - a.x, b.y - a.y) > long.iconSize);
            // The connecting chord follows the midpoint tangent. This also
            // catches separate, unrelated interpolation of position and tilt.
            fuzzyCompare(Math.atan2(b.x - a.x, a.y - b.y) * 180 / Math.PI, (before.rotation + after.rotation)
                         / 2, 0.00001);
        }
    }

    function test_fanLimitsExpandedExtent() {
        for (const size of [64, 84, 160]) {
            const layout = DockLayout.folderFan("bottom", 200, 1600, 1400, true, size);
            verify(layout.count <= 8);
            verify(layout.height <= 1400 * 0.75);
            verify(layout.count > 0);
        }
    }

    function test_smallSpacerUsesHalfAnIconSlot() {
        const kinds = ["app", "spacer", "small-spacer", "app"];
        const resting = DockLayout.layout(kinds, 48, 800, 2, 16, NaN);
        compare(resting.slots[1].span - resting.slots[2].span, 24);
        const small = DockLayout.layout(kinds, 48, 800, 2, 16, resting.slots[2].center);
        const regular = DockLayout.layout(kinds, 48, 800, 2, 16, resting.slots[1].center);
        compare(small.slots[2].size, regular.slots[1].size);
        compare(small.slots[2].span - 8, (regular.slots[1].span - 8) / 2);
        compare(small.slots[2].center, resting.slots[2].center);
        verifyOrdered(small);
        const preview = DockLayout.previewOrder(kinds, 2, 0, "small-spacer");
        compare(preview.kinds[0], "small-spacer");
        compare(preview.kinds.length, kinds.length);
    }

    function test_fanKeepsItsFootAtTheFolderNearOutputEdge() {
        for (const size of [64, 84, 160]) {
            for (const outset of [size / 2 + 14, size / 2 + 40, size / 2 + 100]) {
                const layout = DockLayout.folderFan("bottom", 200, 1000, 1400, true, size, outset);
                verify(layout.iconInset <= outset);
                verifyFanBounds(layout, true);
                verifyFanBounds(layout, false);
                const first = fanCenter(layout.slots[0], layout, true);
                fuzzyCompare(first.x, layout.width - layout.iconInset, 0.00001);
            }
        }
    }

    function test_fileSectionUsesSameLayoutAndDistinctDividers() {
        const kinds = ["app", "spacer", "app", "file", "folder", "trash"];
        const boundaries = DockLayout.sectionBoundaries(kinds, 2);
        compare(boundaries.join(","), "2,3");
        const result = DockLayout.layout(kinds, 48, 900, 1.5, 16, NaN, boundaries);
        compare(result.dividers.length, 2);
        verifyOrdered(result);
        compare(DockLayout.sectionBoundaries(["app", "folder", "trash"], 1).join(","), "1");
        compare(DockLayout.sectionBoundaries(["folder", "trash"], 0).length, 0);
        const preview = DockLayout.previewOrder(kinds, -1, 4, "folder");
        compare(DockLayout.sectionBoundaries(preview.kinds, 2, preview.order).join(","), "2,3");
    }

    function test_windowPreviewsAlwaysFitOneRow() {
        for (const available of [0, 8, 100, 600, 1920]) {
            let previous = Infinity;
            for (const count of [1, 2, 8, 40, 200]) {
                const row = DockLayout.windowPreviewRow(count, 272, available);
                verify(row.cardWidth >= 0 && row.cardWidth <= previous);
                verify(row.gap >= 0);
                verify(row.width <= available + 0.00001);
                fuzzyCompare(row.width, row.margin * 2 + count * row.cardWidth + (count - 1) * row.gap,
                             0.00001);
                previous = row.cardWidth;
            }
        }
        compare(DockLayout.windowPreviewRow(0, 272, 600).width, 0);
        compare(DockLayout.windowPreviewRow(1, 272, 600).cardWidth, 272);
        verify(DockLayout.windowPreviewRow(10, 272, 600).cardWidth < 160);
    }

    function test_sectionGapPreservesInsertionIndices() {
        const kinds = ["app", "app", "app"];
        const plain = DockLayout.layout(kinds, 48, 800, 1.5, 16, NaN);
        const divided = DockLayout.layout(kinds, 48, 800, 1.5, 16, NaN, 2);
        compare(divided.slots.length, kinds.length);
        compare(divided.length - plain.length, 24);
        compare(divided.slots[0].start, plain.slots[0].start);
        compare(divided.slots[2].start - plain.slots[2].start, 24);
        compare(DockLayout.insertionIndex(divided.slots, divided.divider), 2);
        const hovered = DockLayout.layout(kinds, 48, 800, 1.5, 16, divided.slots[1].center, 2);
        compare(hovered.slots[2].center, divided.slots[2].center);
        verify(hovered.divider > hovered.slots[1].start + hovered.slots[1].span);
        verify(hovered.divider < hovered.slots[2].start);
        verifyOrdered(hovered);
    }

    function test_sectionBoundaryFollowsDragGroups() {
        const kinds = ["app", "app", "app"];
        compare(DockLayout.sectionBoundary(kinds, 2), 2);
        compare(DockLayout.sectionBoundary(kinds, 0), -1);
        compare(DockLayout.sectionBoundary(kinds, 3), -1);
        compare(DockLayout.sectionBoundary(["app", "spacer", "app"], 2), 2);
        compare(DockLayout.sectionBoundary(["spacer", "app"], 1), -1);
        const outside = DockLayout.previewOrder(kinds, 0, -1, "app");
        compare(DockLayout.sectionBoundary(outside.kinds, 2, outside.order), 1);
        compare(DockLayout.sectionBoundary(outside.kinds, 1, outside.order), -1);
        const incoming = DockLayout.previewOrder(kinds, -1, 2, "app");
        compare(DockLayout.sectionBoundary(incoming.kinds, 2, incoming.order), 3);
        const firstPin = DockLayout.previewOrder(kinds, -1, 0, "app");
        compare(DockLayout.sectionBoundary(firstPin.kinds, 0, firstPin.order), 1);
    }

    function test_dragPreviewPreservesModelUntilDrop() {
        const kinds = ["app", "spacer", "app", "app"];
        const preview = DockLayout.previewOrder(kinds, 0, 3, "app");
        compare(preview.order.join(","), "1,2,-1,3");
        compare(preview.kinds.join(","), "spacer,app,app,app");
        compare(kinds.join(","), "app,spacer,app,app");
        // Returning to either side of the source restores the same gap.
        compare(DockLayout.previewOrder(kinds, 0, 0, "app").order.join(","), "-1,1,2,3");
        compare(DockLayout.previewOrder(kinds, 0, 1, "app").order.join(","), "-1,1,2,3");
    }

    function test_dragOutClosesGapAndCancelRestoresIt() {
        const kinds = ["app", "spacer", "app"];
        const outside = DockLayout.previewOrder(kinds, 1, -1, "spacer");
        compare(outside.kinds.join(","), "app,app");
        compare(outside.order.join(","), "0,2");
        const cancelled = DockLayout.previewOrder(kinds, -1, -1, "app");
        compare(cancelled.kinds.join(","), kinds.join(","));
        compare(cancelled.order.join(","), "0,1,2");
    }

    function test_externalPreviewReservesExactlyOneSlot() {
        const kinds = ["app", "app"];
        for (let gap = 0; gap <= kinds.length; ++gap) {
            const preview = DockLayout.previewOrder(kinds, -1, gap, "app");
            compare(preview.kinds.length, 3);
            compare(preview.order[gap], -1);
            compare(preview.order.filter(index => index >= 0).join(","), "0,1");
        }
        compare(DockLayout.previewOrder([], -1, 0, "app").order.join(","), "-1");
    }

    function verifyOrdered(result) {
        let end = 0;
        result.slots.forEach(slot => {
            verify(isFinite(slot.start));
            verify(isFinite(slot.span));
            verify(slot.span > 0);
            verify(slot.start >= end - 0.0001);
            end = slot.start + slot.span;
        });
        verify(result.length >= end);
    }

    function test_fitsWithoutExceedingPreferredSize_data() {
        return [
                    {
                        tag: "single",
                        kinds: ["app"],
                        preferred: 48,
                        available: 240,
                        maximum: 2
                    },
                    {
                        tag: "mixed",
                        kinds: ["app", "app", "spacer", "app", "app", "app"],
                        preferred: 64,
                        available: 600,
                        maximum: 2
                    },
                    {
                        tag: "compact",
                        kinds: ["app", "app", "app", "app", "app", "app"],
                        preferred: 80,
                        available: 600,
                        maximum: 1.5
                    },
                    {
                        tag: "large",
                        kinds: Array(16).fill("app"),
                        preferred: 80,
                        available: 1200,
                        maximum: 2
                    }
                ];
    }

    function test_fitsWithoutExceedingPreferredSize(data) {
        const resting = DockLayout.layout(data.kinds, data.preferred, data.available, data.maximum, 16, NaN);
        verify(!resting.overflow);
        verify(resting.size >= 32);
        verify(resting.size <= data.preferred);
        verify(resting.length <= data.available + 0.0001);
        verifyOrdered(resting);
        resting.slots.forEach(slot => {
            const hovered = DockLayout.layout(data.kinds, data.preferred, data.available, data.maximum, 16,
                                              slot.center);
            verify(hovered.length <= data.available + 0.0001);
            verify(!hovered.overflow);
            verifyOrdered(hovered);
        });
    }

    function test_shrinksUntilMinimumThenReportsOverflow() {
        const kinds = Array(6).fill("app");
        const spacious = DockLayout.layout(kinds, 80, 1200, 2, 16, NaN);
        const compact = DockLayout.layout(kinds, 80, 600, 2, 16, NaN);
        const crowded = DockLayout.layout(kinds, 80, 240, 2, 16, NaN);
        compare(spacious.size, 80);
        verify(compact.size < spacious.size);
        verify(compact.size > 32);
        verify(!compact.overflow);
        compare(crowded.size, 32);
        verify(crowded.overflow);
        verify(crowded.length > 240);
        verifyOrdered(crowded);
    }

    function test_waveStrengthPreservesCapacityAndInterpolatesGeometry() {
        const kinds = ["app", "small-spacer", "app", "app", "folder", "trash"];
        const boundaries = [3, 4];
        for (const available of [240, 600, 1200]) {
            const resting = DockLayout.layout(kinds, 80, available, 2, 16, NaN, boundaries);
            for (const target of resting.slots) {
                const full = DockLayout.layout(kinds, 80, available, 2, 16, target.center, boundaries);
                for (const strength of [0, 0.1, 0.5, 0.9, 1]) {
                    const wave = DockLayout.layout(kinds, 80, available, 2, 16, target.center, boundaries,
                                                   strength);
                    compare(wave.size, resting.size);
                    compare(wave.baseLength, resting.baseLength);
                    compare(wave.overflow, resting.overflow);
                    verifyOrdered(wave);
                    fuzzyCompare(wave.length, resting.length + strength * (full.length - resting.length),
                                 0.000001);
                    for (let i = 0; i < wave.slots.length; ++i) {
                        compare(wave.slots[i].center, resting.slots[i].center);
                        for (const field of ["size", "span", "start"])
                            fuzzyCompare(wave.slots[i][field], resting.slots[i][field] + strength * (
                                             full.slots[i][field] - resting.slots[i][field]), 0.000001);
                    }
                    for (let i = 0; i < wave.dividers.length; ++i)
                        fuzzyCompare(wave.dividers[i], resting.dividers[i] + strength * (full.dividers[i]
                                                                                         - resting.dividers[i]),
                                     0.000001);
                }
            }
        }
    }

    function test_overflowAccountsForHoverSpace() {
        const kinds = Array(6).fill("app");
        const resting = DockLayout.layout(kinds, 32, 300, 2, 16, NaN);
        verify(resting.baseLength < 300);
        verify(resting.overflow);
        const disabled = DockLayout.layout(kinds, 32, 300, 1, 16, NaN);
        verify(!disabled.overflow);
    }

    function test_pointerDoesNotMoveBaseCenters() {
        const kinds = ["app", "app", "spacer", "app", "app"];
        const resting = DockLayout.layout(kinds, 48, 800, 1.75, 20, NaN);
        resting.slots.forEach(target => {
            const hovered = DockLayout.layout(kinds, 48, 800, 1.75, 20, target.center);
            compare(hovered.size, resting.size);
            compare(hovered.baseLength, resting.baseLength);
            hovered.slots.forEach((slot, index) => {
                compare(slot.center, resting.slots[index].center);
            });
            verifyOrdered(hovered);
        });
    }

    function test_spacersUseApplicationSlotsAtEverySizeAndMagnification() {
        const kinds = ["spacer", "app", "spacer", "app", "spacer"];
        for (const available of [240, 600, 1200]) {
            for (const pointer of [NaN, 40, 100, 250]) {
                const mixed = DockLayout.layout(kinds, 80, available, 1.6, 16, pointer, 3);
                const apps = DockLayout.layout(kinds.map(() => "app"), 80, available, 1.6, 16, pointer, 3);
                compare(mixed, apps);
                verifyOrdered(mixed);
            }
        }
    }

    function test_emptyAndSpacerOnlyLayoutsStayFinite() {
        [[], ["spacer"], ["spacer", "spacer"]].forEach(kinds => {
            const result = DockLayout.layout(kinds, 48, 600, 2, 16, 100);
            compare(result.slots.length, kinds.length);
            verify(isFinite(result.size));
            verify(isFinite(result.length));
            verify(!result.overflow);
            verifyOrdered(result);
        });
    }

    function test_insertionUsesVisualSlotMidpoints() {
        const slots = [
                  {
                      start: 10,
                      span: 20
                  },
                  {
                      start: 30,
                      span: 60
                  },
                  {
                      start: 90,
                      span: 20
                  }
              ];
        compare(DockLayout.insertionIndex(slots, -100), 0);
        compare(DockLayout.insertionIndex(slots, 19), 0);
        compare(DockLayout.insertionIndex(slots, 21), 1);
        compare(DockLayout.insertionIndex(slots, 59), 1);
        compare(DockLayout.insertionIndex(slots, 61), 2);
        compare(DockLayout.insertionIndex(slots, 99), 2);
        compare(DockLayout.insertionIndex(slots, 101), 3);
        compare(DockLayout.insertionIndex(slots, 1000), 3);
        compare(DockLayout.insertionIndex([], 100), 0);
    }

    function test_removalDistanceMeasuresInwardFromDockEdge() {
        const width = 1200;
        const height = 800;
        const offset = 40;
        compare(DockLayout.removalDistance("left", offset, 300, width, height, offset), 0);
        compare(DockLayout.removalDistance("right", width - offset, 300, width, height, offset), 0);
        compare(DockLayout.removalDistance("bottom", 300, height - offset, width, height, offset), 0);
        compare(DockLayout.removalDistance("left", offset + 100, 5, width, height, offset), 100);
        compare(DockLayout.removalDistance("left", offset + 100, 700, width, height, offset), 100);
        compare(DockLayout.removalDistance("right", width - offset - 100, 5, width, height, offset), 100);
        compare(DockLayout.removalDistance("right", width - offset - 100, 700, width, height, offset), 100);
        compare(DockLayout.removalDistance("bottom", 5, height - offset - 100, width, height, offset), 100);
        compare(DockLayout.removalDistance("bottom", 1100, height - offset - 100, width, height, offset),
                100);


        verify(DockLayout.removalDistance("left", 0, 300, width, height, offset) < 0);
        verify(DockLayout.removalDistance("right", width, 300, width, height, offset) < 0);
        verify(DockLayout.removalDistance("bottom", 300, height, width, height, offset) < 0);
    }
}
