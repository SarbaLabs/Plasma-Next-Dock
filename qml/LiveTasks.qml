// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import "code/TaskBehavior.js" as Behavior
import org.kde.taskmanager as TaskManager
Item {
    id: source
    readonly property var options: dockSettings.values
    readonly property int selectedSort: [TaskManager.TasksModel.SortManual, TaskManager.TasksModel.SortAlpha,
        TaskManager.TasksModel.SortLastActivated, TaskManager.TasksModel.SortVirtualDesktop,
        TaskManager.TasksModel.SortActivity][options.taskSort || 0]
    readonly property var actionRoles: ({active: TaskManager.AbstractTasksModel.IsActive,
        minimized: TaskManager.AbstractTasksModel.IsMinimized, minimizable: TaskManager.AbstractTasksModel.IsMinimizable,
        closable: TaskManager.AbstractTasksModel.IsClosable})
    readonly property bool attention: options.revealAttention === true && tasks.anyTaskDemandsAttention
    onAttentionChanged: dockController.setAttention(attention)
    property alias tasks: tasks
    property alias collisionTasks: collisionTasks
    readonly property var savedLaunchers: dockSettings.values.launchers
    onSavedLaunchersChanged: Qt.callLater(applySavedLaunchers)
    function applySavedLaunchers() {
        if (JSON.stringify(tasks.launcherList) === JSON.stringify(savedLaunchers)) return;
        tasks.launcherList = savedLaunchers;
        // A saved list does not reset TasksModel's existing manual row map.
        // Rebuild it from launcher order only when the external list changes.
        tasks.sortMode = TaskManager.TasksModel.SortDisabled;
        tasks.sortMode = Qt.binding(() => source.selectedSort);
    }
    function moveTask(from, to) { return tasks.move(from, to); }
    function finishMove() {
        tasks.syncLaunchers();
        dockSettings.saveLaunchers(tasks.launcherList);
    }
    signal launchRequested(int row)
    function activate(index) {
        if (tasks.data(tasks.makeModelIndex(index), TaskManager.AbstractTasksModel.IsLauncher)) launchRequested(index);
        Behavior.primary(tasks, index, options.minimizeActive === true, actionRoles);
    }
    function cycle(index, direction) { return Behavior.cycle(tasks, index, direction, options.skipMinimized !== false, actionRoles); }
    function middle(index) {
        if (options.middleClick === 1) launchRequested(index);
        Behavior.middle(tasks, index, options.middleClick || 0, actionRoles);
    }
    function insertLaunchers(urls, before) {
        const desired = launcherResolver.insert(tasks.launcherList, urls, before);
        for (const url of desired) {
            if (tasks.launcherPosition(url) < 0) tasks.requestAddLauncher(url);
        }
        if (dockSettings.saveLaunchers(desired)) return true;
        tasks.launcherList = dockSettings.values.launchers;
        return false;
    }
    function toggleGrouping(index) {
        tasks.requestToggleGrouping(index);
        const saved = dockSettings.apply({groupingAppIdBlacklist: tasks.groupingAppIdBlacklist,
                                          groupingLauncherUrlBlacklist: tasks.groupingLauncherUrlBlacklist});
        if (!saved) {
            tasks.groupingAppIdBlacklist = Qt.binding(() => source.options.groupingAppIdBlacklist || []);
            tasks.groupingLauncherUrlBlacklist = Qt.binding(() => source.options.groupingLauncherUrlBlacklist || []);
        }
    }
    function pinned(url) { return tasks.launcherPosition(url) >= 0; }
    function togglePinned(url) {
        if (pinned(url)) tasks.requestRemoveLauncher(url);
        else tasks.requestAddLauncher(url);
        dockSettings.saveLaunchers(tasks.launcherList);
    }
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: tasks
        groupMode: source.options.groupApplications !== false ? TaskManager.TasksModel.GroupApplications : TaskManager.TasksModel.GroupDisabled
        groupingAppIdBlacklist: source.options.groupingAppIdBlacklist || []
        groupingLauncherUrlBlacklist: source.options.groupingLauncherUrlBlacklist || []
        groupInline: false
        groupingWindowTasksThreshold: -1
        sortMode: source.selectedSort
        separateLaunchers: true
        launchInPlace: true
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        filterByVirtualDesktop: source.options.filterDesktop !== false
        filterByActivity: source.options.filterActivity !== false
        filterByScreen: source.options.filterScreen === true
        screenGeometry: typeof outputGeometry !== "undefined" ? outputGeometry : Qt.rect(0, 0, 0, 0)
        filterNotMinimized: source.options.onlyMinimized === true
    }
    // Collision must keep every individual window geometry, including siblings
    // hidden behind a group in the presentation model.
    TaskManager.TasksModel {
        id: collisionTasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        filterByScreen: false
    }
    Component.onCompleted: { applySavedLaunchers(); dockController.model = collisionTasks; dockController.setAttention(attention); }
    Component.onDestruction: { dockController.model = null; dockController.setAttention(false); }
}
