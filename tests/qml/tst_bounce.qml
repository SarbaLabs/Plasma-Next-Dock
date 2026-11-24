// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../qml/code/AdaptiveLayout.js" as Adaptive
TestCase {
    name: "IconBounce"
    width: 1000; height: 800; visible: true
    when: windowShown
    Loader { id: dock; source: "qrc:/qml/Main.qml" }
    SignalSpy { id: widthSpy; target: dock.item; signalName: "widthChanged" }
    SignalSpy { id: heightSpy; target: dock.item; signalName: "heightChanged" }
    function init() { dock.active = false; dock.active = true; tryCompare(dock, "status", Loader.Ready); }
    function test_hoverAcrossIconAndTooltip() {
        testEnvironment.behaviorOptions({iconHoverHighlight: true, indicatorMode: 1});
        for (let edge = 0; edge < 4; ++edge) {
            testEnvironment.setEdge(edge);
            mouseMove(this, 990, 790);
            wait(150);
            const lane = findChild(dock.item, "taskInput0");
            const icon = findChild(dock.item, "icon0");
            const indicators = findChild(dock.item, "dockIndicators0");
            const p = lane.mapToItem(dock.item, lane.width / 2, edge === 1 || edge === 3 ? 1 : lane.height - 1);
            mouseMove(dock.item, p.x, p.y);
            tryCompare(icon, "active", true);
            wait(150);
            for (const fraction of [0.9, 0.5, 0.1]) {
                const q = icon.mapToItem(dock.item, icon.width / 2, icon.height * fraction);
                mouseMove(dock.item, q.x, q.y);
                wait(40);
                compare(icon.active, true, "Icon hover must survive tooltip hit testing");
                compare(indicators.hovered, true);
            }
        }
    }
    function test_hoverAcrossGaps_data() {
        const cases = [];
        for (const free of [false, true])
            for (let edge = 0; edge < 4; ++edge)
                cases.push({tag: (free ? "free-" : "centered-") + edge, free, edge});
        return cases;
    }
    function test_hoverAcrossGaps(data) {
        const root = dock.item;
        const first = findChild(root, "task0"), next = findChild(root, "task1");
        const saved = {};
        const options = {freeLayout: data.free, capsuleThickness: 4, iconOffset: 48,
                         iconSpacing: 24, zoom: 2, bounceEnabled: false};
        for (const key of Object.keys(options)) saved[key] = dockOptions[key];
        try {
            testEnvironment.setEdge(data.edge);
            testEnvironment.behaviorOptions(options);
            mouseMove(this, 990, 790);
            wait(150);
            mouseMove(first.iconItem, first.size / 2, first.size / 2);
            tryVerify(() => first.size > root.maximum - 2);
            const gap = first.inputItem.mapToItem(root,
                first.size + 12 * root.fitScale,
                data.edge === 1 || data.edge === 3 ? first.inputItem.height - 3 : 3);
            const capsule = findChild(root, "capsuleBackground");
            verify(!capsule.contains(capsule.mapFromItem(root, gap.x, gap.y)));
            compare(root.taskAt(gap, false), -1);
            mouseMove(root, gap.x, gap.y);
            wait(180);
            verify(root.hovering, "A gap above the capsule must retain hover");
            verify(first.size > root.base || next.size > root.base);
            mouseMove(next.iconItem, next.size / 2, next.size / 2);
            tryVerify(() => next.size > root.base);
            mouseMove(this, 990, 790);
            tryCompare(root, "hovering", false);
            tryCompare(next, "size", root.base);
        } finally {
            testEnvironment.behaviorOptions(saved);
            testEnvironment.setEdge(0);
        }
    }
    function test_hoverHighlightToggle() {
        testEnvironment.setEdge(0);
        testEnvironment.behaviorOptions({iconHoverHighlight: true});
        mouseMove(this, 990, 790);
        wait(150);
        const lane = findChild(dock.item, "taskInput0");
        const icon = findChild(dock.item, "icon0");
        verify(lane && icon);
        testEnvironment.behaviorOptions({iconHoverHighlight: true});
        const point = lane.mapToItem(dock.item, lane.width / 2, lane.height - 1);
        mouseMove(dock.item, point.x, point.y);
        tryCompare(icon, "active", true);
        testEnvironment.behaviorOptions({iconHoverHighlight: false});
        tryCompare(icon, "active", false);
        testEnvironment.behaviorOptions({iconHoverHighlight: true});
        tryCompare(icon, "active", true);
        mouseMove(this, 990, 790);
        tryCompare(icon, "active", false);
    }
    function test_edgeLaneClicksAndReplacement() {
        tryCompare(dock, "status", Loader.Ready);
        const source = findChild(dock.item, "taskSourceLoader");
        source.source = Qt.resolvedUrl("LaunchingTasks.qml");
        tryCompare(source, "status", Loader.Ready);
        try {
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                testEnvironment.behaviorOptions({bounceHeight: 48, hoverLift: 32, bounceCount: 1});
                mouseMove(this, 990, 790);
                wait(150);
                let slot = findChild(dock.item, "task0");
                let lane = findChild(dock.item, "taskInput0");
                // Local axis is rotated with the strip; select the physical edge.
                let p = lane.mapToItem(dock.item, lane.width / 2, (edge === 1 || edge === 3) ? 1 : lane.height - 1);
                mouseMove(dock.item, p.x, p.y);
                wait(150);
                lane = findChild(dock.item, "taskInput0");
                p = lane.mapToItem(dock.item, lane.width / 2, (edge === 1 || edge === 3) ? 1 : lane.height - 1);
                mouseMove(dock.item, p.x, p.y);
                wait(120);
                const count = source.item.activations;
                compare(dock.item.taskAt(p, false), 0);
                mouseClick(dock.item, p.x, p.y, Qt.LeftButton);
                compare(source.item.activations, count + 1);
                let bounce = findChild(dock.item, "taskBounce0");
                tryVerify(() => bounce.offset > 5);
                wait(120); // Click synthesis updates the logical hover position once.
                for (let frame = 0; frame < 6; ++frame) {
                    wait(20);
                    verify(dock.item.hovering);
                    verify(slot.size > dock.item.base + 10, "Bounce must not reset magnification");
                    compare(dock.item.taskAt(p, false), 0);
                }
                const middle = findChild(lane, "middleClick0");
                middle.enabled = true; // Inert fixture, no real applications.
                const middleCount = source.item.middleClicks;
                mouseClick(dock.item, p.x, p.y, Qt.MiddleButton);
                compare(source.item.middleClicks, middleCount + 1);
                bounce.stop();
                // Replace the clicked delegate synchronously as a native
                // launcher/startup/window transition can do during activation.
                source.item.replaceOnLaunch = true;
                const previousSize = slot.size;
                widthSpy.clear(); heightSpy.clear();
                mouseClick(dock.item, p.x, p.y, Qt.LeftButton);
                slot = findChild(dock.item, "task0");
                fuzzyCompare(slot.size, previousSize, 0.05, "Replacement preserves visible zoom immediately");
                fuzzyCompare(slot.animatedFactor, slot.factor, 0.001,
                    "Replacement initializes at the current zoom, not at zero");
                wait(30);
                compare(widthSpy.count, 0, "Replacement must not resize the surface");
                compare(heightSpy.count, 0, "Replacement must not resize the surface");
                slot = findChild(dock.item, "task0");
                bounce = findChild(dock.item, "taskBounce0");
                verify(dock.item.hovering);
                verify(slot.size > dock.item.base);
                tryVerify(() => bounce.offset > 5);
                compare(findChild(dock.item, "taskBounce1").running, false);
                bounce.stop();
                source.item.replaceOnLaunch = false;
            }
        } finally {
            source.source = "qrc:/qml/DemoTasks.qml";
            testEnvironment.behaviorOptions({bounceHeight: 0, hoverLift: 0, bounceCount: 3});
            testEnvironment.setEdge(0);
            mouseMove(this, 990, 790);
        }
    }
    function test_stationaryPointerBelowBouncingIcon() {
        const source = findChild(dock.item, "taskSourceLoader");
        source.source = Qt.resolvedUrl("LaunchingTasks.qml");
        tryCompare(source, "status", Loader.Ready);
        try {
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                testEnvironment.behaviorOptions({bounceHeight: 48, hoverLift: 0, bounceCount: 1});
                mouseMove(this, 990, 790); wait(150);
                const slot = findChild(dock.item, "task0");
                const icon = findChild(dock.item, "icon0");
                const lane = findChild(dock.item, "taskInput0");
                mouseMove(icon, icon.width / 2, icon.height / 2); wait(150);
                const middle = findChild(lane, "middleClick0"); middle.enabled = true;
                // Upright icon coordinates: just inside its outward edge.
                const p = edge === 0 ? Qt.point(icon.width / 2, icon.height - 2)
                    : edge === 1 ? Qt.point(icon.width / 2, 2)
                    : edge === 2 ? Qt.point(2, icon.height / 2) : Qt.point(icon.width - 2, icon.height / 2);
                const fixed = icon.mapToItem(dock.item, p.x, p.y);
                mouseMove(dock.item, fixed.x, fixed.y); wait(150);
                mouseClick(dock.item, fixed.x, fixed.y, Qt.MiddleButton);
                const logicalPosition = dock.item.pointerIndex;
                const bounce = findChild(dock.item, "taskBounce0");
                let crossed = false;
                for (let frame = 0; frame < 20; ++frame) {
                    wait(16);
                    const local = icon.mapFromItem(dock.item, fixed.x, fixed.y);
                    if (local.x < 0 || local.y < 0 || local.x >= icon.width || local.y >= icon.height) crossed = true;
                    verify(dock.item.hovering, "Moving icon must not end surface hover");
                    compare(dock.item.pointerIndex, logicalPosition, "Geometry must not move the logical pointer");
                    verify(slot.size > dock.item.base + 10);
                }
                verify(crossed, "Exercise the icon moving past the stationary cursor");
                bounce.stop();
                mouseMove(this, 990, 790);
                tryCompare(slot, "size", dock.item.base);
            }
        } finally {
            source.source = "qrc:/qml/DemoTasks.qml";
            testEnvironment.behaviorOptions({bounceHeight: 0, hoverLift: 0, bounceCount: 3});
            testEnvironment.setEdge(0);
            mouseMove(this, 990, 790);
        }
    }
    function test_launchRowMovePreservesZoom() {
        const source = findChild(dock.item, "taskSourceLoader");
        source.source = Qt.resolvedUrl("LaunchingTasks.qml");
        tryCompare(source, "status", Loader.Ready);
        try {
            wait(100);
            const slot = findChild(dock.item, "task0");
            const icon = findChild(dock.item, "icon0");
            mouseMove(icon, icon.width / 2, icon.height / 2);
            wait(150);
            const size = slot.size;
            source.item.launchRequested(0);
            // Native launch/startup/window proxies can remap rows while the
            // cursor remains still. Follow the application, not its old row.
            source.item.tasks.move(0, 1, 1);
            wait(130);
            fuzzyCompare(slot.size, size, 0.05);
            // Replacement may also return at another row, in a separate model event.
            source.item.tasks.remove(1);
            source.item.tasks.insert(0, {display: "Window", decoration: "folder", LauncherUrl: "applications:One.desktop", IsWindow: true});
            wait(1); // Flush queued model reconciliation, not a zoom transition.
            const replacement = findChild(dock.item, "task0");
            fuzzyCompare(replacement.size, size, 0.05);
            const other = findChild(dock.item, "icon2");
            mouseMove(other, other.width / 2, other.height / 2);
            wait(150);
            verify(replacement.size < size - 5, "Real movement must release the retained application anchor");
        } finally {
            source.source = "qrc:/qml/DemoTasks.qml";
            mouseMove(this, 990, 790);
        }
    }
    function test_lifecycle() {
        const component = Qt.createComponent("qrc:/qml/TaskBounce.qml");
        compare(component.status, Component.Ready, component.errorString());
        const bounce = createTemporaryObject(component, this, {amplitude: 24, speed: 200, repetitions: 1});
        verify(bounce !== null);
        bounce.test();
        tryVerify(() => bounce.offset > 0);
        verify(bounce.offset <= 24);
        tryCompare(bounce, "running", false, 1500);
        compare(bounce.offset, 0);
        bounce.attention = true;
        tryCompare(bounce, "running", true);
        wait(600);
        compare(bounce.running, true); // Attention repeats beyond a finite launch.
        bounce.attention = false;
        tryCompare(bounce, "running", false);
        compare(bounce.offset, 0);
        bounce.launch();
        tryVerify(() => bounce.offset > 0);
        bounce.suspended = true;
        tryCompare(bounce, "offset", 0);
        compare(bounce.running, false);
        bounce.attention = true;
        bounce.suspended = false;
        tryCompare(bounce, "running", true);
        bounce.animationsEnabled = false;
        tryCompare(bounce, "running", false);
        compare(bounce.offset, 0);
        bounce.test(); compare(bounce.running, false);
        bounce.attention = false;
        bounce.animationsEnabled = true;
        bounce.launchEnabled = false;
        bounce.launch(); compare(bounce.running, false);
        bounce.launchEnabled = true;
        bounce.startup = true;
        tryCompare(bounce, "running", true);
        bounce.stop();
    }
    function test_allEdgesReserveAndStationaryIndicators() {
        tryCompare(dock, "status", Loader.Ready);
        try {
            dock.item.hovering = true;
            dock.item.pointerIndex = 0;
            for (let edge=0; edge<4; ++edge) {
                testEnvironment.setEdge(edge);
                testEnvironment.behaviorOptions({bounceEnabled:true, bounceHeight:48, bounceSpeed:100, bounceCount:1, hoverLift:32, indicatorMode:2});
                wait(150);
                const bounce = findChild(dock.item, "taskBounce0");
                const icon = findChild(dock.item, "icon0");
                const indicator = findChild(dock.item, "dockIndicators0");
                const bar = findChild(dock.item, "capsuleBackground");
                const lane = findChild(dock.item, "taskInput0");
                // Wait for zoom to settle before measuring bounce-only movement.
                // A fixed delay can sample one remaining frame under CI load.
                tryVerify(() => {
                    for (let i = 0; ; ++i) {
                        const slot = findChild(dock.item, "task" + i);
                        if (!slot) return true;
                        if (Math.abs(slot.animatedFactor - slot.factor) > 0.00001) return false;
                    }
                });
                const hitRect = lane.mapToItem(dock.item, Qt.rect(0, 0, lane.width, lane.height));
                const origin = icon.mapToItem(dock.item, 0, 0);
                const anchor = indicator.mapToItem(dock.item, 0, 0);
                const capsule = Qt.rect(bar.x,bar.y,bar.width,bar.height);
                bounce.test();
                tryVerify(() => bounce.offset > 5);
                for (let frame=0; frame<12; ++frame) {
                    wait(20);
                    const p = icon.mapToItem(dock.item, 0, 0);
                    verify(p.x >= -0.01 && p.y >= -0.01);
                    verify(p.x+icon.width <= dock.item.width+0.01);
                    verify(p.y+icon.height <= dock.item.height+0.01);
                    fuzzyCompare(edge<2?p.x:p.y, edge<2?origin.x:origin.y, 0.01);
                    const a = indicator.mapToItem(dock.item,0,0);
                    fuzzyCompare(a.x,anchor.x,0.01); fuzzyCompare(a.y,anchor.y,0.01);
                    compare(Qt.rect(bar.x,bar.y,bar.width,bar.height),capsule);
                    compare(lane.mapToItem(dock.item, Qt.rect(0, 0, lane.width, lane.height)), hitRect);
                    if(edge===0) verify(p.y<=origin.y+0.01);
                    if(edge===1) verify(p.y>=origin.y-0.01);
                    if(edge===2) verify(p.x>=origin.x-0.01);
                    if(edge===3) verify(p.x<=origin.x+0.01);
                }
                bounce.stop();
            }
            const tiny = Adaptive.metrics(80,96,2.5,600,100,8,10,12,10,8,64,64);
            verify(tiny.depth<=100 && tiny.length<=600);
        } finally {
            dock.item.hovering=false;
            testEnvironment.behaviorOptions({bounceEnabled:true,bounceHeight:0,bounceSpeed:100,bounceCount:3,hoverLift:0,indicatorMode:0});
            testEnvironment.setEdge(0);
        }
    }
}
