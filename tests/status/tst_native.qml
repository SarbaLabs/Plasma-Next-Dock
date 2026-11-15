// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest

TestCase {
    name: "NativeApplicationStatus"
    visible: true
    width: 400; height: 300
    when: windowShown
    function test_nativeLauncherUpdates() {
        const component = Qt.createComponent("qrc:/qml/TaskStatus.qml");
        compare(component.status, Component.Ready, component.errorString());
        const status = component.createObject(this, {task: {LauncherUrlWithoutIcon: testLauncherUrls[0]}, taskIndex: 0});
        // Let queued initialization finish before capturing its diagnostics.
        wait(0);
        tryVerify(() => status.smart !== null, 5000,
            "Installed KDE SmartLauncherItem must load: " + status.smartError);
        verify(testEnvironment.publishLauncher({"count": 7, "count-visible": true, "progress": 0.42, "progress-visible": true}));
        tryCompare(status.smart, "count", 7);
        tryCompare(status.smart, "countVisible", true);
        tryCompare(status.smart, "progress", 42);
        tryCompare(status.smart, "progressVisible", true);
        const previous = status.smart;
        status.launcherUrl = testLauncherUrls[1];
        // Replacement is queued; do not retain the destroyed object in tryCompare.
        tryVerify(() => status.smart !== null && status.smart !== previous);
        tryCompare(status.smart, "count", 0);
        tryCompare(status.smart, "countVisible", false);
        status.launcherEnabled = false;
        tryCompare(status, "smart", null);
        status.destroy();
    }
    function test_nativeAudioModelLoads() {
        const component = Qt.createComponent("qrc:/qml/AudioService.qml");
        compare(component.status, Component.Ready, component.errorString());
        const audio = component.createObject(this);
        verify(audio !== null);
        verify(audio.normalVolume > 0);
        compare(audio.streamsForPid(-999).length, 0);
        compare(audio.streamsForAppId("not.a.real.application").length, 0);
        audio.destroy();
    }
}
