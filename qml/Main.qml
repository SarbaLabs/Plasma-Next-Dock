// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "code/CapsuleGeometry.js" as Geometry
import "code/InteractionGeometry.js" as Interaction
import "code/AdaptiveLayout.js" as Adaptive

Item {
    id: root
    readonly property bool vertical: dockOptions.edge >= 2
    readonly property var layoutMetrics: Adaptive.metrics(repeater.count, dockOptions.iconSize,
        dockOptions.zoom, (vertical ? outputSize.height : outputSize.width) - 16,
        vertical ? outputSize.width : outputSize.height,
        dockOptions.spacing === undefined ? 8 : dockOptions.spacing)
    readonly property real fitScale: layoutMetrics.scale
    readonly property real base: layoutMetrics.base
    readonly property real edgeSpacing: layoutMetrics.gap
    readonly property real maximum: base * dockOptions.zoom
    readonly property real depth: layoutMetrics.depth
    readonly property real length: layoutMetrics.length
    readonly property real taskPadding: 10 * fitScale
    readonly property real endPadding: 12 * fitScale
    width: vertical ? depth : length
    height: vertical ? length : depth
    property int dragIndex: -1
    readonly property bool dragging: dragIndex >= 0
    readonly property int tooltipLocation: [PlasmaCore.Types.BottomEdge, PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge][dockOptions.edge]
    function refreshHover() {
        dockController.setHovered(pointer.hovered || contextMenu.visibleMenu || dragging || previewPanel.displayed);
    }
    onDraggingChanged: { if (dragging) previewPanel.dismiss(); refreshHover(); }
    TaskPreview {
        id: previewPanel
        objectName: "taskPreview"
        dockWindow: root.Window.window
        vertical: root.vertical
        onDisplayedChanged: root.refreshHover()
    }
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
        root.refreshHover();
    }
    // Bound only overlapping zoom animation tails, not preferred icon sizes.
    property real animatedWeight: 0
    readonly property real zoomBudgetScale: Math.min(1, 2 / Math.max(2, animatedWeight))
    property real pointerIndex: -10
    property bool hovering: pointer.hovered
    property color applicationColor: Kirigami.Theme.highlightColor
    readonly property real barThickness: base + 2 * taskPadding
    readonly property real barLength: Math.min(length, Math.max(160 * fitScale, taskRow.width + 2 * endPadding))

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
        objectName: "taskViewport"
        width: root.length
        height: root.depth
        x: root.vertical ? (root.width - width) / 2 : 0
        y: root.vertical ? (root.height - height) / 2 : 0
        rotation: root.vertical ? 90 : 0
        clip: true
        contentWidth: Math.max(width, taskRow.width + 2 * root.endPadding)
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        // Left-button gestures belong to reorder, not competing flick grabs.
        interactive: false
        function clampScroll() {
            contentX = Adaptive.scrollPosition(contentX, 0, contentWidth, width);
        }
        onContentWidthChanged: Qt.callLater(clampScroll)
        onWidthChanged: Qt.callLater(clampScroll)
        onContentXChanged: root.queueGeometry()
        Row {
            id: taskRow
            x: Math.max(root.endPadding, (viewport.width - width) / 2)
            height: viewport.height
            spacing: root.taskPadding
            onXChanged: root.queueGeometry()
            onWidthChanged: root.queueGeometry()
            Repeater {
                id: repeater
                model: taskSource.item ? taskSource.item.tasks : null
                onCountChanged: { previewPanel.dismiss(); root.finishDrag(); root.queueGeometry(); }
                delegate: Item {
                    id: slot
                    objectName: "task" + index
                    required property int index
                    required property var model
                    readonly property real factor: root.hovering && !root.dragging ? Math.max(0, 1 - Math.abs(root.pointerIndex - index) / 2.4) : 0
                    property real animatedFactor: factor * factor
                    property real reportedFactor: 0
                    onAnimatedFactorChanged: {
                        root.animatedWeight += animatedFactor - reportedFactor;
                        reportedFactor = animatedFactor;
                    }
                    Component.onDestruction: root.animatedWeight -= reportedFactor
                    readonly property real size: root.base + (root.maximum - root.base) * animatedFactor * root.zoomBudgetScale
                    property alias iconItem: icon
                    width: size
                    height: viewport.height
                    Behavior on animatedFactor { NumberAnimation { duration: 90 } }
                    onXChanged: root.queueGeometry()
                    onSizeChanged: root.queueGeometry()
                    Kirigami.Icon {
                        id: icon
                        objectName: "icon" + slot.index
                        width: slot.size; height: width
                        x: 0
                        // After a clockwise rotation, local bottom is the screen's left.
                        y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? root.edgeSpacing + root.taskPadding : slot.height - height - root.edgeSpacing - root.taskPadding
                        rotation: root.vertical ? -90 : 0
                        source: slot.model.decoration
                        opacity: root.dragIndex === slot.index ? 0.65 : 1
                        roundToIconSize: false
                        onYChanged: root.queueGeometry()
                        DockIndicators {
                            anchors.fill: parent
                            z: -1
                            configuration: dockOptions
                            task: slot.model
                            taskIndex: slot.index
                            tasksModel: dockOptions.demo ? null : taskSource.item.tasks
                            edge: dockOptions.edge
                            padding: root.taskPadding
                            hovered: iconHover.hovered
                            dominantColor: colorLoader.item ? colorLoader.item.dominant : "transparent"
                        }
                        TapHandler {
                            onTapped: {
                                if (reorder.active) return;
                                if (slot.model.IsGroupParent) taskTip.showToolTip();
                                else { previewPanel.dismiss(); taskSource.item.activate(slot.index); }
                            }
                        }
                        HoverHandler {
                            id: iconHover
                            onHoveredChanged: if (hovered) root.applicationColor = colorLoader.item ? colorLoader.item.dominant : Kirigami.Theme.highlightColor
                        }
                        PlasmaCore.ToolTipArea {
                            id: taskTip
                            objectName: "taskTip" + slot.index
                            anchors.fill: parent
                            location: root.tooltipLocation
                            mainText: slot.model.AppName || slot.model.display || ""
                            textFormat: Text.PlainText
                            mainItem: previewPanel
                            interactive: !!slot.model.IsWindow || !!slot.model.IsGroupParent
                            active: !root.dragging && !contextMenu.visibleMenu
                            onAboutToShow: {
                                previewPanel.applicationName = mainText;
                                previewPanel.applicationIcon = slot.model.decoration;
                                windowPreviews.select(dockOptions.demo ? null : taskSource.item.tasks, slot.index);
                            }
                        }
                    }
                    Loader {
                        id: colorLoader
                        active: dockOptions.glow || (dockOptions.indicatorMode === 2
                            && dockOptions.customIndicatorsEnabled !== false && dockOptions.indicatorColorSource === 1
                            && (!!slot.model.IsWindow || !!slot.model.IsGroupParent))
                        sourceComponent: Kirigami.ImageColors {
                            source: slot.model.decoration
                            onPaletteChanged: if (iconHover.hovered) root.applicationColor = dominant
                        }
                    }
                    Rectangle {
                        visible: (dockOptions.indicatorMode === undefined || dockOptions.indicatorMode === 0) && (!!slot.model.IsWindow || !!slot.model.IsGroupParent)
                        width: 4 * root.fitScale; height: width; radius: width / 2
                        x: (slot.width - width) / 2
                        y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? root.edgeSpacing + 4 * root.fitScale : slot.height - root.edgeSpacing - 8 * root.fitScale
                        color: slot.model.IsActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    }
                }
            }
        }
    }
    function scrollWheel(event, axis) {
        const pixel = event.pixelDelta;
        const angle = event.angleDelta;
        // A diagonal gesture belongs to one handler only. Honour pixel scrolling
        // when supplied, otherwise use traditional wheel-angle increments.
        const delta = (pixel.x || pixel.y) ? pixel : Qt.point(angle.x / 2, angle.y / 2);
        const selectedAxis = delta.y ? Qt.Vertical : Qt.Horizontal;
        if (selectedAxis !== axis || (!delta.x && !delta.y)) {
            event.accepted = false;
            return;
        }
        viewport.contentX = Adaptive.scrollPosition(viewport.contentX,
            -(axis === Qt.Vertical ? delta.y : delta.x), viewport.contentWidth, viewport.width);
        root.updatePointer(Qt.point(event.x, event.y));
        event.accepted = true;
    }
    component DockWheelHandler: WheelHandler {
        target: null
        enabled: viewport.contentWidth > viewport.width && !contextMenu.visibleMenu
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.scrollWheel(event, orientation)
    }
    // Receive wheel events in fixed, unrotated coordinates, including the edge
    // corridor. Never attach scrolling input to the moving task content.
    DockWheelHandler { orientation: Qt.Vertical }
    DockWheelHandler { orientation: Qt.Horizontal }
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
            previewPanel.dismiss();
            const row = dockOptions.demo ? -1 : root.taskAt(eventPoint.position, false);
            // Include magnified icons so the menu does not cover their inner edge.
            let left = bar.x, top = bar.y, right = bar.x + bar.width, bottom = bar.y + bar.height;
            for (let i = 0; i < repeater.count; ++i) {
                const icon = repeater.itemAt(i).iconItem;
                const p = icon.mapToItem(root, 0, 0);
                if (p.x + icon.width <= 0 || p.y + icon.height <= 0 || p.x >= root.width || p.y >= root.height) continue;
                left = Math.min(left, Math.max(0, p.x)); top = Math.min(top, Math.max(0, p.y));
                right = Math.max(right, Math.min(root.width, p.x + icon.width)); bottom = Math.max(bottom, Math.min(root.height, p.y + icon.height));
            }
            const anchor = Interaction.menuAnchor(dockOptions.edge,
                Qt.rect(left, top, right - left, bottom - top), eventPoint.position, 6);
            contextMenu.showAt(Qt.point(anchor.x, anchor.y), dockOptions.demo ? null : taskSource.item, row);
        }
    }
    ContextMenu {
        id: contextMenu
        objectName: "dockMenu"
        onOpenedChanged: root.refreshHover()
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
        onHoveredChanged: root.refreshHover()
    }
}
