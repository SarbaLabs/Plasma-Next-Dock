// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import org.kde.taskmanager as TaskManager
TestCase {
    name: "NativeLaunchers"
    when: windowShown
    function test_pinUnpinAndRestoreOrder() {
        const component = Qt.createComponent("qrc:/qml/LiveTasks.qml");
        compare(component.status, Component.Ready, component.errorString());
        let live = component.createObject(this);
        verify(live !== null);
        verify(live.tasks !== live.collisionTasks);
        compare(live.tasks.groupMode, TaskManager.TasksModel.GroupApplications);
        compare(live.tasks.groupInline, false);
        compare(live.collisionTasks.groupMode, TaskManager.TasksModel.GroupDisabled);
        compare(dockController.model, live.collisionTasks);
        // No compositor/current desktop/activity exists in this headless fixture.
        live.tasks.filterByVirtualDesktop = false;
        live.tasks.filterByActivity = false;
        tryCompare(live.tasks, "launcherCount", 0);
        live.togglePinned(testLauncherUrls[0]);
        tryVerify(() => live.pinned(testLauncherUrls[0]));
        live.togglePinned(testLauncherUrls[1]);
        // The offscreen platform has no window backend, so the concatenated
        // task model has no display columns. Exercise native launcher identity
        // and ordering APIs; visible task rows require a real Wayland session.
        compare(live.tasks.launcherPosition(testLauncherUrls[0]), 0);
        compare(live.tasks.launcherPosition(testLauncherUrls[1]), 1);
        compare(dockSettings.values.launchers.length, 2);
        // Reorder in settings without reconstructing the running model.
        verify(dockSettings.saveLaunchers([testLauncherUrls[1], testLauncherUrls[0]]));
        tryCompare(live.tasks, "launcherList", dockSettings.values.launchers);
        compare(live.tasks.launcherPosition(testLauncherUrls[1]), 0);
        compare(live.tasks.launcherPosition(testLauncherUrls[0]), 1);
        live.togglePinned(testLauncherUrls[1]);
        tryVerify(() => !live.pinned(testLauncherUrls[1]));
        compare(dockSettings.values.launchers.length, 1);
        live.togglePinned(testLauncherUrls[0]);
        tryCompare(live.tasks, "launcherCount", 0);
        compare(dockSettings.values.launchers.length, 0);
        live.destroy();
    }
}
