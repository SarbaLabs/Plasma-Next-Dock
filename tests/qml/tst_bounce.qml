// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../qml/code/AdaptiveLayout.js" as Adaptive
TestCase {
    name: "IconBounce"
    width: 1000; height: 800; visible: true
    when: windowShown
    Loader { id: dock; source: "qrc:/qml/Main.qml" }
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
