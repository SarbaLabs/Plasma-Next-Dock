// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.plasma.private.mpris as Mpris

ColumnLayout {
    id: root
    property var status: null
    property var player: status?.player ?? null
    readonly property bool hasMedia: !!player?.canControl
    readonly property bool hasVolume: (status?.streams.length ?? 0) > 0
    visible: hasMedia || hasVolume
    Controls.Label {
        Layout.fillWidth: true
        visible: root.hasMedia && text.length > 0
        text: [root.player?.track ?? "", root.player?.artist ?? ""].filter(s => s.length).join(" — ")
        textFormat: Text.PlainText; elide: Text.ElideRight
    }
    RowLayout {
        visible: root.hasMedia
        Controls.ToolButton {
            objectName: "mediaPrevious"; icon.name: "media-skip-backward"; Accessible.name: i18n("Previous track")
            enabled: root.player?.canGoPrevious ?? false
            onClicked: root.player.Previous()
        }
        Controls.ToolButton {
            objectName: "mediaPlayPause"
            readonly property bool playing: root.player?.playbackStatus === Mpris.PlaybackStatus.Playing
            icon.name: playing ? "media-playback-pause" : "media-playback-start"
            Accessible.name: playing ? i18n("Pause") : i18n("Play")
            enabled: playing ? (root.player?.canPause ?? false) : (root.player?.canPlay ?? false)
            onClicked: { if (playing) root.player.Pause(); else root.player.Play(); }
        }
        Controls.ToolButton {
            objectName: "mediaNext"; icon.name: "media-skip-forward"; Accessible.name: i18n("Next track")
            enabled: root.player?.canGoNext ?? false
            onClicked: root.player.Next()
        }
    }
    RowLayout {
        visible: root.hasVolume
        Controls.ToolButton {
            objectName: "volumeMute"
            icon.name: root.status?.muted ? "audio-volume-muted" : "audio-volume-high"
            Accessible.name: root.status?.muted ? i18n("Unmute application") : i18n("Mute application")
            onClicked: root.status.muteToggle()
        }
        Controls.Slider {
            objectName: "applicationVolume"
            Layout.fillWidth: true
            from: 0; to: root.status?.audio?.normalVolume ?? 65536
            value: root.status?.volume ?? 0
            Accessible.name: i18n("Application volume")
            onMoved: root.status.setVolume(value)
        }
    }
}
