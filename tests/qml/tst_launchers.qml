// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import org.kde.taskmanager as TaskManager
TestCase {
    name: "NativeLaunchers"
    when: windowShown
    function test_behaviorFiltersAndSort() {
        const component = Qt.createComponent("qrc:/qml/LiveTasks.qml");
        compare(component.status, Component.Ready, component.errorString());
        // QVariantMap members may be live QML sequence references on newer Qt.
        // Materialize nested launcher lists before the test mutates settings.
        const saved = JSON.parse(JSON.stringify(dockSettings.values));
        const live = component.createObject(this);
        try {
            dockSettings.apply({groupApplications: false, taskSort: 2, filterDesktop: false,
                filterActivity: false, filterScreen: true, onlyMinimized: true});
            tryCompare(live.tasks, "groupMode", TaskManager.TasksModel.GroupDisabled);
            compare(live.tasks.sortMode, TaskManager.TasksModel.SortLastActivated);
            compare(live.tasks.filterByVirtualDesktop, false);
            compare(live.tasks.filterByActivity, false);
            compare(live.tasks.filterByScreen, true);
            compare(live.tasks.screenGeometry, Qt.rect(-1000, 0, 1000, 700));
            compare(live.tasks.filterNotMinimized, true);
            compare(live.collisionTasks.groupMode, TaskManager.TasksModel.GroupDisabled);
            compare(live.collisionTasks.filterByVirtualDesktop, true);
            compare(live.collisionTasks.filterByActivity, true);
            compare(live.collisionTasks.filterNotMinimized, false);
            dockSettings.saveLaunchers([testLauncherUrls[0]]);
            tryCompare(live.tasks, "launcherList", dockSettings.values.launchers);
            compare(live.tasks.sortMode, TaskManager.TasksModel.SortLastActivated);
            compare(saved.launchers, [], "The restoration snapshot must not follow launcher mutations");
            dockSettings.apply({taskSort: 1});
            tryCompare(live.tasks, "sortMode", TaskManager.TasksModel.SortAlpha);
        } finally {
            try {
                verify(dockSettings.apply(saved));
                tryCompare(live.tasks, "launcherList", saved.launchers);
            } finally { live.destroy(); wait(0); }
        }
    }
    function test_pinUnpinAndRestoreOrder() {
        const saved = JSON.parse(JSON.stringify(dockSettings.values));
        const component = Qt.createComponent("qrc:/qml/LiveTasks.qml");
        compare(component.status, Component.Ready, component.errorString());
        let live = component.createObject(this);
        verify(live !== null);
        try {
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
        } finally {
            try {
                verify(dockSettings.apply(saved));
                tryCompare(live.tasks, "launcherList", saved.launchers);
            } finally { live.destroy(); wait(0); }
        }
    }
}
