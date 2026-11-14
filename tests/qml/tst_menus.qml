// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    id: test
    name: "PlasmaContextMenus"
    width: 600; height: 400
    visible: true
    when: windowShown
    Loader { id: loader; source: "qrc:/qml/ContextMenu.qml" }
    QtObject {
        id: source
        property var tasks: testMenuModel
        property bool isPinned: true
        property int toggles: 0
        function pinned(url) { return isPinned; }
        function togglePinned(url) { isPinned = !isPinned; toggles++; }
    }
    function init() {
        testEnvironment.language("en");
        testEnvironment.menuFixture(testLauncherUrls[0]);
        source.isPinned = true;
        source.toggles = 0;
        tryCompare(loader, "status", Loader.Ready);
    }
    function cleanup() { loader.item.close(); testEnvironment.language("en"); }
    function test_desktopActionsAppearWithoutEmptySections() {
        loader.item.showAt(Qt.point(100, 100), source, 0);
        tryCompare(loader.item, "visibleMenu", true);
        const texts = testEnvironment.menuTexts();
        verify(texts.indexOf("New Private Window") >= 0, JSON.stringify(texts));
        verify(texts.indexOf("Recent Files") < 0);
        verify(texts.indexOf("Places") < 0);
        verify(texts.indexOf("Actions") < 0); // No redundant heading for actions alone.
    }
    function test_nativePinAndUnpin() {
        loader.item.showAt(Qt.point(100, 100), source, 0);
        tryCompare(loader.item, "visibleMenu", true);
        verify(testEnvironment.menuTexts().indexOf("Unpin from Dock") >= 0);
        verify(testEnvironment.clickMenu("Unpin from Dock"));
        compare(source.toggles, 1);
        loader.item.showAt(Qt.point(150, 100), source, 0);
        verify(testEnvironment.menuTexts().indexOf("Pin to Dock") >= 0);
        verify(testEnvironment.clickMenu("Pin to Dock"));
        compare(source.toggles, 2);
    }
    function test_frenchProjectCatalogAndKdeLabels() {
        if (!testEnvironment.translationLocaleAvailable()) {
            skip("GNU gettext requires an installed non-C locale for this translation check");
            return;
        }
        testEnvironment.language("fr");
        loader.item.showAt(Qt.point(100, 100), source, 0);
        tryCompare(loader.item, "visibleMenu", true);
        verify(testEnvironment.menuTexts().indexOf("Détacher du dock") >= 0, JSON.stringify(testEnvironment.menuTexts()));
        verify(testEnvironment.menuTexts().indexOf("Configurer Plasma Next Dock…") >= 0);
        const current = i18ndc("plasma_applet_org.kde.plasma.taskmanager", "@title:group for section of menu items", "Recent Files");
        const expected = current === "Recent Files" ? i18nd("plasma_applet_org.kde.plasma.taskmanager", "Recent Files") : current;
        compare(loader.item.kde("@title:group for section of menu items", "Recent Files"), expected);
    }
    function test_kdeFrenchCatalog() {
        if (!testEnvironment.translationLocaleAvailable() || !testEnvironment.kdeFrenchAvailable()) {
            skip("French KDE catalog or non-C locale unavailable");
            return;
        }
        testEnvironment.language("fr");
        verify(loader.item.kde("@title:group for section of menu items", "Recent Files") !== "Recent Files");
        verify(loader.item.kde("@title:group for section of menu items", "Actions").length > 0);
    }
    function test_targetDisappearsAndBackgroundMenu() {
        loader.item.showAt(Qt.point(100, 100), source, 0);
        tryCompare(loader.item, "visibleMenu", true);
        testEnvironment.removeMenuTask();
        tryCompare(loader.item, "visibleMenu", false);
        loader.item.showAt(Qt.point(100, 100), null, -1);
        tryCompare(loader.item, "visibleMenu", true);
        const texts = testEnvironment.menuTexts().filter(t => t.length > 0);
        compare(texts.length, 2);
        verify(texts.indexOf("Configure Plasma Next Dock…") >= 0);
        verify(texts.indexOf("Quit Plasma Next Dock") >= 0);
    }
    function test_windowMenuStructure() {
        testEnvironment.menuFixture(testLauncherUrls[0], true);
        loader.item.showAt(Qt.point(100, 100), source, 0);
        tryCompare(loader.item, "visibleMenu", true);
        const texts = testEnvironment.menuTexts();
        verify(texts.indexOf("More") >= 0);
        verify(texts.indexOf("Close") >= 0);
        verify(texts.indexOf("Unpin from Dock") >= 0);
    }
}
