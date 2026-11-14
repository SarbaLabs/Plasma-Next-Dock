// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../qml/code/AdaptiveLayout.js" as Adaptive

TestCase {
    name: "AdaptiveLayout"
    width: 1000; height: 800
    visible: true
    when: windowShown
    Loader { id: dock; source: "qrc:/qml/Main.qml" }
    function test_limitsAndMonotonicity() {
        for (const preferred of [24, 40, 96]) {
            for (const zoom of [1, 1.5, 2.5]) {
                let previous = preferred;
                for (let count = 0; count <= 100; ++count) {
                    const m = Adaptive.metrics(count, preferred, zoom, 984, 700, 8);
                    verify(m.base <= previous + 0.00001);
                    verify(m.base >= 24 && m.base <= preferred);
                    verify(m.length <= 984 && m.depth <= 700);
                    if (m.base > 24) {
                        // Resting strip plus the bounded local zoom budget fits.
                        verify(count * m.base + Math.min(count, 2) * m.base * (zoom - 1) + Math.max(0, count - 1) * 10 * m.scale + 24 * m.scale <= m.length + 0.001);
                    }
                    previous = m.base;
                }
            }
        }
        compare(Adaptive.metrics(5, 40, 1.5, 984, 700, 8).base, 40);
        // Eighteen icons fit at rest AND at maximum local magnification.
        compare(Adaptive.metrics(18, 40, 1.5, 984, 700, 8).base, 40);
        verify(Adaptive.metrics(22, 40, 1.5, 984, 700, 8).base > 24);
        const tiny = Adaptive.metrics(100, 96, 2.5, 60, 40, 128);
        verify(tiny.length <= 60 && tiny.depth <= 40 && tiny.base > 0);
        compare(Adaptive.scrollPosition(200, 100, 500, 300), 200);
        compare(Adaptive.scrollPosition(200, 0, 100, 300), 0);
        compare(Adaptive.scrollPosition(20, -100, 500, 300), 0);
    }
    function test_synthesizedWheel() {
        tryCompare(dock, "status", Loader.Ready);
        const tasks = findChild(dock.item, "taskSourceLoader").item.tasks;
        const viewport = findChild(dock.item, "taskViewport");
        const original = tasks.count;
        try {
            for (let i = original; i < 100; ++i)
                tasks.append({decoration: "folder", display: "Scroll", IsWindow: false, IsActive: false});
            wait(150);
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                wait(100);
                for (const pixels of [false, true]) {
                    for (const delta of [Qt.point(0, -120), Qt.point(-120, 0), Qt.point(-60, -120)]) {
                        viewport.contentX = 0;
                        const p = Qt.point(dock.item.width / 2, dock.item.height / 2);
                        testEnvironment.wheel(dock.item, p, delta, true, pixels);
                        const expected = pixels ? 120 : 60;
                        compare(viewport.contentX, expected, "One scroll for synthesized/diagonal input");
                        testEnvironment.wheel(dock.item, p, Qt.point(-delta.x, -delta.y), true, pixels);
                        compare(viewport.contentX, 0);
                    }
                }
            }
        } finally { tasks.remove(original, tasks.count - original); testEnvironment.setEdge(0); }
    }
    function test_wheelAcrossEdgesAndScrollOffsets() {
        tryCompare(dock, "status", Loader.Ready);
        const tasks = findChild(dock.item, "taskSourceLoader").item.tasks;
        const viewport = findChild(dock.item, "taskViewport");
        const original = tasks.count;
        try {
            for (let i = original; i < 100; ++i)
                tasks.append({decoration: "folder", display: "Scroll", IsWindow: false, IsActive: false});
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                wait(150);
                // First at the start, then after scrolling more than one viewport.
                for (const offset of [0, viewport.width * 1.5]) {
                    viewport.contentX = offset;
                    wait(100);
                    const x = dock.item.width / 2;
                    const y = dock.item.height / 2;
                    const before = viewport.contentX;
                    mouseWheel(dock.item, x, y, 0, -120);
                    tryVerify(() => viewport.contentX > before, 1000, "Wheel edge " + edge + " offset " + offset);
                }
            }
        } finally {
            tasks.remove(original, tasks.count - original);
            testEnvironment.setEdge(0);
        }
    }
    function test_liveCountShrinkAndRecovery() {
        tryCompare(dock, "status", Loader.Ready);
        const source = findChild(dock.item, "taskSourceLoader");
        const tasks = source.item.tasks;
        const viewport = findChild(dock.item, "taskViewport");
        const original = tasks.count;
        tryCompare(dock.item, "base", 40);
        for (let i = original; i < 22; ++i)
            tasks.append({decoration: "folder", display: "Extra", IsWindow: false, IsActive: false});
        tryVerify(() => dock.item.base < 40 && dock.item.base > 24);
        verify(dock.item.barThickness < 60);
        const first = findChild(dock.item, "task0");
        dock.item.hovering = true;
        dock.item.pointerIndex = 0;
        tryVerify(() => first.size > dock.item.base);
        verify(first.size <= dock.item.maximum + 0.001);
        // Simulate animation tails at distant icons without changing count/output.
        const next = findChild(dock.item, "task1");
        const third = findChild(dock.item, "task2");
        first.animatedFactor = 1; next.animatedFactor = 1; third.animatedFactor = 1;
        tryVerify(() => dock.item.animatedWeight >= 2.99);
        verify(dock.item.animatedWeight * dock.item.zoomBudgetScale <= 2.001);
        for (let i = tasks.count; i < 80; ++i)
            tasks.append({decoration: "folder", display: "Overflow", IsWindow: false, IsActive: false});
        tryCompare(dock.item, "base", 24);
        tryVerify(() => viewport.contentWidth > viewport.width);
        mouseWheel(viewport, viewport.width / 2, viewport.height / 2, 0, -120);
        tryVerify(() => viewport.contentX > 0);
        viewport.contentX = viewport.contentWidth - viewport.width;
        const last = findChild(dock.item, "icon79");
        tryVerify(() => last.mapToItem(dock.item, 0, 0).x < dock.item.width);
        tasks.remove(original, tasks.count - original);
        tryCompare(dock.item, "base", 40);
        tryCompare(viewport, "contentX", 0);
        compare(dockOptions.iconSize, 40);
        dock.item.hovering = false;
    }
}
