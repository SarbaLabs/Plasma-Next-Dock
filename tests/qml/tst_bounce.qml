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
    function test_edgeLaneClicksAndReplacement() {
        tryCompare(dock, "status", Loader.Ready);
        const source = findChild(dock.item, "taskSourceLoader");
        source.source = Qt.resolvedUrl("LaunchingTasks.qml");
        tryCompare(source, "status", Loader.Ready);
        try {
            for (let edge = 0; edge < 4; ++edge) {
                for (let direction = 1; direction <= 2; ++direction) {
                    testEnvironment.setEdge(edge);
                    testEnvironment.behaviorOptions({layoutDirection: direction, bounceHeight: 48, hoverLift: 32, bounceCount: 1});
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
                    widthSpy.clear(); heightSpy.clear();
                    mouseClick(dock.item, p.x, p.y, Qt.LeftButton);
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
            }
        } finally {
            source.source = "qrc:/qml/DemoTasks.qml";
            testEnvironment.behaviorOptions({layoutDirection: 0, bounceHeight: 0, hoverLift: 0, bounceCount: 3});
            testEnvironment.setEdge(0);
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
            const tiny = Adaptive.metrics(80,96,2.5,600,100,8,10,12,10,8,64,12,64);
            verify(tiny.depth<=100 && tiny.length<=600);
        } finally {
            dock.item.hovering=false;
            testEnvironment.behaviorOptions({bounceEnabled:true,bounceHeight:0,bounceSpeed:100,bounceCount:3,hoverLift:0,indicatorMode:0});
            testEnvironment.setEdge(0);
        }
    }
}
