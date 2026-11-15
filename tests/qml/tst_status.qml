// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    id: test
    name: "ApplicationStatus"
    width: 400; height: 300
    visible: true
    when: windowShown
    Component {
        id: streamFactory
        QtObject {
            property bool muted: false
            property bool corked: false
            property int volume: 100
            function mute() { muted = true; }
            function unmute() { muted = false; }
            function setVolume(v) { volume = v; }
        }
    }
    Component {
        id: audioFactory
        QtObject {
            signal streamsChanged()
            property var first
            property var second
            function streamsForPid(pid) { return pid === 101 ? [first] : pid === 202 ? [second] : []; }
            function streamsForAppId(id) { return id === "sandbox.app" ? [second] : []; }
            function streamsForAppName(name) { return []; }
            function hasPidMatch(name) { return false; }
            function registerPidMatch(name) { }
        }
    }
    Component {
        id: modelFactory
        QtObject {
            function makeModelIndex(row, child) { return child === undefined ? -1 : child; }
            function rowCount(index) { return 2; }
            function data(index, role) { return index === 0 ? 101 : 202; }
        }
    }
    function test_groupMatchingAndPortalPriority() {
        const a = streamFactory.createObject(test);
        const b = streamFactory.createObject(test);
        const audio = audioFactory.createObject(test, {first: a, second: b});
        const model = modelFactory.createObject(test);
        const component = Qt.createComponent("qrc:/qml/TaskStatus.qml");
        const status = component.createObject(test, {task: {IsGroupParent: true, AppPid: 101},
            taskIndex: 0, tasksModel: model, audio: audio, launcherEnabled: false});
        tryCompare(status, "streams", [a, b]);
        status.task = {IsWindow: true, AppPid: 101, AppId: "sandbox.app"};
        tryCompare(status, "streams", [b]);
        status.task = {IsLauncher: true, AppPid: 101};
        tryCompare(status, "streams", []);
        status.destroy(); audio.destroy(); model.destroy(); a.destroy(); b.destroy();
    }
    function test_taskRemovedBeforeQueuedRefresh() {
        failOnWarning(/TypeError/);
        const a = streamFactory.createObject(test);
        const audio = audioFactory.createObject(test, {first: a});
        const component = Qt.createComponent("qrc:/qml/TaskStatus.qml");
        compare(component.status, Component.Ready, component.errorString());
        const status = component.createObject(test, {task: null, taskIndex: 0,
            audio: audio, launcherEnabled: false});
        wait(0);
        compare(status.launcherUrl, "");
        for (let i = 0; i < 3; ++i) {
            status.task = {IsWindow: true, AppPid: 101, LauncherUrl: "applications:test.desktop"};
            tryCompare(status, "streams", [a]);
            status.player = a;
            audio.streamsChanged(); // Queue work, then detach the model first.
            status.task = null;
            tryCompare(status, "streams", []);
            compare(status.player, null);
            compare(status.launcherUrl, "");
        }
        status.destroy(); audio.destroy(); a.destroy();
    }
    function test_mediaCapabilitiesAndActions() {
        const component = Qt.createComponent("qrc:/qml/MediaControls.qml");
        compare(component.status, Component.Ready, component.errorString());
        const player = {canControl: true, canPlay: true, canPause: true,
            canGoPrevious: false, canGoNext: true, playbackStatus: 0, played: 0, next: 0,
            Play: function() { ++this.played; }, Pause: function() {},
            Next: function() { ++this.next; }, Previous: function() {}};
        const controls = component.createObject(test, {width: 280, height: 120, player: player});
        verify(controls.hasMedia);
        waitForRendering(controls);
        verify(!findChild(controls, "mediaPrevious").enabled);
        mouseClick(findChild(controls, "mediaPlayPause"));
        compare(controls.player.played, 1);
        mouseClick(findChild(controls, "mediaNext"));
        compare(controls.player.next, 1);
        controls.player = null;
        verify(!controls.visible);
        controls.destroy();
    }
    function test_streamControlsAndOverlay() {
        const component = Qt.createComponent("qrc:/qml/TaskStatus.qml");
        compare(component.status, Component.Ready, component.errorString());
        const status = component.createObject(test, {task: {}, taskIndex: 0, nativeEnabled: false});
        wait(0);
        const a = streamFactory.createObject(test, {volume: 100});
        const b = streamFactory.createObject(test, {volume: 50});
        status.streams = [a, b];
        status.muteToggle();
        verify(a.muted && b.muted);
        status.muteToggle();
        verify(!a.muted && !b.muted);
        status.setVolume(80);
        compare(a.volume, 80); compare(b.volume, 40);
        const overlayComponent = Qt.createComponent("qrc:/qml/StatusOverlay.qml");
        compare(overlayComponent.status, Component.Ready, overlayComponent.errorString());
        const overlay = overlayComponent.createObject(test, {width: 60, height: 60, status: status,
            configuration: {showBadges: true, showProgress: true, showAudioIndicator: true, muteOnClick: true}});
        verify(findChild(overlay, "taskAudio").visible);
        mouseClick(findChild(overlay, "taskAudio"));
        verify(status.muted);
        overlay.configuration = {showAudioIndicator: false, showBadges: false, showProgress: false};
        verify(!findChild(overlay, "taskAudio").visible);
        verify(!findChild(overlay, "countBadge").visible);
        overlay.destroy(); status.destroy(); a.destroy(); b.destroy();
    }
}
