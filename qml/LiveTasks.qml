// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.taskmanager as TaskManager
Item {
    property alias tasks: tasks
    function activate(index) { tasks.requestActivate(tasks.makeModelIndex(index)); }
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortAlpha
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
