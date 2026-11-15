/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2024 Nate Graham <nate@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
// Movement phases adapted from plasma-macos-dock Task.qml. Lifecycle and
// standalone geometry are independent of the original plasmoid delegate.
import QtQuick

Item {
    id: bounce
    property bool animationsEnabled: true
    property bool launchEnabled: true
    property bool attentionEnabled: true
    property bool attention: false
    property bool startup: false
    property bool suspended: false
    property real amplitude: 7
    property real speed: 100
    property int repetitions: 3
    property real progress: 0
    property string reason: ""
    readonly property real offset: progress * amplitude
    readonly property bool running: movement.running
    readonly property real timing: 100 / Math.max(50, Math.min(200, speed))

    function stop() { movement.stop(); progress = 0; reason = ""; }
    function play(kind) {
        if (!animationsEnabled || suspended || amplitude <= 0) return;
        stop();
        reason = kind;
        movement.start();
    }
    function launch() {
        if (launchEnabled && reason !== "attention" && !running) play("launch");
    }
    function test() { play("test"); }
    function refresh() {
        if (!animationsEnabled || suspended || amplitude <= 0) { stop(); return; }
        if (attention && attentionEnabled) {
            if (!running) play("attention");
        } else if (reason === "attention") stop();
        if (!launchEnabled && reason === "launch") stop();
    }
    onAnimationsEnabledChanged: Qt.callLater(refresh)
    onAttentionEnabledChanged: Qt.callLater(refresh)
    onLaunchEnabledChanged: Qt.callLater(refresh)
    onAttentionChanged: Qt.callLater(refresh)
    onSuspendedChanged: Qt.callLater(refresh)
    onAmplitudeChanged: Qt.callLater(refresh)
    onStartupChanged: if (startup) Qt.callLater(launch)
    Component.onCompleted: { Qt.callLater(refresh); if (startup) Qt.callLater(launch); }
    SequentialAnimation {
        id: movement
        loops: bounce.reason === "attention" ? Animation.Infinite : Math.max(1, Math.min(5, bounce.repetitions))
        NumberAnimation { target: bounce; property: "progress"; to: 1; duration: 220 * bounce.timing; easing.type: Easing.OutCubic }
        NumberAnimation { target: bounce; property: "progress"; to: 0; duration: 200 * bounce.timing; easing.type: Easing.InQuad }
        NumberAnimation { target: bounce; property: "progress"; to: 0.3; duration: 110 * bounce.timing; easing.type: Easing.OutQuad }
        NumberAnimation { target: bounce; property: "progress"; to: 0; duration: 100 * bounce.timing; easing.type: Easing.InQuad }
        PauseAnimation { duration: 280 * bounce.timing }
        onFinished: { bounce.progress = 0; bounce.reason = ""; Qt.callLater(bounce.refresh); }
    }
}
