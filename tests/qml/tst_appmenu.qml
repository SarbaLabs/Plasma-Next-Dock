// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    name: "ApplicationsMenu"
    when: windowShown
    width: 640
    height: 480
    visible: true
    Loader { id: loader; anchors.fill: parent; active: false; source: appMenuUrl }
    function test_nestedNavigation() {
        loader.active = true;
        tryCompare(loader, "status", Loader.Ready);
        const page = loader.item;
        const view = findChild(page, "menuContents");
        page.configuration = {favorites:["Second.desktop"], favoritesGrid:true, categoryGrid:false, format:3};
        verify(page.favoritesPage);
        compare(view.model[0].name, "Second");
        verify(page.grid);
        const internet = page.group("", false).find(row => row.name === "Internet");
        verify(!!internet);
        page.enter(internet);
        verify(!page.grid);
        const browsers = view.model.find(row => row.name === "Browsers");
        verify(!!browsers, JSON.stringify({internet:internet,rows:view.model}));
        page.enter(browsers);
        compare(view.model[0].name, "First");
        compare(page.history.length, 2);
        page.back();
        compare(view.model[0].id, browsers.id);
        loader.active = false;
    }
}
