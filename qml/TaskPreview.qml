// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

Item {
    id: panel
    // Plasma's tooltip sets this to its current owner before displaying us.
    property PlasmaCore.ToolTipArea toolTip: null
    property var dockWindow: null
    property string applicationName: ""
    property var applicationIcon: ""
    property bool vertical: false
    property var status: null
    readonly property bool mediaAvailable: dockOptions.showMediaControls !== false
        && !!(status?.player?.canControl || status?.streams?.length)
    property bool windowsEnabled: true
    readonly property int visibleWindows: windowsEnabled ? windowPreviews.count : 0
    property bool thumbnailsEnabled: !dockOptions.demo
    readonly property bool displayed: Window.window !== null && Window.window !== dockWindow && Window.window.visible
    // A shared Plasma tooltip briefly detaches this item while changing owners.
    // Release the model only after that synchronous reparenting has finished.
    onDisplayedChanged: if (!displayed) Qt.callLater(() => { if (!panel.displayed) windowPreviews.clear(); })
    visible: false
    implicitWidth: visibleWindows ? Math.min(outputSize.width - 32, vertical ? 240 : Math.min(visibleWindows, 3) * 240) : Math.min(outputSize.width - 32, Math.max(mediaAvailable ? 260 : 80, heading.implicitWidth + 24))
    implicitHeight: Math.min(outputSize.height - 32, (visibleWindows ? 32 + (vertical ? Math.min(visibleWindows, 3) : 1) * 180 : 36) + (media.item && media.item.visible ? media.item.implicitHeight + 12 : 0))
    width: Math.max(32, implicitWidth)
    height: Math.max(32, implicitHeight)
    function dismiss() {
        const owner = toolTip;
        if (owner && typeof owner.hideImmediately === "function") owner.hideImmediately();
    }
    Connections {
        target: windowPreviews
        function onTargetGone() { if (panel.displayed) panel.dismiss(); }
    }
    Controls.Label {
        id: heading
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
        height: 24
        text: panel.applicationName
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.bold: true
    }
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: heading.bottom; bottom: media.top }
        visible: panel.visibleWindows > 0
        orientation: panel.vertical ? ListView.Vertical : ListView.Horizontal
        clip: true
        model: windowPreviews
        reuseItems: false
        cacheBuffer: 0
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar { active: panel.vertical && list.contentHeight > list.height }
        Controls.ScrollBar.horizontal: Controls.ScrollBar { active: !panel.vertical && list.contentWidth > list.width }
        delegate: Item {
            id: card
            required property int index
            required property string title
            required property var icon
            required property string windowId
            required property bool minimized
            required property bool active
            required property bool closable
            width: panel.vertical ? list.width : Math.min(240, list.width)
            height: panel.vertical ? 180 : list.height
            readonly property bool onScreen: panel.vertical ? y + height > list.contentY && y < list.contentY + list.height : x + width > list.contentX && x < list.contentX + list.width
            Rectangle {
                anchors.fill: parent; anchors.margins: 3
                radius: 5
                color: card.active ? Kirigami.Theme.highlightColor : "transparent"
                opacity: 0.18
            }
            Controls.ToolButton {
                id: activate
                objectName: "previewActivate" + card.index
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: caption.top; margins: 6 }
                Accessible.name: card.title
                onClicked: { windowPreviews.activate(card.index); panel.dismiss(); }
                contentItem: Item {
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 48; height: width
                        source: card.icon || panel.applicationIcon
                        visible: !capture.item || !capture.item.hasThumbnail
                        roundToIconSize: false
                    }
                    Loader {
                        id: capture
                        anchors.fill: parent
                        active: panel.displayed && panel.windowsEnabled && panel.thumbnailsEnabled && card.onScreen && !card.minimized && card.windowId.length > 0
                        asynchronous: true
                        source: active ? "WindowThumbnail.qml" : ""
                        onLoaded: item.windowId = Qt.binding(() => card.windowId)
                    }
                }
            }
            RowLayout {
                id: caption
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
                Controls.Label {
                    Layout.fillWidth: true
                    text: card.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
                Controls.ToolButton {
                    objectName: "previewClose" + card.index
                    icon.name: "window-close"
                    enabled: card.closable
                    Accessible.name: i18ndc("plasma_applet_org.kde.plasma.taskmanager", "action:inmenu", "&Close")
                    onClicked: windowPreviews.close(card.index)
                }
            }
        }
    }
    Loader {
        id: media
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
        height: item && item.visible ? item.implicitHeight : 0
        active: panel.displayed && panel.mediaAvailable
        sourceComponent: MediaControls { status: panel.status }
    }

}
