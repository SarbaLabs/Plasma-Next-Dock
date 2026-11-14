// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtTest
import org.kde.plasma.core as PlasmaCore
TestCase {
    id: test
    name: "WindowPreviews"
    width: 800; height: 400
    visible: true
    when: windowShown
    Loader { id: dock; source: "qrc:/qml/Main.qml" }
    function cleanup() {
        const panel = findChild(dock.item, "taskPreview");
        if (panel) panel.dismiss();
        testEnvironment.setEdge(0);
    }
    function test_explicitInwardLocationAllEdges() {
        tryCompare(dock, "status", Loader.Ready);
        const expected = [PlasmaCore.Types.BottomEdge, PlasmaCore.Types.TopEdge, PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge];
        for (let edge = 0; edge < 4; ++edge) {
            testEnvironment.setEdge(edge);
            const tip = findChild(dock.item, "taskTip0");
            compare(tip.location, expected[edge]);
        }
    }
    function test_switchingTooltipOwnerUpdatesName() {
        tryCompare(dock, "status", Loader.Ready);
        const first = findChild(dock.item, "taskTip0");
        const last = findChild(dock.item, "taskTip4");
        const panel = findChild(dock.item, "taskPreview");
        first.showToolTip();
        tryCompare(panel, "displayed", true);
        compare(panel.applicationName, "Files");
        verify(!panel.mediaAvailable);
        verify(panel.implicitWidth < 260);
        panel.status = {player: {canControl: true}, streams: []};
        verify(panel.mediaAvailable);
        verify(panel.implicitWidth >= 260);
        compare(panel.toolTip, first);
        last.showToolTip();
        tryCompare(panel, "displayed", true);
        compare(panel.applicationName, "Settings");
        compare(panel.toolTip, last);
        panel.dismiss();
        tryCompare(panel, "displayed", false);
    }
    function test_groupCardsRouteToIndividualWindows() {
        tryCompare(dock, "status", Loader.Ready);
        const owner = findChild(dock.item, "taskTip0");
        const panel = findChild(dock.item, "taskPreview");
        owner.showToolTip();
        tryCompare(panel, "displayed", true);
        windowPreviews.select(testPreviewModel, 0);
        compare(windowPreviews.count, 2);
        panel.windowsEnabled = false;
        compare(panel.visibleWindows, 0);
        panel.windowsEnabled = true;
        compare(panel.visibleWindows, 2);
        tryVerify(() => findChild(panel, "previewClose1") !== null);
        const closeButton = findChild(panel, "previewClose1");
        closeButton.clicked();
        compare(testEnvironment.closedPreview(), "Second window");
        const activateButton = findChild(panel, "previewActivate0");
        activateButton.clicked();
        compare(testEnvironment.activatedPreview(), "First window");
        tryCompare(panel, "displayed", false);
        tryCompare(windowPreviews, "count", 0);
    }
    function test_nativeThumbnailComponentLoads() {
        const component = Qt.createComponent("qrc:/qml/WindowThumbnail.qml");
        compare(component.status, Component.Ready, component.errorString());
        // No compositor UUID: validate real imports without requesting a capture.
        const thumbnail = component.createObject(test);
        verify(thumbnail !== null, component.errorString());
        compare(thumbnail.windowId, "");
        thumbnail.destroy();
    }
}
