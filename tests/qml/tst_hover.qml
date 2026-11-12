// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtTest
TestCase {
    id: testCase
    name: "StandaloneHover"
    width: 800; height: 300
    visible: true
    when: windowShown
    Rectangle { anchors.fill: parent; color: "#ff00ff"; z: -1 }
    Loader { id: dock; source: "qrc:/qml/Main.qml" }
    function initTestCase() { testCase.Window.window.color = "transparent"; }
    function test_magnificationContinuesAndResets() {
        tryCompare(dock, "status", Loader.Ready);
        const first = findChild(dock.item, "task0");
        const last = findChild(dock.item, "task4");
        verify(first !== null && last !== null);
        const firstIcon = findChild(dock.item, "icon0");
        const lastIcon = findChild(dock.item, "icon4");
        mouseMove(firstIcon, firstIcon.width / 2, firstIcon.height / 2);
        tryVerify(() => first.size > 55);
        const initial = dock.item.pointerIndex;
        mouseMove(lastIcon, lastIcon.width / 2, lastIcon.height / 2);
        tryVerify(() => dock.item.pointerIndex > initial + 2);
        tryVerify(() => last.size > 55);
        verify(lastIcon.mapToItem(dock.item, 0, 0).y >= 0, "Magnified icon remains in drawing surface");
        mouseMove(testCase, 700, 250);
        tryCompare(first, "size", 40);
        tryCompare(last, "size", 40);
        verify(!dock.item.hovering);
    }
    function test_transparentDrawingMargin() {
        tryCompare(dock, "status", Loader.Ready);
        mouseMove(testCase, 700, 250);
        wait(150);
        const shot = grabImage(dock.item);
        compare(shot.red(0, 0), 255);
        compare(shot.green(0, 0), 0);
        compare(shot.blue(0, 0), 255);
        verify(shot.green(Math.floor(dock.item.width / 2), dock.item.height - 35) > 0);
    }
}
