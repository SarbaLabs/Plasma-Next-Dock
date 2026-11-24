// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest

TestCase {
    id: test
    name: "ModuleEditor"
    when: windowShown
    visible: true
    width: 600; height: 240
    QtObject {
        id: profile
        property var values: ({moduleZones: {left: [], disabled: [], right: ["a"]}})
        function apply(changes) { values = changes; }
    }
    function test_dragAcrossAndWithinColumns() {
        const page = createTemporaryObject(Qt.createComponent("qrc:/qml/ModulesSettings.qml"), test,
            {width: width, height: height, profile: profile, catalog: {a: {name: "A"}, b: {name: "B"}, c: {name: "C"}}});
        verify(page);
        const left = findChild(page, "moduleColumn0"), off = findChild(page, "moduleColumn1");
        const right = findChild(page, "moduleColumn2");
        function drag(from, row, to, y) {
            tryVerify(() => from.itemAtIndex(row) !== null);
            const start = from.itemAtIndex(row).mapToItem(page, 12, 18);
            const end = to.mapToItem(page, 15, y);
            mouseDrag(page, start.x, start.y, end.x-start.x, end.y-start.y, Qt.LeftButton);
        }
        drag(off, 0, left, 10);
        tryCompare(left, "count", 1);
        compare(profile.values.moduleZones.left, ["b"]);
        drag(right, 0, left, 5);
        tryCompare(left, "count", 2);
        compare(profile.values.moduleZones.left, ["a", "b"]);
        drag(left, 0, left, 95);
        tryVerify(() => profile.values.moduleZones.left[0] === "b");
        drag(left, 1, off, 5);
        tryCompare(off, "count", 2);
        compare(profile.values.moduleZones.disabled, ["a", "c"]);
    }
}
