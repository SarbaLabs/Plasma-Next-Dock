// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    name: "NativeLaunchers"
    when: windowShown
    function test_pinUnpinAndRestoreOrder() {
        const component = Qt.createComponent("qrc:/qml/LiveTasks.qml");
        compare(component.status, Component.Ready, component.errorString());
        let live = component.createObject(this);
        verify(live !== null);
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
        // Reorder the saved list, then rebuild the native model as at restart.
        verify(dockSettings.saveLaunchers([testLauncherUrls[1], testLauncherUrls[0]]));
        live.destroy(); wait(0);
        live = component.createObject(this);
        live.tasks.filterByVirtualDesktop = false;
        live.tasks.filterByActivity = false;
        live.tasks.launcherList = dockSettings.values.launchers;
        tryVerify(() => live.pinned(testLauncherUrls[0]) && live.pinned(testLauncherUrls[1]));
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
