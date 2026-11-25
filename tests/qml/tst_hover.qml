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
    function test_keyboardNavigation() {
        tryCompare(dock, "status", Loader.Ready);
        dock.item.beginKeyboard();
        verify(dock.item.keyboardActive);
        compare(dock.item.keyboardItem.index, 0);
        keyClick(Qt.Key_Right);
        compare(dock.item.keyboardItem.index, 1);
        keyClick(Qt.Key_End);
        compare(dock.item.keyboardItem.index, 4);
        keyClick(Qt.Key_Right);
        compare(dock.item.keyboardItem.index, 0);
        keyClick(Qt.Key_Left);
        compare(dock.item.keyboardItem.index, 4);
        keyClick(Qt.Key_Home);
        compare(dock.item.keyboardItem.index, 0);
        keyClick(Qt.Key_Escape);
        verify(!dock.item.keyboardActive);
        dock.item.beginKeyboard();
        keyClick(Qt.Key_Return);
        verify(!dock.item.keyboardActive);
    }
    function test_keyboardContextMenu_data() {
        return [{tag: "Menu", key: Qt.Key_Menu, modifiers: Qt.NoModifier},
                {tag: "Shift-F10", key: Qt.Key_F10, modifiers: Qt.ShiftModifier}];
    }
    function test_keyboardContextMenu(data) {
        tryCompare(dock, "status", Loader.Ready);
        const menu = findChild(dock.item, "dockMenu");
        dock.item.beginKeyboard();
        keyClick(Qt.Key_Right);
        keyClick(data.key, data.modifiers);
        tryCompare(menu, "visibleMenu", true);
        menu.close();
        tryCompare(menu, "visibleMenu", false);
        compare(dock.item.keyboardItem.index, 1);
        dock.item.keyboardItem = null;
        // Offscreen QMenu dismissal does not restore the fixture window.
        testCase.Window.window.requestActivate();
        tryCompare(testCase.Window.window, "active", true);
    }
    function test_pointerMenuAnchor() {
        tryCompare(dock, "status", Loader.Ready);
        const menu = findChild(dock.item, "dockMenu");
        for (let edge = 0; edge < 4; ++edge) {
            testEnvironment.setEdge(edge);
            wait(30);
            const icon = findChild(dock.item, "icon0");
            const p = icon.mapToItem(dock.item, 3, 4);
            const click = Qt.point(Math.round(p.x), Math.round(p.y));
            mouseClick(dock.item, click.x, click.y, Qt.RightButton);
            tryCompare(menu, "visibleMenu", true);
            compare(menu.activeMenu.visualParent.mapToItem(dock.item, 0, 0), click);
            menu.close();
            tryCompare(menu, "visibleMenu", false);
            testCase.Window.window.requestActivate();
            tryCompare(testCase.Window.window, "active", true);
        }
        testEnvironment.setEdge(0);
    }
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
    function test_magnificationAlongPhysicalEdge() {
        tryCompare(dock, "status", Loader.Ready);
        const first = findChild(dock.item, "task0");
        const last = findChild(dock.item, "task4");
        const firstIcon = findChild(dock.item, "icon0");
        const lastIcon = findChild(dock.item, "icon4");
        mouseMove(dock.item, firstIcon.mapToItem(dock.item, firstIcon.width / 2, 0).x, dock.item.height - 1);
        tryVerify(() => first.size > 55);
        mouseMove(dock.item, lastIcon.mapToItem(dock.item, lastIcon.width / 2, 0).x, dock.item.height - 1);
        tryVerify(() => last.size > 55);
        mouseMove(testCase, 700, 250);
        tryCompare(last, "size", 40);
        verify(!dock.item.hovering);
    }
    function test_dragReordersWithoutActivating() {
        const source = findChild(dock.item, "taskSourceLoader");
        const handler = findChild(dock.item, "reorderHandler");
        source.source = Qt.resolvedUrl("MovableTasks.qml");
        tryCompare(source, "status", Loader.Ready);
        handler.enabled = true; // Exercise gestures with an inert model, no applications.
        wait(150); // Allow the replacement model's Row to position its delegates.
        const first = findChild(dock.item, "icon0");
        const last = findChild(dock.item, "icon4");
        const start = first.mapToItem(dock.item, first.width / 2, first.height / 2);
        const end = last.mapToItem(dock.item, last.width / 2, last.height / 2);
        mouseMove(dock.item, start.x, start.y);
        wait(120);
        mousePress(first, first.width / 2, first.height / 2, Qt.LeftButton);
        mouseMove(dock.item, start.x + 30, start.y, 30);
        mouseMove(dock.item, end.x, end.y, 150);
        verify(dock.item.dragDestination > dock.item.dragIndex);
        compare(source.item.moves, 0);
        compare(source.item.saves, 0);
        mouseRelease(dock.item, end.x, end.y, Qt.LeftButton);
        tryVerify(() => source.item.moves > 0);
        compare(source.item.activations, 0);
        compare(source.item.saves, 1);
        verify(!dock.item.dragging);
        handler.enabled = false;
        source.source = "qrc:/qml/DemoTasks.qml";
        tryCompare(source, "status", Loader.Ready);
        mouseMove(testCase, 700, 250);
    }
    function test_rightClickMenu() {
        tryCompare(dock, "status", Loader.Ready);
        const icon = findChild(dock.item, "icon0");
        const menu = findChild(dock.item, "dockMenu");
        mouseClick(icon, icon.width / 2, icon.height / 2, Qt.RightButton);
        tryCompare(menu, "visibleMenu", true);
        compare(menu.launcherUrl, ""); // Demo icons must never expose pin actions.
        menu.close();
        tryCompare(menu, "visibleMenu", false);
        mouseMove(testCase, 700, 250);
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
