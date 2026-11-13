// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.taskmanager as TaskManager
Item {
    property alias tasks: tasks
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
        launcherList: dockOptions.launchers
    }
    Component.onCompleted: dockController.model = tasks
    Component.onDestruction: dockController.model = null
}
