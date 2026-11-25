// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    id: testCase
    name: "ApplicationsMenu"
    when: windowShown
    width: 640
    height: 480
    visible: true
    Loader { id: loader; anchors.fill: parent; active: false; source: appMenuUrl }
    SignalSpy { id: updates; signalName: "edited" }
    function init() {
        width = 640;
        loader.active = true;
        tryCompare(loader, "status", Loader.Ready);
        updates.target = loader.item;
        updates.clear();
    }
    function cleanup() { loader.active = false; }

    Timer { id: releaseDrag; interval: 120; onTriggered: mouseRelease(testCase, width / 2, height / 2) }
    function test_dragSurvivesSourceRemoval() {
        loader.item.configuration = {favorites:["First.desktop"]};
        const view = findChild(loader.item, "menuContents");
        tryVerify(() => view.currentItem?.applicationId === "First.desktop");
        const tile = view.currentItem;
        // A pin can retire this entire popup while the platform drag still
        // owns the pointer. Let deferred deletion run before ending the drag.
        tile.consumedPressChanged.connect(() => Qt.callLater(() => {
            loader.active = false;
            releaseDrag.restart();
        }));
        mousePress(tile, 8, 12);
        mouseMove(tile, 32, 12);
        mouseMove(tile, 54, 12);
        tryCompare(loader, "active", false);
        tryCompare(releaseDrag, "running", false);
    }

    function test_favoriteOrder_data() { return [{tag:"grid", grid:true}, {tag:"list", grid:false}]; }
    function test_favoriteOrder(data) {
        const page = loader.item;
        const view = findChild(page, "menuContents");
        page.configuration = {favorites:["Second.desktop", "First.desktop"], favoritesGrid:data.grid};
        compare(view.interactive, false);
        page.moveFavorite("First.desktop", "Second.desktop");
        compare(updates.count, 1);
        compare(updates.signalArguments[0][0].favorites, ["First.desktop", "Second.desktop"]);
        page.enter({group:true, id:"@all"});
        page.moveFavorite("First.desktop", "Second.desktop");
        compare(updates.count, 1);
        compare(view.model.model.map(row => row.id).filter(id => ["First.desktop", "Second.desktop"].includes(id)),
                ["First.desktop", "Second.desktop"]);
    }

    function test_pinFromMenu() {
        const page = loader.item;
        let pinned = "";
        page.launcherActions = {
            pinned: url => pinned === url.toString(),
            togglePinned: url => { pinned = pinned === url.toString() ? "" : url.toString(); }
        };
        page.configuration = {favorites:["First.desktop"]};
        const view = findChild(page, "menuContents");
        tryVerify(() => view.currentItem?.applicationId === "First.desktop");
        const tile = view.currentItem;
        const action = findChild(page, "menuPinAction");
        tile.context();
        const firstLabel = action.text;
        action.triggered();
        compare(pinned, "applications:First.desktop");
        tile.context();
        verify(action.text !== firstLabel);
        action.triggered();
        compare(pinned, "");
        compare(updates.count, 0);
    }

    function test_plasmaSearch() {
        const page = loader.item;
        const field = findChild(page, "menuSearch");
        const view = findChild(page, "menuContents");
        page.configuration = {favorites:["Second.desktop"]};
        compare(view.model.model[0].id, "Second.desktop");
        testEnvironment.configureSearchFixture(true);
        field.text = "First";
        tryVerify(() => page.searching && !!view.model.model);
        tryVerify(() => {
            for (let i = 0; i < view.count; ++i) {
                if (view.itemAtIndex(i)?.applicationId === "First.desktop") return true;
            }
            return false;
        });
        field.clear();
        tryVerify(() => page.favoritesPage && view.currentItem?.applicationId === "Second.desktop");
        testEnvironment.configureSearchFixture(false);
        field.text = "First";
        tryVerify(() => !!view.model.model && !view.model.model.querying && view.count === 0);
    }

    function test_sessionBreakpoints() {
        const bar = findChild(loader.item, "sessionBar");
        const personal = findChild(bar, "sessionActions");
        const power = findChild(bar, "powerActions");
        tryVerify(() => power.directWidth > power.groupedWidth && personal.directWidth > personal.groupedWidth);
        const margin = width - bar.width;
        const wide = Math.ceil(margin + power.directWidth + personal.directWidth);
        width = wide + 2;
        tryCompare(personal, "compact", false);
        compare(power.compact, false);
        width = Math.ceil(margin + power.directWidth + personal.groupedWidth);
        tryCompare(personal, "compact", true);
        compare(power.compact, false);
        width -= 5;
        tryCompare(power, "compact", true);
        width = wide + 2;
        tryCompare(power, "compact", false);
        compare(personal.compact, false);
    }

    function test_nestedNavigation() {
        const page = loader.item;
        const view = findChild(page, "menuContents");
        page.configuration = {favorites:["Second.desktop"], favoritesGrid:true, categoryGrid:false, format:3};
        verify(page.favoritesPage);
        compare(view.model.model[0].name, "Second");
        verify(page.grid);
        const internet = page.group("", false).find(row => row.name === "Internet");
        verify(!!internet);
        page.enter(internet);
        verify(!page.grid);
        const browsers = view.model.model.find(row => row.name === "Browsers");
        verify(!!browsers, JSON.stringify({internet:internet,rows:view.model.model}));
        page.enter(browsers);
        compare(view.model.model[0].name, "First");
        compare(page.history.length, 2);
        page.back();
        compare(view.model.model[0].id, browsers.id);
    }
}
