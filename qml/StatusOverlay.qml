// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: root
    required property var status
    required property var configuration
    readonly property bool audioHovered: audioButton.visible && audioButton.hovered
    readonly property real badgeSize: Math.max(12, Math.min(22, width * 0.4))
    Rectangle {
        objectName: "countBadge"
        visible: root.configuration.showBadges !== false && !!root.status.smart?.countVisible && root.status.smart.count > 0
        anchors { right: parent.right; top: parent.top }
        width: Math.max(root.badgeSize, label.implicitWidth + 6); height: root.badgeSize
        radius: height / 2
        color: Kirigami.Theme.highlightColor
        Controls.Label {
            id: label; anchors.centerIn: parent
            text: root.status.smart?.count > 999 ? "999+" : String(root.status.smart?.count ?? 0)
            font.pixelSize: Math.max(9, root.badgeSize * 0.6)
            color: Kirigami.Theme.highlightedTextColor
        }
    }
    Controls.ProgressBar {
        objectName: "taskProgress"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: root.configuration.showProgress !== false && !!root.status.smart?.progressVisible
        from: 0; to: 100; value: root.status.smart?.progress ?? 0
        height: Math.max(4, parent.height * 0.1)
    }
    Controls.ToolButton {
        id: audioButton
        hoverEnabled: true
        objectName: "taskAudio"
        anchors { left: parent.left; top: parent.top }
        visible: root.configuration.showAudioIndicator !== false && (root.status.playing || root.status.muted)
        width: root.badgeSize; height: width
        padding: 1
        icon.name: root.status.muted ? "audio-volume-muted" : "audio-volume-high"
        Accessible.name: root.status.muted ? i18n("Unmute application") : i18n("Mute application")
        enabled: root.configuration.muteOnClick !== false
        onClicked: root.status.muteToggle()
    }
}
