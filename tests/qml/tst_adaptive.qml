// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../qml/code/AdaptiveLayout.js" as Adaptive

TestCase {
    name: "AdaptiveLayout"
    width: 1000; height: 300
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
                        // Even simultaneous full zoom fits; animation tails cannot clip.
                        verify(count * m.base * zoom + Math.max(0, count - 1) * 10 * m.scale + 24 * m.scale <= m.length + 0.001);
                    }
                    previous = m.base;
                }
            }
        }
        compare(Adaptive.metrics(5, 40, 1.5, 984, 700, 8).base, 40);
        const tiny = Adaptive.metrics(100, 96, 2.5, 60, 40, 128);
        verify(tiny.length <= 60 && tiny.depth <= 40 && tiny.base > 0);
        compare(Adaptive.scrollPosition(200, 100, 500, 300), 200);
        compare(Adaptive.scrollPosition(200, 0, 100, 300), 0);
        compare(Adaptive.scrollPosition(20, -100, 500, 300), 0);
    }
    function test_liveCountShrinkAndRecovery() {
        tryCompare(dock, "status", Loader.Ready);
        const source = findChild(dock.item, "taskSourceLoader");
        const tasks = source.item.tasks;
        const viewport = findChild(dock.item, "taskViewport");
        const original = tasks.count;
        tryCompare(dock.item, "base", 40);
        for (let i = original; i < 18; ++i)
            tasks.append({decoration: "folder", display: "Extra", IsWindow: false, IsActive: false});
        tryVerify(() => dock.item.base < 40 && dock.item.base > 24);
        verify(dock.item.barThickness < 60);
        const first = findChild(dock.item, "task0");
        dock.item.hovering = true;
        dock.item.pointerIndex = 0;
        tryVerify(() => first.size > dock.item.base);
        verify(first.size <= dock.item.maximum + 0.001);
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
