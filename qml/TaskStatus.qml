// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.taskmanager as TaskManager

Item {
    id: root
    required property var task
    required property int taskIndex
    property var tasksModel: null
    property var audio: null
    property var players: null
    property bool nativeEnabled: true
    property bool audioEnabled: true
    property bool launcherEnabled: true
    property string launcherUrl: String(task?.LauncherUrlWithoutIcon || task?.LauncherUrl || "")
    property var streams: []
    property var player: null
    property var smart: null
    property string smartError: ""
    readonly property bool muted: streams.length > 0 && streams.every(s => s && s.muted)
    readonly property bool playing: streams.some(s => s && !s.corked)
    readonly property real volume: streams.reduce((v, s) => Math.max(v, s ? s.volume : 0), 0)
    // Snapshot the target before mutating streams: muted changes synchronously.
    function muteToggle() {
        const unmute = muted;
        streams.filter(s => s).forEach(s => { if (unmute) s.unmute(); else s.mute(); });
    }
    function setVolume(value) {
        const loudest = volume;
        streams.filter(s => s).forEach(s => s.setVolume(loudest > 0 ? s.volume / loudest * value : value));
    }
    function refresh() {
        // TasksModel can detach a delegate before an already queued refresh runs.
        if (!task) {
            streams = [];
            player = null;
            return;
        }
        const matches = [];
        if (nativeEnabled && audioEnabled && audio && (task.IsWindow || task.IsGroupParent)) {
            let found = task.AppId ? audio.streamsForAppId(task.AppId) : [];
            const pids = [Number(task.AppPid) || 0];
            if (task.IsGroupParent && tasksModel) {
                const parent = tasksModel.makeModelIndex(taskIndex);
                for (let i = 0; i < tasksModel.rowCount(parent); ++i)
                    pids.push(Number(tasksModel.data(tasksModel.makeModelIndex(taskIndex, i), TaskManager.AbstractTasksModel.AppPid)) || 0);
            }
            if (!found.length) {
                pids.filter(p => p > 0).forEach(pid => found.push(...audio.streamsForPid(pid)));
                if (found.length && task.AppName) audio.registerPidMatch(task.AppName);
                if (!found.length && task.AppName && !audio.hasPidMatch(task.AppName))
                    found = audio.streamsForAppName(task.AppName);
            }
            for (const stream of found) if (!matches.includes(stream)) matches.push(stream);
        }
        streams = matches;
        player = nativeEnabled && players ? players.playerForLauncherUrl(launcherUrl, Number(task.AppPid) || 0) : null;
    }
    // Owned one-shot queues are cancelled with the delegate/context. A bare
    // callLater closure can outlive its TasksModel delegate's QML context.
    function schedule() { refreshQueue.restart(); }
    function scheduleSmart() { smartQueue.restart(); }
    Timer { id: refreshQueue; interval: 0; repeat: false; onTriggered: root.refresh() }
    Timer { id: smartQueue; interval: 0; repeat: false; onTriggered: root.loadSmart() }
    Component.onDestruction: { refreshQueue.stop(); smartQueue.stop(); }
    function loadSmart() {
        if (smart) { smart.destroy(); smart = null; }
        smartError = "";
        if (!nativeEnabled || !launcherEnabled || !launcherUrl) return;
        // Plasma 6 moved this type into the applet module. Instantiate only the
        // status type, never its Backend (which registers global shortcuts).
        statusSupport.prepareSmartLauncherModule();
        let component = Qt.createComponent("plasma.applet.org.kde.plasma.taskmanager", "SmartLauncherItem");
        const modernError = component.errorString();
        if (component.status !== Component.Ready)
            component = Qt.createComponent("org.kde.plasma.private.taskmanager", "SmartLauncherItem");
        if (component.status === Component.Ready)
            smart = component.createObject(root, {launcherUrl: root.launcherUrl});
        if (!smart)
            smartError = statusSupport.smartLauncherLoadError() + "\n" + modernError + "\n" + component.errorString();
    }
    onLauncherUrlChanged: { schedule(); scheduleSmart(); }
    onTasksModelChanged: schedule()
    onTaskChanged: schedule()
    onTaskIndexChanged: schedule()
    onAudioChanged: schedule()
    onAudioEnabledChanged: schedule()
    onPlayersChanged: schedule()
    onNativeEnabledChanged: { schedule(); scheduleSmart(); }
    onLauncherEnabledChanged: scheduleSmart()
    Component.onCompleted: { schedule(); scheduleSmart(); }
    Connections {
        target: root.audio
        function onStreamsChanged() { root.schedule(); }
    }
    Connections {
        target: root.tasksModel
        ignoreUnknownSignals: true
        function onDataChanged() { root.schedule(); }
        function onRowsInserted() { root.schedule(); }
        function onRowsRemoved() { root.schedule(); }
        function onLayoutChanged() { root.schedule(); }
        function onModelReset() { root.schedule(); }
    }
    Connections {
        target: root.players
        ignoreUnknownSignals: true
        function onRowsInserted() { root.schedule(); }
        function onRowsRemoved() { root.schedule(); }
        function onDataChanged() { root.schedule(); }
        function onModelReset() { root.schedule(); }
    }
}
