// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.taskmanager as TaskManager
Item {
    id: source
    property alias tasks: tasks
    readonly property var savedLaunchers: dockSettings.values.launchers
    onSavedLaunchersChanged: Qt.callLater(applySavedLaunchers)
    function applySavedLaunchers() {
        if (JSON.stringify(tasks.launcherList) === JSON.stringify(savedLaunchers)) return;
        tasks.launcherList = savedLaunchers;
        // A saved list does not reset TasksModel's existing manual row map.
        // Rebuild it from launcher order only when the external list changes.
        tasks.sortMode = TaskManager.TasksModel.SortDisabled;
        tasks.sortMode = TaskManager.TasksModel.SortManual;
    }
    function moveTask(from, to) { return tasks.move(from, to); }
    function finishMove() {
        tasks.syncLaunchers();
        dockSettings.saveLaunchers(tasks.launcherList);
    }
    function activate(index) { tasks.requestActivate(tasks.makeModelIndex(index)); }
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
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: true
        launchInPlace: true
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        filterByVirtualDesktop: true
        filterByActivity: true
        filterByScreen: false
    }
    Component.onCompleted: { applySavedLaunchers(); dockController.model = tasks; }
    Component.onDestruction: dockController.model = null
}
