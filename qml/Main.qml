// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "code/CapsuleGeometry.js" as Geometry
import "code/InteractionGeometry.js" as Interaction

Item {
    id: root
    readonly property bool vertical: dockOptions.edge >= 2
    readonly property real base: dockOptions.iconSize
    readonly property real edgeSpacing: dockOptions.spacing === undefined ? 8 : dockOptions.spacing
    readonly property real maximum: base * dockOptions.zoom
    readonly property real depth: maximum + 24 + edgeSpacing
    readonly property real length: Math.min((vertical ? outputSize.height : outputSize.width) - 16,
        Math.max(200, repeater.count * (maximum + 12) + 32))
    width: vertical ? depth : length
    height: vertical ? length : depth
    property int dragIndex: -1
    readonly property bool dragging: dragIndex >= 0
    function taskAt(position, nearest) {
        let result = -1;
        let distance = Infinity;
        for (let i = 0; i < repeater.count; ++i) {
            const slot = repeater.itemAt(i);
            const p = slot.iconItem.mapFromItem(root, position.x, position.y);
            if (!nearest && p.x >= 0 && p.y >= 0 && p.x < slot.iconItem.width && p.y < slot.iconItem.height) return i;
            const center = slot.iconItem.mapToItem(root, slot.iconItem.width / 2, slot.iconItem.height / 2);
            const delta = Math.abs(vertical ? position.y - center.y : position.x - center.x);
            if (nearest && delta < distance) { distance = delta; result = i; }
        }
        return result;
    }
    function finishDrag() {
        if (!dragging) return;
        dragIndex = -1;
        if (taskSource.item && taskSource.item.finishMove) taskSource.item.finishMove();
        dockController.setHovered(pointer.hovered || contextMenu.visible);
    }
    property real pointerIndex: -10
    property bool hovering: pointer.hovered
    property color applicationColor: Kirigami.Theme.highlightColor
    readonly property real barThickness: base + 20
    readonly property real barLength: Math.min(length, Math.max(160, taskRow.width + 24))

    function updatePointer(position) {
        const coordinate = vertical ? position.y : position.x;
        let nearest = -1;
        let distance = Infinity;
        let fraction = 0;
        for (let i = 0; i < repeater.count; ++i) {
            const slot = repeater.itemAt(i);
            if (!slot) continue;
            const center = slot.mapToItem(root, slot.width / 2, slot.height / 2);
            const delta = coordinate - (vertical ? center.y : center.x);
            if (Math.abs(delta) < distance) {
                distance = Math.abs(delta);
                nearest = i;
                fraction = delta / (slot.width + taskRow.spacing);
            }
        }
        pointerIndex = nearest < 0 ? -10 : nearest + fraction;
    }
    function syncGeometry() {
        let icons = [];
        for (let i = 0; i < repeater.count; ++i) {
            const slot = repeater.itemAt(i);
            if (!slot) continue;
            const p = slot.iconItem.mapToItem(root, 0, 0);
            icons.push(Qt.rect(p.x, p.y, slot.iconItem.width, slot.iconItem.height));
        }
        dockController.setGeometry(Qt.rect(bar.x, bar.y, bar.width, bar.height), bar.radius, icons, dockOptions.edge);
    }
    function queueGeometry() { Qt.callLater(syncGeometry); }
    onWidthChanged: queueGeometry()
    onHeightChanged: queueGeometry()
    Component.onCompleted: queueGeometry()

    Loader {
        id: taskSource
        objectName: "taskSourceLoader"
        source: dockOptions.demo ? "DemoTasks.qml" : "LiveTasks.qml"
        onStatusChanged: if (status === Loader.Error) Qt.exit(1)
    }
    Rectangle {
        id: bar
        x: root.vertical ? (dockOptions.edge === 2 ? root.edgeSpacing : root.width - width - root.edgeSpacing) : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : (dockOptions.edge === 1 ? root.edgeSpacing : root.height - height - root.edgeSpacing)
        width: root.vertical ? root.barThickness : root.barLength
        height: root.vertical ? root.barLength : root.barThickness
        radius: Geometry.radius(width, height, true, dockOptions.radius)
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.disabledTextColor
        border.width: 1
        onXChanged: root.queueGeometry()
        onYChanged: root.queueGeometry()
        onWidthChanged: root.queueGeometry()
        onHeightChanged: root.queueGeometry()
        Loader {
            anchors.fill: parent
            active: dockOptions.glow
            sourceComponent: CapsuleGlow {
                cornerRadius: bar.radius
                pointerX: pointer.point.position.x - bar.x
                pointerY: pointer.point.position.y - bar.y
                hovering: pointer.hovered && Geometry.containsPoint(width, height, cornerRadius, pointerX, pointerY)
                glowColor: root.applicationColor
                glowRadius: root.maximum
            }
        }
    }
    // Rotate the layout axis only; icons counter-rotate to stay upright.
    Flickable {
        id: viewport
        width: root.length
        height: root.depth
        x: root.vertical ? (root.width - width) / 2 : 0
        y: root.vertical ? (root.height - height) / 2 : 0
        rotation: root.vertical ? 90 : 0
        clip: true
        contentWidth: Math.max(width, taskRow.width + 24)
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        onContentXChanged: root.queueGeometry()
        Row {
            id: taskRow
            x: Math.max(12, (viewport.width - width) / 2)
            height: viewport.height
            spacing: 10
            onXChanged: root.queueGeometry()
            onWidthChanged: root.queueGeometry()
            Repeater {
                id: repeater
                model: taskSource.item ? taskSource.item.tasks : null
                onCountChanged: { root.finishDrag(); root.queueGeometry(); }
                delegate: Item {
                    id: slot
                    objectName: "task" + index
                    required property int index
                    required property var model
                    readonly property real factor: root.hovering && !root.dragging ? Math.max(0, 1 - Math.abs(root.pointerIndex - index) / 2.4) : 0
                    property real size: root.base + (root.maximum - root.base) * factor * factor
                    property alias iconItem: icon
                    width: size
                    height: viewport.height
                    Behavior on size { NumberAnimation { duration: 90 } }
                    onXChanged: root.queueGeometry()
                    onSizeChanged: root.queueGeometry()
                    Kirigami.Icon {
                        id: icon
                        objectName: "icon" + slot.index
                        width: slot.size; height: width
                        x: 0
                        // After a clockwise rotation, local bottom is the screen's left.
                        y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? root.edgeSpacing + 10 : slot.height - height - root.edgeSpacing - 10
                        rotation: root.vertical ? -90 : 0
                        source: slot.model.decoration
                        opacity: root.dragIndex === slot.index ? 0.65 : 1
                        roundToIconSize: false
                        onYChanged: root.queueGeometry()
                        TapHandler { onTapped: if (!reorder.active) taskSource.item.activate(slot.index) }
                        HoverHandler {
                            id: iconHover
                            onHoveredChanged: if (hovered) root.applicationColor = colorLoader.item ? colorLoader.item.dominant : Kirigami.Theme.highlightColor
                        }
                        Controls.ToolTip.visible: iconHover.hovered
                        Controls.ToolTip.delay: 900
                        Controls.ToolTip.text: slot.model.display || ""
                    }
                    Loader {
                        id: colorLoader
                        active: dockOptions.glow
                        sourceComponent: Kirigami.ImageColors {
                            source: slot.model.decoration
                            onPaletteChanged: if (iconHover.hovered) root.applicationColor = dominant
                        }
                    }
                    Rectangle {
                        visible: !!slot.model.IsWindow
                        width: 4; height: 4; radius: 2
                        x: (slot.width - width) / 2
                        y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? root.edgeSpacing + 4 : slot.height - root.edgeSpacing - 8
                        color: slot.model.IsActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    }
                }
            }
        }
        WheelHandler {
            onWheel: event => {
                if (viewport.contentWidth > viewport.width) {
                    viewport.contentX = Math.max(0, Math.min(viewport.contentWidth - viewport.width,
                        viewport.contentX - event.angleDelta.y / 2));
                    event.accepted = true;
                }
            }
        }
    }
    DragHandler {
        id: reorder
        objectName: "reorderHandler"
        enabled: !dockOptions.demo
        target: null
        acceptedButtons: Qt.LeftButton
        cursorShape: active ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onActiveChanged: {
            if (active) {
                const p = root.mapFromItem(null, centroid.scenePressPosition.x, centroid.scenePressPosition.y);
                root.dragIndex = root.taskAt(p, false);
                if (root.dragging) dockController.setHovered(true);
            } else root.finishDrag();
        }
        onActiveTranslationChanged: {
            if (!active || !root.dragging) return;
            const p = root.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
            const targetIndex = root.taskAt(p, true);
            if (targetIndex >= 0 && targetIndex !== root.dragIndex && taskSource.item.moveTask(root.dragIndex, targetIndex))
                root.dragIndex = targetIndex;
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: eventPoint => {
            contextMenu.launcherUrl = "";
            if (!dockOptions.demo) {
                for (let i = 0; i < repeater.count; ++i) {
                    const slot = repeater.itemAt(i);
                    const p = slot.iconItem.mapFromItem(root, eventPoint.position.x, eventPoint.position.y);
                    if (p.x >= 0 && p.y >= 0 && p.x < slot.iconItem.width && p.y < slot.iconItem.height) {
                        contextMenu.launcherUrl = String(slot.model.LauncherUrlWithoutIcon || slot.model.LauncherUrl || "");
                        break;
                    }
                }
            }
            contextMenu.pinned = contextMenu.launcherUrl.length > 0 && taskSource.item.pinned(contextMenu.launcherUrl);
            // Include magnified icons so the menu does not cover their inner edge.
            let left = bar.x, top = bar.y, right = bar.x + bar.width, bottom = bar.y + bar.height;
            for (let i = 0; i < repeater.count; ++i) {
                const icon = repeater.itemAt(i).iconItem;
                const p = icon.mapToItem(root, 0, 0);
                left = Math.min(left, p.x); top = Math.min(top, p.y);
                right = Math.max(right, p.x + icon.width); bottom = Math.max(bottom, p.y + icon.height);
            }
            const position = Interaction.menuPosition(dockOptions.edge,
                Qt.rect(left, top, right - left, bottom - top), eventPoint.position,
                Qt.size(contextMenu.implicitWidth, contextMenu.implicitHeight), 6);
            // Use a parent-local native anchor: recent Qt ignores popup(x,y)
            // on Wayland when it has a parent control rectangle.
            const anchor = Interaction.menuAnchor(dockOptions.edge,
                Qt.rect(left, top, right - left, bottom - top), eventPoint.position, 6);
            dockMenuAnchor.prepare(root, Qt.point(anchor.x, anchor.y), dockOptions.edge);
            contextMenu.popup(root, position.x, position.y);
        }
    }
    Controls.Menu {
        id: contextMenu
        objectName: "dockMenu"
        popupType: Controls.Popup.Window
        parent: root
        // The menu must extend outside the narrow layer surface, not fit inside it.
        margins: -1
        property string launcherUrl: ""
        property bool pinned: false
        onVisibleChanged: dockController.setHovered(pointer.hovered || visible || root.dragging)
        Controls.MenuItem {
            text: contextMenu.pinned ? qsTr("Unpin from Dock") : qsTr("Pin to Dock")
            visible: contextMenu.launcherUrl.length > 0
            height: visible ? implicitHeight : 0
            onTriggered: taskSource.item.togglePinned(contextMenu.launcherUrl)
        }
        Controls.MenuSeparator { visible: contextMenu.launcherUrl.length > 0; height: visible ? implicitHeight : 0 }
        Controls.MenuItem { text: qsTr("Configure Plasma Next Dock…"); onTriggered: dockSettings.configure() }
        Controls.MenuItem { text: qsTr("Quit Plasma Next Dock"); onTriggered: Qt.quit() }
    }
    Controls.Label {
        anchors.centerIn: bar
        visible: repeater.count === 0
        text: qsTr("Plasma Next Dock")
    }
    HoverHandler {
        id: pointer
        blocking: false
        onPointChanged: root.updatePointer(point.position)
        onHoveredChanged: dockController.setHovered(hovered || contextMenu.visible || root.dragging)
    }
}
