// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../qml/code/TaskBehavior.js" as Behavior
import "../../qml/code/AdaptiveLayout.js" as Adaptive
TestCase {
    name: "TaskBehavior"
    width: 1000; height: 800
    visible: true
    when: windowShown
    Loader { id: dock; source: "qrc:/qml/Main.qml" }
    function test_boundaryAndDirection() {
        for (const flags of [[], [true], [false], [true,true], [false,false], [false,true], [true,false,true]])
            compare(Behavior.boundary(flags), -1);
        compare(Behavior.boundary([true,true,false,false]), 2);
        compare(Behavior.reversed(0, false, true), true);
        compare(Behavior.reversed(0, true, true), false);
        compare(Behavior.reversed(1, false, true), false);
        compare(Behavior.reversed(2, true, false), true);
        const normal = Adaptive.metrics(20,40,1.5,984,700,8);
        const divided = Adaptive.metrics(20,40,1.5,984,700,8,10,12,10,2,0,12);
        verify(divided.scale < normal.scale);
        verify(divided.length <= 984);
    }
    function test_oneWheelEventPerWindow() {
        // A lower wheel speed must not require multiple notches for one action.
        for (const amount of [15, 40, 60, 120, 240]) {
            compare(Behavior.wheelCycle(amount, 0, 0), {direction: -1, remainder: 0});
            compare(Behavior.wheelCycle(-amount, 0, 0), {direction: 1, remainder: 0});
        }
        compare(Behavior.wheelCycle(0, 0, 20).direction, 0);
        let remainder = 0;
        for (let i = 0; i < 3; ++i) {
            const step = Behavior.wheelCycle(0, 10, remainder);
            compare(step.direction, 0); remainder = step.remainder;
        }
        compare(Behavior.wheelCycle(0, 10, remainder), {direction: -1, remainder: 0});
        compare(Behavior.wheelCycle(0, -10, 30), {direction: 0, remainder: -10});
        compare(Behavior.wheelCycle(0, -80, 0), {direction: 1, remainder: 0});
    }
    function test_nativeActionRouting() {
        const roles = {active: "active", minimized: "minimized", minimizable: "minimizable", closable: "closable"};
        const leaves = [{active: false, minimized: false}, {active: true, minimized: false}, {active: false, minimized: true}];
        let calls = [];
        const model = {
            makeModelIndex: (row, child) => ({valid: row === 0, row: child === undefined ? row : child, child: child !== undefined}),
            rowCount: () => leaves.length,
            data: (index, role) => index.child ? leaves[index.row][role] : ({active: true, minimizable: true, closable: true})[role],
            requestActivate: index => calls.push(["activate",index.row]),
            requestToggleMinimized: index => calls.push(["minimize",index.row]),
            requestClose: index => calls.push(["close",index.row]),
            requestNewInstance: index => calls.push(["new",index.row])
        };
        Behavior.cycle(model,0,1,true,roles); compare(calls.pop(), ["activate",0]);
        Behavior.cycle(model,0,1,false,roles); compare(calls.pop(), ["activate",2]);
        Behavior.cycle(model,0,-1,true,roles); compare(calls.pop(), ["activate",0]);
        leaves.forEach(x => x.minimized = true);
        compare(Behavior.cycle(model,0,1,true,roles),false);
        Behavior.primary(model,0,true,roles); compare(calls.pop(), ["minimize",0]);
        Behavior.primary(model,0,false,roles); compare(calls.pop(), ["activate",0]);
        Behavior.middle(model,0,0,roles); compare(calls.length,0);
        Behavior.middle(model,0,1,roles); compare(calls.pop(), ["new",0]);
        Behavior.middle(model,0,2,roles); compare(calls.pop(), ["close",0]);
        Behavior.middle(model,0,3,roles); compare(calls.pop(), ["minimize",0]);
        Behavior.primary(model,99,true,roles); compare(calls.length,0);
    }
    function test_separatorAllEdgesAndDirections() {
        tryCompare(dock,"status",Loader.Ready);
        const tasks = findChild(dock.item,"taskSourceLoader").item.tasks;
        dock.item.hovering = false;
        try {
            for (let i=0;i<tasks.count;++i) tasks.setProperty(i,"HasLauncher",i<2);
            tryCompare(dock.item,"dividerIndex",2);
            for (let edge=0;edge<4;++edge) {
                testEnvironment.setEdge(edge);
                for (const direction of [1,2]) {
                    testEnvironment.behaviorOptions({layoutDirection:direction,showSeparator:true});
                    wait(150);
                    const a = findChild(dock.item,"icon1");
                    const b = findChild(dock.item,"icon2");
                    const separator = findChild(dock.item,"taskSeparator2");
                    verify(separator.visible);
                    const p=a.mapToItem(dock.item,a.width/2,a.height/2);
                    const q=b.mapToItem(dock.item,b.width/2,b.height/2);
                    const s=separator.mapToItem(dock.item,separator.width/2,separator.height/2);
                    const x=edge<2?p.x:p.y, y=edge<2?q.x:q.y, z=edge<2?s.x:s.y;
                    verify(z>Math.min(x,y) && z<Math.max(x,y), "Separator between groups edge "+edge+" direction "+direction);
                    compare(x<y,direction===1);
                    dock.item.updatePointer(b.mapToItem(dock.item,b.width/2,b.height/2));
                    fuzzyCompare(dock.item.pointerIndex,2,0.01);
                    dock.item.hovering = true;
                    wait(150);
                    const magnified = separator.mapToItem(dock.item, separator.width/2, separator.height/2);
                    fuzzyCompare(edge<2?magnified.y:magnified.x, edge<2?s.y:s.x, 0.01);
                    dock.item.hovering = false;
                    wait(150);
                }
            }
            tasks.setProperty(1,"HasLauncher",false);
            tasks.setProperty(1,"IsWindow",true);
            tryCompare(dock.item,"dividerIndex",1);
            tasks.setProperty(1,"HasLauncher",true);
            tryCompare(dock.item,"dividerIndex",2);
            testEnvironment.behaviorOptions({showSeparator:false});
            tryCompare(dock.item,"dividerSpan",0);
            for (let i=0;i<tasks.count;++i) tasks.setProperty(i,"HasLauncher",true);
            tryCompare(dock.item,"dividerIndex",-1);
            for (let i=0;i<tasks.count;++i) tasks.setProperty(i,"HasLauncher",false);
            tryCompare(dock.item,"dividerIndex",-1);
        } finally {
            for (let i=0;i<tasks.count;++i) tasks.setProperty(i,"HasLauncher",false);
            tasks.setProperty(1,"IsWindow",false);
            dock.item.hovering = false;
            testEnvironment.behaviorOptions({layoutDirection:0,showSeparator:true});
            testEnvironment.setEdge(0);
        }
    }
}
