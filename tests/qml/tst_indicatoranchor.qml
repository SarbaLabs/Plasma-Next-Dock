// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest

TestCase {
    id: test
    name: "IndicatorAnchor"
    width: 1100; height: 800
    visible: true
    when: windowShown
    Loader { id: dock; source: "qrc:/qml/Main.qml" }
    function cleanup() {
        dock.item.hovering = false;
        testEnvironment.setEdge(0);
        testEnvironment.indicatorOptions(0);
    }
    function test_crossAxisStaysFixedDuringZoom_data() {
        const rows = [];
        for (let edge = 0; edge < 4; ++edge)
            for (let mode of [1, 2]) rows.push({tag: "edge" + edge + "mode" + mode, edge: edge, mode: mode});
        return rows;
    }
    function test_crossAxisStaysFixedDuringZoom(data) {
        tryCompare(dock, "status", Loader.Ready);
        testEnvironment.setEdge(data.edge);
        testEnvironment.indicatorOptions(data.mode);
        const source = findChild(dock.item, "taskSourceLoader");
        source.item.tasks.setProperty(2, "IsWindow", true);
        const slot = findChild(dock.item, "task2");
        const indicator = findChild(dock.item, "dockIndicators2");
        dock.item.hovering = false;
        tryCompare(slot, "size", 40);
        const name = data.mode === 2 ? "indicatorSegment0" : "nativeIndicatorStrip";
        tryVerify(() => findChild(indicator, name) !== null);
        const segment = findChild(indicator, name);
        wait(150); // Settle the intentional indicator state animation first.
        const before = segment.mapToItem(dock.item, 0, 0);
        const cross = data.edge < 2 ? before.y : before.x;
        dock.item.pointerIndex = 2;
        dock.item.hovering = true;
        // Sample intermediate frames: the regression was transient, not merely
        // a wrong final position after the two animations had both settled.
        for (let i = 0; i < 12; ++i) {
            wait(16);
            const point = segment.mapToItem(dock.item, 0, 0);
            fuzzyCompare(data.edge < 2 ? point.y : point.x, cross, 0.01);
        }
        verify(slot.size > 55, "Icon actually magnified during this check");
        dock.item.hovering = false;
        for (let i = 0; i < 12; ++i) {
            wait(16);
            const point = segment.mapToItem(dock.item, 0, 0);
            fuzzyCompare(data.edge < 2 ? point.y : point.x, cross, 0.01);
        }
        tryCompare(slot, "size", 40);
    }
}
