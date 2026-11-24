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
    function publishMinimizeTarget(row, rect, delegate) {
        tasks.requestPublishDelegateGeometry(tasks.makeModelIndex(row), rect, delegate);
    }
    function moveTask(from, to) { return tasks.separateLaunchers && tasks.move(from, to); }
    function finishMove() {
        if (!tasks.separateLaunchers) return;
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
        // KDE pins launchers to their saved positions when this is enabled.
        separateLaunchers: source.selectedSort === TaskManager.TasksModel.SortManual
        taskReorderingEnabled: separateLaunchers
        launchInPlace: true
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        filterByVirtualDesktop: source.options.filterDesktop !== false
        filterByActivity: source.options.filterActivity !== false
        filterByScreen: source.options.filterScreen === true
        screenGeometry: typeof outputGeometry !== "undefined" ? outputGeometry : Qt.rect(0, 0, 0, 0)
        filterNotMinimized: source.options.onlyMinimized === true
    }
    // Publish only task data to the module engine; KDE actions stay on this model.
    Binding { target: typeof dockTaskRows === "undefined" ? null : dockTaskRows; property: "sourceModel"; value: tasks }
    Binding { target: typeof dockTaskRows === "undefined" ? null : dockTaskRows; property: "desktopIds"; value: desktops.desktopIds }
    Binding {
        target: typeof dockTaskRows === "undefined" ? null : dockTaskRows
        property: "activityNames"
        value: source.activityNames
    }
    property var activityNames: ({})
    function updateActivityNames() {
        const names = {};
        for (const id of activities.runningActivities()) names[id] = activities.activityName(id);
        activityNames = names;
    }
    Connections {
        target: activities
        function onNamesOfRunningActivitiesChanged() { source.updateActivityNames(); }
        function onNumberOfRunningActivitiesChanged() { source.updateActivityNames(); }
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
    Component.onCompleted: { updateActivityNames(); applySavedLaunchers(); dockController.model = collisionTasks; dockController.setAttention(attention); }
    Component.onDestruction: { dockController.model = null; dockController.setAttention(false); }
}
