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
    property PlasmaCore.ToolTipArea dragOwner: null
    function showForDrag(owner) {
        handover.stop();
        dragOwner = owner;
        owner.showGroupWindows();
    }
    function leaveDock() { if (dragOwner) handover.restart(); }
    function endDrag() {
        handover.stop();
        if (!dragOwner) return;
        dragOwner = null;
        dismiss();
    }
    Timer {
        id: handover
        interval: 750
        onTriggered: if (!cardDrag.containsDrag) panel.endDrag()
    }
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
    onDisplayedChanged: if (!displayed) Qt.callLater(() => { if (!panel.displayed) { panel.dragOwner = null; windowPreviews.clear(); } })
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
                color: card.active || cardDrag.candidate === card ? Kirigami.Theme.highlightColor : "transparent"
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
    // Wayland sends a new drag enter when crossing into the tooltip surface.
    // Accept the hover offer, but leave the actual file drop to the application.
    DropArea {
        id: cardDrag
        objectName: "previewDocumentDrag"
        anchors.fill: parent
        enabled: !!panel.dragOwner && panel.toolTip === panel.dragOwner && panel.displayed
        property Item candidate: null
        property point point: Qt.point(0, 0)
        readonly property point listPoint: list.mapFromItem(cardDrag, point)
        readonly property real axis: panel.vertical ? listPoint.y : listPoint.x
        readonly property real extent: panel.vertical ? list.height : list.width
        readonly property real offset: panel.vertical ? list.contentY - list.originY : list.contentX - list.originX
        readonly property real overflow: panel.vertical ? list.contentHeight - list.height : list.contentWidth - list.width
        readonly property int scrollStep: !containsDrag || !list.contains(listPoint) ? 0
            : axis < 22 && offset > 0 ? -18 : axis > extent - 22 && offset < overflow ? 18 : 0
        function locate() {
            const p = list.contentItem.mapFromItem(cardDrag, point);
            const card = list.contains(listPoint) ? list.itemAt(p.x, p.y) : null;
            if (card === candidate) return;
            choose.stop();
            candidate = card;
            if (card && !scrollStep) choose.start();
        }
        function reset() { choose.stop(); candidate = null; }
        onEntered: event => {
            event.accepted = event.hasUrls && !!(event.supportedActions & Qt.CopyAction)
                && launcherResolver.classify(event.urls).kind === "documents";
            if (!event.accepted) return;
            handover.stop();
            point = Qt.point(event.x, event.y);
            locate();
        }
        onPositionChanged: event => { point = Qt.point(event.x, event.y); locate(); }
        onExited: { reset(); panel.endDrag(); }
        onDropped: event => { event.accepted = false; reset(); panel.endDrag(); }
        onScrollStepChanged: {
            if (scrollStep) choose.stop();
            else if (containsDrag && candidate) choose.restart();
        }
        onEnabledChanged: if (!enabled) reset()
        Timer {
            id: choose
            interval: 350
            onTriggered: {
                const card = cardDrag.candidate;
                if (!cardDrag.containsDrag || !cardDrag.enabled || !card || cardDrag.scrollStep) return;
                // Card geometry can settle or change under a stationary drag.
                cardDrag.locate();
                if (card !== cardDrag.candidate || !card.onScreen) return;
                windowPreviews.activate(card.index);
            }
        }
        // Make off-screen group members reachable while holding the document.
        Timer {
            interval: 60; repeat: true
            running: cardDrag.scrollStep !== 0
            onTriggered: {
                const next = Math.max(0, Math.min(cardDrag.overflow, cardDrag.offset + cardDrag.scrollStep));
                if (panel.vertical) list.contentY = list.originY + next;
                else list.contentX = list.originX + next;
                cardDrag.locate();
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
