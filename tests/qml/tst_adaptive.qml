// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../qml/code/AdaptiveLayout.js" as Adaptive

TestCase {
    name: "AdaptiveLayout"
    width: 1000; height: 800
    visible: true
    when: windowShown
    Loader {
        id: dock
        property var dockModules: ({entries: [{popup: true}]})
        source: "qrc:/qml/Main.qml"
    }
    function test_modulePopupGap() {
        const root = dock.item;
        const changes = {zoom: 1, spacing: 0, freeLayout: true, capsuleThickness: 8, iconOffset: 14};
        const saved = {};
        for (const key of Object.keys(changes)) saved[key] = dockOptions[key];
        try {
            testEnvironment.behaviorOptions(changes);
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                for (const spacing of [0, 16, 128]) {
                    testEnvironment.behaviorOptions({spacing: spacing});
                    compare(root.modulePopupDepth - root.reservedThickness, spacing);
                    verify(root.modulePopupDepth < (root.vertical ? root.width : root.height));
                    compare(root.vertical ? root.interactionBounds.width : root.interactionBounds.height, root.canvasDepth);
                    compare(root.vertical ? root.dodgeBounds.width : root.dodgeBounds.height, root.reservedThickness);
                }
            }
        } finally {
            testEnvironment.behaviorOptions(saved);
            testEnvironment.setEdge(0);
        }
    }
    function test_fractionalZoomKeepsPhysicalEdge() {
        const root = dock.item;
        const capsule = findChild(root, "capsuleBackground");
        const changes = {zoom: 1.72, iconSize: 40, spacing: 0, edge: 0, extendDock: true, freeLayout: false};
        const saved = {};
        for (const key of Object.keys(changes)) saved[key] = dockOptions[key];
        try {
            for (const edge of [0, 3]) {
                testEnvironment.behaviorOptions(Object.assign({}, changes, {edge: edge}));
                const extent = root.vertical ? root.width : root.height;
                compare(extent, Math.floor(extent));
                compare(root.vertical ? capsule.x + capsule.width : capsule.y + capsule.height, extent);
            }
        } finally { testEnvironment.behaviorOptions(saved); }
    }
    function test_reservationEndsAtVisibleContent() {
        const root = dock.item;
        const changes = {edge: 0, extendDock: true, spacing: 0, freeLayout: false,
            borderWidth: 1, borderOpacity: 0, borderRole: "custom", borderColor: "#222222",
            capsuleThickness: 4, iconOffset: 16};
        const saved = {};
        for (const key of Object.keys(changes)) saved[key] = dockOptions[key];
        try {
            testEnvironment.behaviorOptions(changes);
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.behaviorOptions({edge: edge, freeLayout: false, borderOpacity: 0});
                compare(root.reservedThickness, Math.ceil(root.barThickness));
                testEnvironment.behaviorOptions({borderOpacity: 1});
                compare(root.reservedThickness, Math.ceil(root.barThickness + 1));
                testEnvironment.behaviorOptions({freeLayout: true});
                verify(root.iconEdge + root.base > root.barThickness + 1);
                compare(root.reservedThickness, Math.ceil(root.iconEdge + root.base));
            }
        } finally { testEnvironment.behaviorOptions(saved); }
    }
    function test_initialCanvasIncludesTasks() {
        // Inspect the component before queued row-count notifications can run.
        dock.active = false;
        dock.active = true;
        compare(dock.status, Loader.Ready);
        const tasks = findChild(dock.item, "taskSourceLoader").item.tasks;
        verify(tasks.count > 0);
        compare(dock.item.layoutCount, tasks.count);
    }
    function test_capsuleResizesBeforeRowPolish() {
        tryCompare(dock, "status", Loader.Ready);
        const root = dock.item;
        const capsule = findChild(root, "capsuleBackground");
        const original = dockOptions.iconSize;
        try {
            for (const size of [52, 28, 64]) {
                testEnvironment.behaviorOptions({iconSize: size});
                const count = root.layoutCount;
                const expected = count * root.base + (count - 1) * (dockOptions.iconSpacing ?? 10) * root.fitScale
                    + 2 * root.endPadding;
                fuzzyCompare(root.vertical ? capsule.height : capsule.width, Math.min(expected, root.length), 0.01);
            }
        } finally { testEnvironment.behaviorOptions({iconSize: original}); }
    }
    function test_radiusBudgetAndLift() {
        for (let r = 0; r <= 8; ++r) {
            for (let p = 0; p < 1; p += 0.05) {
                let total = 0;
                for (let i = -10; i <= 10; ++i) total += Adaptive.hoverWeight(p - i, r);
                verify(total <= Adaptive.zoomBudget(r) + 0.00001);
            }
            compare(Adaptive.hoverWeight(r + 1, r), 0);
            if (r > 0) verify(Adaptive.hoverWeight(r, r) > 0);
            const m = Adaptive.metrics(40, 40, 1.5, 984, 120, 8, 10, 12, 10, r, 64);
            verify(m.depth <= 120 && m.length <= 984);
        }
        fuzzyCompare(Adaptive.hoverWeight(1, 2), Math.pow(1 - 1 / 2.4, 2), 0.00001);
    }
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
    function test_customPaddingAcrossEdges() {
        tryCompare(dock, "status", Loader.Ready);
        try {
            for (const gap of [0, 18, 64]) {
                for (const ends of [0, 25, 128]) {
                    for (const thickness of [0, 16, 64]) {
                        const m = Adaptive.metrics(22, 40, 1.5, 984, 700, 8, gap, ends, thickness);
                        verify(m.length <= 984 && m.depth <= 700);
                        if (m.base > 24)
                            verify(22 * m.base + 2 * m.base * 0.5 + (21 * gap + 2 * ends) * m.scale <= m.length + 0.001);
                    }
                }
            }
            dock.item.hovering = false;
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                for (const values of [[0, 0, 0], [18, 25, 16], [18, 0, 30], [5, 35, 0]]) {
                    testEnvironment.layoutOptions(values[0], values[1], values[2]);
                    wait(120);
                    const capsule = findChild(dock.item, "capsuleBackground");
                    const first = findChild(dock.item, "icon0");
                    const second = findChild(dock.item, "icon1");
                    const p = first.mapToItem(capsule, 0, 0);
                    const q = second.mapToItem(capsule, 0, 0);
                    const gap = values[0] * dock.item.fitScale;
                    const ends = values[1] * dock.item.fitScale;
                    const thickness = values[2] * dock.item.fitScale;
                    fuzzyCompare(edge < 2 ? p.x : p.y, ends, 0.01);
                    fuzzyCompare(edge < 2 ? p.y : p.x, thickness, 0.01);
                    fuzzyCompare((edge < 2 ? q.x - p.x : q.y - p.y) - dock.item.base, gap, 0.01);
                    fuzzyCompare(edge < 2 ? capsule.height : capsule.width, dock.item.base + 2 * thickness, 0.01);
                }
            }
        } finally {
            testEnvironment.layoutOptions(10, 12, 10);
            testEnvironment.setEdge(0);
        }
    }
    function test_freeLayoutAcrossEdges() {
        const root = dock.item;
        const capsule = findChild(root, "capsuleBackground");
        const icon = findChild(root, "icon0");
        const lane = findChild(root, "taskInput0");
        try {
            root.hovering = false;
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                for (const [thickness, offset] of [[4, 46], [90, 46], [72, 0], [4, 0], [90, -3], [4, -256]]) {
                    testEnvironment.behaviorOptions({freeLayout: true, capsuleThickness: thickness, iconOffset: offset});
                    wait(60);
                    const t = thickness * root.fitScale;
                    fuzzyCompare(root.vertical ? capsule.width : capsule.height, t, 0.01);
                    const bounds = icon.mapToItem(capsule, Qt.rect(0, 0, icon.width, icon.height));
                    const inward = [t - bounds.y - bounds.height, bounds.y, bounds.x, t - bounds.x - bounds.width][edge];
                    fuzzyCompare(inward, Math.max(-root.edgeSpacing, offset), 0.1);
                    const hit = icon.mapToItem(lane, icon.width / 2, icon.height / 2);
                    verify(lane.contains(hit));
                    const reservation = root.reservedThickness;
                    const footprint = root.dodgeBounds;
                    fuzzyCompare(root.vertical ? footprint.y : footprint.x, root.barStart, 0.01);
                    fuzzyCompare(root.vertical ? footprint.height : footprint.width, root.barLength, 0.01);
                    compare(root.vertical ? footprint.width : footprint.height, reservation);
                    root.pointerIndex = 0;
                    root.hovering = true;
                    wait(120);
                    compare(root.reservedThickness, reservation);
                    compare(root.dodgeBounds, footprint);
                    root.hovering = false;
                    wait(120);
                }
            }
        } finally {
            testEnvironment.behaviorOptions({freeLayout: false, capsuleThickness: 60, iconOffset: 0});
            testEnvironment.setEdge(0);
        }
    }
    function test_freeIndicatorAnchor() {
        const root = dock.item;
        const tasks = findChild(root, "taskSourceLoader").item.tasks;
        const bar = findChild(root, "capsuleBackground");
        const changes = {freeLayout: true, capsuleThickness: 4, iconOffset: 48, verticalPadding: 64,
            indicatorAnimations: false, taskDecorations: 2, indicatorMode: 2, indicatorOverride: true,
            indicatorEdge: 1, indicatorEdgeDistance: 17, indicatorStyle: 2};
        const saved = {};
        for (const key of Object.keys(changes)) saved[key] = dockOptions[key];
        const running = tasks.get(0).IsWindow;
        try {
            tasks.setProperty(0, "IsWindow", true);
            testEnvironment.behaviorOptions(changes);
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                for (const mode of [0, 1, 2]) {
                    testEnvironment.behaviorOptions({indicatorMode: mode});
                    const name = ["macIndicator0", "nativeIndicatorStrip", "indicatorSegment0"][mode];
                    const owner = mode === 0 ? root : findChild(root, "dockIndicators0");
                    tryVerify(() => !!findChild(owner, name));
                    const marker = findChild(owner, name);
                    for (const distance of [5, 21]) {
                        testEnvironment.behaviorOptions({iconOffset: distance * 2,
                            verticalPadding: distance, indicatorEdgeDistance: distance});
                        wait(25);
                        const bounds = marker.mapToItem(bar, Qt.rect(0, 0, marker.width, marker.height));
                        const inset = [bar.height - bounds.y - bounds.height, bounds.y,
                            bounds.x, bar.width - bounds.x - bounds.width][edge];
                        fuzzyCompare(inset, mode === 2 ? distance : 0, 0.01);
                    }
                }
            }
        } finally {
            tasks.setProperty(0, "IsWindow", running);
            testEnvironment.behaviorOptions(saved);
            testEnvironment.setEdge(0);
        }
    }
    function test_splitExtendedDock() {
        const root = dock.item;
        const tasks = findChild(root, "taskSourceLoader").item.tasks;
        const viewport = findChild(root, "taskViewport");
        const original = tasks.count;
        const changes = {extendDock: true, splitExtendedDock: true, dockAlignment: 1, alignmentMargin: 16, zoom: 1};
        const saved = {};
        for (const key of Object.keys(changes)) saved[key] = dockOptions[key];
        try {
            testEnvironment.behaviorOptions(changes);
            tasks.setProperty(0, "dockZone", -1);
            tasks.setProperty(original - 1, "dockZone", 1);
            tryCompare(root, "leadingCount", 1);
            tryCompare(root, "trailingCount", 1);
            const first = findChild(root, "task0");
            const center = findChild(root, "task2");
            const last = findChild(root, "task" + (original - 1));
            const divider = findChild(root, "zoneSeparator0");
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                const axis = item => {
                    const point = item.mapToItem(root, item.width / 2, item.height / 2);
                    return root.vertical ? point.y : point.x;
                };
                const length = root.vertical ? root.height : root.width;
                tryVerify(() => Math.abs(axis(center) - length / 2) < 1);
                verify(Math.abs(axis(first) - (16 + root.endPadding + root.base / 2)) < 1);
                verify(Math.abs(length - axis(last) - axis(first)) < 1);
                verify(!divider.visible);
                const leftModule = axis(first), rightModule = axis(last);
                for (const align of [0, 2, 1]) {
                    testEnvironment.behaviorOptions({dockAlignment: align});
                    const firstPin = findChild(root, "task1");
                    const lastPin = findChild(root, "task3");
                    if (align === 1) tryVerify(() => Math.abs(axis(center) - length / 2) < 1);
                    else {
                        const pin = align === 0 ? firstPin : lastPin;
                        const boundary = viewport.mapToItem(root, align === 0 ? 0 : viewport.width, viewport.height / 2);
                        const expected = (root.vertical ? boundary.y : boundary.x) + (align === 0 ? 1 : -1) * pin.width / 2;
                        tryVerify(() => Math.abs(axis(pin) - expected) < 1);
                    }
                    compare(axis(first), leftModule);
                    compare(axis(last), rightModule);
                    compare(divider.visible, align === 0);
                    compare(findChild(root, "zoneSeparator1").visible, align === 2);
                }

                for (let i = 0; i < 50; ++i)
                    tasks.insert(1, {decoration: "folder", display: "Pinned", dockZone: 0});
                tryVerify(() => viewport.contentWidth > viewport.width && divider.visible);
                const left = axis(first), right = axis(last), pin = axis(center);
                viewport.contentX = 50;
                compare(axis(first), left);
                compare(axis(last), right);
                compare(axis(center), pin - 50);
                tasks.remove(1, 50);
                tryCompare(viewport, "contentX", 0);
            }
        } finally {
            if (tasks.count > original) tasks.remove(1, tasks.count - original);
            tasks.setProperty(0, "dockZone", 0);
            tasks.setProperty(original - 1, "dockZone", 0);
            testEnvironment.behaviorOptions(saved);
            testEnvironment.setEdge(0);
        }
    }
    function test_pinAcrossZones_data() {
        return [{tag: "center", alignment: 1}, {tag: "right", alignment: 2}];
    }
    function test_pinAcrossZones(data) {
        const root = dock.item;
        const tasks = findChild(root, "taskSourceLoader").item.tasks;
        const view = findChild(root, "taskViewport");
        const changes = {extendDock: true, splitExtendedDock: true, dockAlignment: data.alignment, zoom: 1, edge: 0};
        const saved = {};
        for (const key of Object.keys(changes)) saved[key] = dockOptions[key];
        try {
            testEnvironment.behaviorOptions(changes);
            tasks.setProperty(0, "dockZone", -1);
            tasks.setProperty(3, "dockZone", 1);
            tasks.setProperty(4, "dockZone", 1);
            tryCompare(root, "trailingCount", 2);
            tasks.move(3, 4, 1);
            wait(50);
            const gap = ((dockOptions.iconSpacing ?? 10) + 6) * root.fitScale;
            const rightEdge = () => view.mapToItem(root, view.width, 0).x;
            verify(Math.abs(findChild(root, "task3").mapToItem(root, 0, 0).x - rightEdge() - gap) < 1);
            // Pin the running application, then replace the boundary delegate as
            // the task model reconciles launcher order without changing its size.
            tasks.move(3, 1, 1);
            tasks.setProperty(1, "dockZone", 0);
            tryCompare(root, "trailingCount", 1);
            const replacement = Object.assign({}, tasks.get(4));
            tasks.remove(4);
            tasks.append(replacement);
            wait(50);
            const firstPin = findChild(root, "task1");
            const lastPin = findChild(root, "task3");
            const firstX = firstPin.mapToItem(view, 0, 0).x;
            const endX = lastPin.mapToItem(view, lastPin.width, 0).x;
            verify(firstX >= -0.01 && endX <= view.width + 0.01);
            const lastModule = findChild(root, "task4");
            verify(Math.abs(lastModule.mapToItem(root, 0, 0).x - view.mapToItem(root, view.width, 0).x
                - ((dockOptions.iconSpacing ?? 10) + 6) * root.fitScale) < 1);
        } finally {
            tasks.move(1, 3, 1);
            tasks.move(4, 3, 1);
            for (let i = 0; i < tasks.count; ++i) tasks.setProperty(i, "dockZone", 0);
            testEnvironment.behaviorOptions(saved);
        }
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
