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
    function test_oneWheelEventPerWindow() {
        // Cover angle-only, pixel-only AND combined events, including small deltas.
        // The previous implementation still accumulated combined/pixel input.
        for (const amount of [1, 15, 40, 60, 120, 240]) {
            compare(Behavior.wheelCycle(amount, 0), -1);
            compare(Behavior.wheelCycle(-amount, 0), 1);
            compare(Behavior.wheelCycle(0, amount), -1);
            compare(Behavior.wheelCycle(0, -amount), 1);
            compare(Behavior.wheelCycle(amount, 10), -1);
            compare(Behavior.wheelCycle(-amount, -10), 1);
        }
        compare(Behavior.wheelCycle(0, 0), 0);
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
}
