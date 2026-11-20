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
    function test_documentDragChoosesSecondWindow() {
        tryCompare(dock, "status", Loader.Ready);
        const panel = findChild(dock.item, "taskPreview");
        const owner = findChild(dock.item, "taskTip0");
        panel.showForDrag(owner);
        tryCompare(panel, "displayed", true);
        windowPreviews.select(testPreviewModel, 0);
        const area = findChild(panel, "previewDocumentDrag");
        tryVerify(() => area.enabled && findChild(panel, "previewActivate1") !== null);
        const first = findChild(panel, "previewActivate0");
        const second = findChild(panel, "previewActivate1");
        tryVerify(() => second.width > 0 && second.mapToItem(area, 0, 0).x >= first.width);
        const p = first.mapToItem(area, first.width / 2, first.height / 2);
        const q = second.mapToItem(area, second.width / 2, second.height / 2);
        const urls = ["file:///tmp/document.txt"];
        verify(testEnvironment.externalDrag(area, p, urls, 0));
        verify(testEnvironment.externalDrag(area, q, urls, 1));
        compare(area.candidate.index, 1);
        tryVerify(() => testEnvironment.activatedPreview() === "Second window");
        verify(panel.displayed && area.containsDrag);
        verify(testEnvironment.externalDrag(area, p, urls, 1));
        tryVerify(() => testEnvironment.activatedPreview() === "First window");
        verify(panel.displayed && area.containsDrag);
        verify(testEnvironment.externalDrag(area, q, urls, 1));
        testEnvironment.externalDrag(area, q, urls, 3);
        wait(400);
        compare(testEnvironment.activatedPreview(), "First window");
        tryCompare(panel, "displayed", false);
    }
    function test_keyboardChoosesGroupMember() {
        tryCompare(dock, "status", Loader.Ready);
        dock.item.beginKeyboard();
        const owner = dock.item.keyboardItem.previewOwner;
        const panel = findChild(dock.item, "taskPreview");
        panel.showForKeyboard(owner);
        tryCompare(panel, "displayed", true);
        // Demo tasks have no native windows. Attach the two-window fixture.
        panel.keyboardOwner = null;
        windowPreviews.select(testPreviewModel, 0);
        panel.keyboardOwner = owner;
        // Plasma defers shared tooltip dismissal after a sibling area is deactivated.
        wait(1000);
        compare(panel.displayed, true);
        compare(panel.keyboardOwner, owner);
        verify(panel.moveKeyboardSelection(Qt.Key_Home));
        verify(panel.moveKeyboardSelection(Qt.Key_Right));
        tryVerify(() => findChild(panel, "previewActivate1") !== null);
        verify(panel.activateKeyboardWindow());
        tryCompare(panel, "displayed", false);
        compare(testEnvironment.activatedPreview(), "Second window");
        dock.item.keyboardItem = null;
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
        owner.showGroupWindows();
        verify(panel.windowsEnabled);
        // Showing the tooltip can reselect the demo owner; restore grouped fixture.
        windowPreviews.select(testPreviewModel, 0);
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
    Component { id: temporaryOwner; PlasmaCore.ToolTipArea {} }
    function test_destroyedTooltipOwnerIsCleared() {
        const component = Qt.createComponent("qrc:/qml/TaskPreview.qml");
        compare(component.status, Component.Ready, component.errorString());
        const panel = component.createObject(test);
        const owner = temporaryOwner.createObject(test);
        panel.toolTip = owner;
        owner.destroy();
        tryCompare(panel, "toolTip", null);
        panel.dismiss();
        panel.destroy();
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
