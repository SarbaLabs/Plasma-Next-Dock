// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Window
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "code/AdaptiveLayout.js" as Adaptive
import "code/TaskBehavior.js" as Behavior

Item {
    id: root
    readonly property QtObject presentationTasks: dockOptions.demo ? null : taskSource.item?.tasks ?? null
    Mpris.Mpris2Model { id: statusPlayers }
    Loader {
        id: audioService
        active: !dockOptions.demo && (dockOptions.showAudioIndicator !== false || dockOptions.showMediaControls !== false || !!contextMenu.audioTarget)
        source: active ? "AudioService.qml" : ""
    }
    readonly property var taskRows: !dockOptions.demo && typeof dockTaskRows !== "undefined" ? dockTaskRows : null
    function nativeRow(visual) { return taskRows ? taskRows.nativeRow(visual) : visual; }
    function nativeSlot(sourceRow) { return repeater.slotAt(taskRows ? taskRows.visualRow(sourceRow) : sourceRow); }
    readonly property real bounceHeight: dockOptions.bounceEnabled === false ? 0
        : (dockOptions.bounceHeight > 0 ? dockOptions.bounceHeight : Math.min(10, Math.max(6, Math.round(dockOptions.iconSize * 0.18))))
    readonly property bool vertical: dockOptions.edge >= 2
    // Coalesce launcher-to-window row replacement before resizing the surface.
    property int layoutCount: 0
    property int separators: 0
    function syncTaskCount() {
        layoutCount = repeater.count;
        let leading = 0, trailing = 0, boundaries = 0;
        for (let row = 0; row < layoutCount; ++row) {
            const slot = repeater.slotAt(row);
            if (slot?.zone < 0) ++leading;
            if (slot?.zone > 0) ++trailing;
            if (slot?.separatorAfter) ++boundaries;
        }
        leadingCount = leading;
        trailingCount = trailing;
        separators = boundaries;
    }
    property int leadingCount: 0
    property int trailingCount: 0
    readonly property bool split: extended && !!dockOptions.splitExtendedDock
    readonly property bool extended: dockOptions.extendDock ?? false
    readonly property real outputLength: vertical ? outputSize.height : outputSize.width
    // Keep one icon accessible when moving a profile to a much smaller output.
    readonly property int extendedMargin: Math.min(dockOptions.alignmentMargin ?? 0,
        Math.max(0, Math.floor((outputLength - dockOptions.iconSize) / 2)))
    readonly property real availableLength: extended ? Math.max(1, outputLength - 2 * extendedMargin)
        : outputLength - 16 - 2 * endClearance
    // Retain room for an icon even if a saved margin exceeds the new output.
    readonly property int effectiveAlignmentMargin: extended || (dockOptions.dockAlignment ?? 1) === 1 ? 0
        : Math.min(dockOptions.alignmentMargin ?? 0, Math.max(0, Math.floor(availableLength - dockOptions.iconSize)))
    readonly property var layoutMetrics: Adaptive.metrics(layoutCount, dockOptions.iconSize,
        dockOptions.zoom, availableLength - effectiveAlignmentMargin,
        (vertical ? outputSize.width : outputSize.height) - (dockOptions.borderWidth ?? 1),
        dockOptions.spacing === undefined ? 8 : dockOptions.spacing,
        dockOptions.iconSpacing === undefined ? 10 : dockOptions.iconSpacing,
        dockOptions.horizontalPadding === undefined ? 12 : dockOptions.horizontalPadding,
        dockOptions.freeLayout ? 0 : (dockOptions.verticalPadding ?? 10),
        blastRadius, dockOptions.hoverLift === undefined ? 0 : dockOptions.hoverLift, bounceHeight, separators * 6,
        dockOptions.freeLayout ? dockOptions.capsuleThickness : 0, dockOptions.iconOffset ?? 0,
        split ? leadingCount + trailingCount : 0)
    readonly property real fitScale: layoutMetrics.scale
    readonly property real base: layoutMetrics.base
    readonly property real edgeSpacing: layoutMetrics.gap
    readonly property real maximum: base * dockOptions.zoom
    // A custom marker can extend inward beyond a thin free capsule even with
    // small icons. Its drawing space is independent of the exclusive zone.
    // The native surface is integer-sized. Snap its inward extent before
    // anchoring artwork at the bottom or right edge of that surface.
    readonly property int depth: Math.ceil(dockOptions.freeLayout && dockOptions.indicatorMode === 2
        ? Math.max(layoutMetrics.depth, Math.min((vertical ? outputSize.width : outputSize.height) - (dockOptions.borderWidth ?? 1),
            edgeSpacing + (dockOptions.indicatorEdgeDistance ?? 2) + 24))
        : layoutMetrics.depth)
    readonly property real length: extended ? availableLength : Math.min(Math.max(1, availableLength - effectiveAlignmentMargin),
        Math.max(layoutMetrics.length, occupiedLength))
    readonly property real taskPadding: (dockOptions.verticalPadding === undefined ? 10 : dockOptions.verticalPadding) * fitScale
    readonly property real endPadding: (dockOptions.horizontalPadding === undefined ? 12 : dockOptions.horizontalPadding) * fitScale
    readonly property bool dockShadowEnabled: dockOptions.dockShadowStrength > 0 && GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool iconShadowEnabled: dockOptions.iconShadowStrength > 0 && GraphicsInfo.api !== GraphicsInfo.Software
    readonly property int dockShadowPad: dockShadowEnabled ? (dockOptions.dockShadowSize + Math.max(Math.abs(dockOptions.dockShadowX), Math.abs(dockOptions.dockShadowY))) : 0
    readonly property int iconShadowPad: iconShadowEnabled ? (dockOptions.iconShadowSize + Math.max(Math.abs(dockOptions.iconShadowX), Math.abs(dockOptions.iconShadowY))) : 0
    readonly property int shadowExtent: Math.max(dockShadowPad, iconShadowPad)
    readonly property real canvasLength: length + 2 * endClearance
    readonly property real canvasDepth: depth + (dockOptions.borderWidth ?? 1)
    // Add transparent drawing space without moving the dock at an aligned end.
    readonly property real freeLength: Math.max(0, (vertical ? outputSize.height : outputSize.width) - canvasLength)
    readonly property int alignedPad: Math.min(shadowExtent, effectiveAlignmentMargin)
    readonly property int freePad: Math.min(shadowExtent, Math.floor(alignmentFactor === 0.5 ? freeLength / 2 : Math.max(0, freeLength - effectiveAlignmentMargin)))
    readonly property int startPad: extended ? extendedMargin : alignmentFactor === 0 ? alignedPad : freePad
    readonly property int endPad: extended ? extendedMargin : alignmentFactor === 1 ? alignedPad : freePad
    readonly property int surfaceMargin: effectiveAlignmentMargin - alignedPad
    readonly property real modulePopupDepth: reservedThickness + edgeSpacing
    // Wayland requires the popup anchor to lie inside the parent surface.
    // A large edge gap can put it beyond the drawing canvas. Keep the extra
    // transparent space outside the dock's input and exclusive regions.
    readonly property real popupAnchorPad: typeof dockModules !== "undefined" && dockModules.entries.some(entry => entry.popup)
        ? Math.max(0, modulePopupDepth + 1 - canvasDepth) : 0
    readonly property real inwardPad: Math.min(Math.max(shadowExtent, popupAnchorPad),
        Math.max(0, (vertical ? outputSize.width : outputSize.height) - canvasDepth))
    width: vertical ? canvasDepth + inwardPad : canvasLength + startPad + endPad
    height: vertical ? canvasLength + startPad + endPad : canvasDepth + inwardPad
    readonly property rect interactionBounds: Qt.rect(vertical ? (dockOptions.edge === 3 ? inwardPad : 0) : startPad,
        vertical ? startPad : (dockOptions.edge === 0 ? inwardPad : 0), vertical ? canvasDepth : canvasLength, vertical ? canvasLength : canvasDepth)
    property int dragDestination: -1
    property int trashDropRow: -1
    property string draggedLauncher: ""
    property int dragIndex: -1
    property var draggedModuleEntry: null
    readonly property bool dragging: dragIndex >= 0
    // Use the live row for capabilities: a volume can become busy or disappear
    // between the initial grab and release. Never retarget a replacement row.
    readonly property bool draggingUsbVolume: dragging && draggedModuleEntry?.moduleId === "org.sarbalabs.usb"
    readonly property string trashAction: {
        if (!dragging || !externalDrop.hasTrash) return "";
        const slot = repeater.slotAt(dragIndex);
        if (!draggedModuleEntry)
            return slot?.pinned && slot.launchKey === draggedLauncher ? "unpin" : "";
        const entry = slot?.entry;
        return entry?.id === draggedModuleEntry.id && entry.moduleId === draggedModuleEntry.moduleId
            && entry.trashDropAction === draggedModuleEntry.trashDropAction
            ? moduleTrashAction(entry) : "";
    }
    function moduleTrashAction(entry) {
        if (!entry || entry.enabled === false) return "";
        const action = entry.trashDropAction;
        return action && entry.actions?.some(item => item.id === action && item.enabled !== false) ? action : "";
    }
    readonly property int tooltipLocation: [PlasmaCore.Types.BottomEdge, PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge][dockOptions.edge]
    property Item keyboardItem: null
    readonly property bool keyboardActive: keyboardItem !== null
    onKeyboardActiveChanged: {
        if (!keyboardActive && previewPanel.keyboardOwner) previewPanel.dismiss();
        refreshHover();
    }
    function selectKeyboardRow(row) {
        keyboardItem = repeater.slotAt(row);
        if (!keyboardItem || (split && keyboardItem.zone !== 0)) return;
        const icon = keyboardItem.iconItem;
        const rect = icon.mapToItem(viewport.contentItem, Qt.rect(0, 0, icon.width, icon.height));
        if (rect.x < viewport.contentX) viewport.contentX = Math.max(0, rect.x);
        else if (rect.x + rect.width > viewport.contentX + viewport.width)
            viewport.contentX = Math.min(viewport.contentWidth - viewport.width, rect.x + rect.width - viewport.width);
    }
    function beginKeyboard() {
        if (!repeater.count || contextMenu.visibleMenu || dragging || externalDrop.containsDrag) return;
        previewPanel.dismiss();
        selectKeyboardRow(0);
        forceActiveFocus(Qt.ShortcutFocusReason);
    }
    Keys.onPressed: event => {
        if (!keyboardActive || contextMenu.visibleMenu) return;
        const selected = keyboardItem;
        const index = selected.index;
        if (index < 0 || repeater.slotAt(index) !== selected) { keyboardItem = null; return; }
        if (previewPanel.keyboardOwner && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_Escape) previewPanel.dismiss();
            else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
                if (!event.isAutoRepeat && previewPanel.activateKeyboardWindow()) keyboardItem = null;
            } else if (!previewPanel.moveKeyboardSelection(event.key)) return;
            event.accepted = true;
            return;
        }
        if ((event.key === Qt.Key_Menu && event.modifiers === Qt.NoModifier)
            || (event.key === Qt.Key_F10 && event.modifiers === Qt.ShiftModifier)) {
            event.accepted = true;
            if (!event.isAutoRepeat) {
                const icon = selected.iconItem;
                showContextMenu(index, icon.mapToItem(root, icon.width / 2, icon.height / 2));
            }
            return;
        }
        if (event.modifiers !== Qt.NoModifier) return;
        switch (event.key) {
        case Qt.Key_Escape: keyboardItem = null; break;
        case Qt.Key_Home: selectKeyboardRow(0); break;
        case Qt.Key_End: selectKeyboardRow(repeater.count - 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
            if (event.isAutoRepeat) break;
            if (selected.model.IsGroupParent) previewPanel.showForKeyboard(selected.previewOwner);
            else { keyboardItem = null; selected.activateEntry(); }
            break;
        default: {
            const next = vertical ? Qt.Key_Down : Qt.Key_Right;
            const previous = vertical ? Qt.Key_Up : Qt.Key_Left;
            if (event.key !== next && event.key !== previous) return;
            const delta = event.key === next ? 1 : -1;
            selectKeyboardRow((index + delta + repeater.count) % repeater.count);
        }
        }
        event.accepted = true;
    }
    function refreshHover() {
        dockController.setHovered(!!modulePopup.item?.visible || keyboardActive || dockController.pointerHovered || contextMenu.visibleMenu || dragging || externalDrop.containsDrag || previewPanel.displayed);
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
            const slot = repeater.slotAt(i);
            if (!slot || (split && !slot.zone && !viewport.contains(viewport.mapFromItem(root, position)))) continue;
            const p = slot.inputItem.mapFromItem(root, position.x, position.y);
            if (!nearest && p.x >= 0 && p.y >= 0 && p.x < slot.inputItem.width && p.y < slot.inputItem.height) return i;
            const center = slot.iconItem.mapToItem(root, slot.iconItem.width / 2, slot.iconItem.height / 2);
            const delta = Math.abs(vertical ? position.y - center.y : position.x - center.x);
            if (nearest && delta < distance) { distance = delta; result = i; }
        }
        return result;
    }
    // Only the Trash input lane is a removal target. The dragged icon can
    // cover it visually, so a generic first-hit lookup would select the source.
    function trashAt(position) {
        for (let row = 0; row < repeater.count; ++row) {
            const slot = repeater.slotAt(row);
            if (slot?.entry?.moduleId !== "org.sarbalabs.trash") continue;
            if (slot.inputItem.contains(slot.inputItem.mapFromItem(root, position))) return row;
        }
        return -1;
    }
    function finishDrag(commit = false, position = null) {
        if (!dragging) return;
        const from = dragIndex, to = dragDestination, source = draggedModuleEntry;
        const target = repeater.slotAt(to);
        const moving = repeater.slotAt(from);
        const action = commit && position && trashAt(position) >= 0 ? trashAction : "";
        trashDropRow = -1;
        dragIndex = -1;
        dragDestination = -1;
        if (action) {
            if (source) dockModules.trigger(source.moduleId, source.id, action);
            else if (taskSource.item.pinned(draggedLauncher))
                taskSource.item.togglePinned(draggedLauncher);
        } else if (commit && from !== to && target && moving) {
            if (source && moving.entry?.id === source.id && moving.entry.moduleId === source.moduleId
                && target.entry?.moduleId === source.moduleId && target.entry.reorderable)
                dockModules.moveEntry(source.moduleId, source.id, target.entry.id);
            else if (!source && !dockOptions.taskSort && moving.pinned && moving.launchKey === draggedLauncher && target.pinned
                     && taskSource.item.moveTask(nativeRow(from), nativeRow(to)))
                taskSource.item.finishMove();
        }
        draggedModuleEntry = null;
        root.refreshHover();
    }
    // Bound only overlapping zoom animation tails, not preferred icon sizes.
    property real animatedWeight: 0
    // Multiple neighbors advance in one animation tick. Publish their combined
    // width once, so the capsule path and blur never see intermediate sums.
    function syncAnimatedWeight() {
        let sum = 0;
        for (let row = 0; row < repeater.count; ++row)
            sum += repeater.slotAt(row)?.animatedFactor ?? 0;
        animatedWeight = sum;
    }
    readonly property int blastRadius: dockOptions.blastRadius === undefined ? 2 : dockOptions.blastRadius
    readonly property real zoomBudget: Adaptive.zoomBudget(blastRadius)
    readonly property real zoomBudgetScale: Math.min(1, zoomBudget / Math.max(zoomBudget, animatedWeight))
    property real pointerIndex: -10
    property var pointerTask: null
    property string pointerKey: ""
    property real pointerFraction: 0
    // Native proxies may move or replace the launcher while starting its first
    // window. Keep the hover anchor on that service until real pointer movement.
    function remapPointer() {
        if (!hovering || dragging) return;
        let slot = pointerTask;
        if (!slot || slot.index < 0 || repeater.slotAt(slot.index) !== slot) {
            slot = null;
            if (pointerKey) {
                for (let i = 0; i < repeater.count; ++i) {
                    const candidate = repeater.slotAt(i);
                    if (candidate && candidate.launchKey === pointerKey) { slot = candidate; break; }
                }
            }
        }
        if (slot) {
            const replacement = slot !== pointerTask;
            pointerTask = slot;
            pointerIndex = slot.index + pointerFraction;
            if (replacement) slot.restoreZoom();
        }
    }
    property bool hovering: dockController.pointerHovered
    property color applicationColor: Kirigami.Theme.highlightColor
    readonly property real barThickness: layoutMetrics.thickness
    readonly property real iconEdge: layoutMetrics.iconEdge
    // The exterior stroke belongs to the capsule only. A hidden stroke or
    // a protruding icon must not leave an empty band in the maximized area.
    readonly property real visibleBorderWidth: bar.borderOpacity > 0 && bar.customBorderColor.a > 0 ? bar.customBorderWidth : 0
    readonly property int reservedThickness: Math.ceil(Math.max(edgeSpacing + barThickness + visibleBorderWidth,
        layoutCount ? iconEdge + base : 0))
    readonly property real alignmentFactor: (dockOptions.dockAlignment ?? 1) / 2
    readonly property real barStart: startPad + endClearance + (length - barLength) * alignmentFactor
    // Row updates its implicit width during polish. Size the painted path from
    // the same slot metrics before polish so an idle frame has the final shape.
    readonly property int insertionRow: externalDrop.preview?.row ?? -1
    readonly property real insertionStride: base + taskRow.spacing
    property real insertionSpace: insertionRow >= 0 ? insertionStride : 0
    Behavior on insertionSpace {
        enabled: externalDrop.located
        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    readonly property real occupiedLength: insertionSpace + layoutMetrics.restingLength + (maximum - base) * animatedWeight * zoomBudgetScale
    readonly property real barLength: extended ? length : Math.min(length, Math.max(1, occupiedLength))

    // Match the exclusive depth, but only along the aligned dock at rest.
    readonly property rect dodgeBounds: {
        if (!dockOptions.freeLayout) return Qt.rect(0, 0, 0, 0);
        const span = extended ? length : Math.min(length, Math.max(1, layoutMetrics.restingLength));
        const start = startPad + endClearance + (length - span) * alignmentFactor;
        return vertical
            ? Qt.rect(dockOptions.edge === 2 ? 0 : width - reservedThickness, start, reservedThickness, span)
            : Qt.rect(start, dockOptions.edge === 1 ? 0 : height - reservedThickness, span, reservedThickness);
    }
    onDodgeBoundsChanged: queueGeometry()
    function updatePointer(position) {
        const coordinate = vertical ? position.y : position.x;
        let nearest = -1;
        let distance = Infinity;
        let fraction = 0;
        for (let i = 0; i < repeater.count; ++i) {
            const slot = repeater.slotAt(i);
            if (!slot) continue;
            if (split && slot.zone && viewport.contains(viewport.mapFromItem(root, position))) continue;
            if (split && !slot.zone) {
                if (!viewport.contains(viewport.mapFromItem(root, position))) continue;
                const local = slot.mapToItem(viewport, 0, 0);
                if (local.x + slot.size <= 0 || local.x >= viewport.width) continue;
            }
            const center = slot.mapToItem(root, slot.size / 2, slot.height / 2);
            const delta = coordinate - (vertical ? center.y : center.x);
            if (Math.abs(delta) < distance) {
                distance = Math.abs(delta);
                nearest = i;
                fraction = delta / (slot.size + taskRow.spacing);
            }
        }
        pointerTask = nearest < 0 ? null : repeater.slotAt(nearest);
        pointerKey = pointerTask ? pointerTask.launchKey : "";
        pointerFraction = fraction;
        pointerIndex = nearest < 0 ? -10 : nearest + fraction;
    }
    // Keep the hover band continuous between icons. During a crossing, the two
    // neighbours can both be smaller than the icon the pointer just left.
    readonly property real hoverDepth: iconEdge + bounceHeight * fitScale
        + (hovering ? maximum + (dockOptions.hoverLift ?? 0) * fitScale : base)
    onHoverDepthChanged: queueGeometry()
    function syncGeometry() {
        const start = Math.max(0, taskRow.x - viewport.contentX);
        const end = Math.min(viewport.width, taskRow.x + taskRow.width + insertionSpace - viewport.contentX);
        const y = dockOptions.edge === 1 || dockOptions.edge === 3 ? 0 : viewport.height - hoverDepth;
        const band = [];
        function include(item, x, width) {
            if (width > 0) band.push(item.mapToItem(root, Qt.rect(x, y, width, hoverDepth)));
        }
        if (split) {
            if (leadingCount) include(axisFrame, endPadding, axisFrame.leftWidth);
            if (trailingCount) include(axisFrame, axisFrame.width - endPadding - axisFrame.rightWidth, axisFrame.rightWidth);
            include(viewport, axisFrame.centerOffset, Math.min(axisFrame.centerSpan, viewport.width));
        } else if (repeater.count) include(viewport, start, end - start);
        dockController.setGeometry(Qt.rect(bar.x, bar.y, bar.width, bar.height), 0, band, dockOptions.edge, bar.corners, root.interactionBounds, root.dodgeBounds);
    }
    // KDE reads the delegate rectangle in surface-local coordinates on Wayland.
    // Use an unrotated item so vertical docks and clipped ends map correctly.
    Item { id: minimizeAnchor; visible: false }
    Timer {
        id: minimizeUpdates
        interval: 50
        onTriggered: {
            if (!root.Window.window?.visible || !taskSource.item?.publishMinimizeTarget) return;
            const centerBounds = viewport.mapToItem(root, Qt.rect(0, 0, viewport.width, viewport.height));
            const fullBounds = axisFrame.mapToItem(root, Qt.rect(0, 0, axisFrame.width, axisFrame.height));
            for (let row = 0; row < repeater.count; ++row) {
                const slot = repeater.slotAt(row);
                if (!slot?.windowIds) continue;
                const bounds = root.split && slot.zone ? fullBounds : centerBounds;
                const icon = slot.iconItem;
                const rect = icon.mapToItem(root, Qt.rect(0, 0, icon.width, icon.height));
                const x = Math.round(Math.max(bounds.x, Math.min(rect.x, (bounds.x + bounds.width) - 1)));
                const y = Math.round(Math.max(bounds.y, Math.min(rect.y, (bounds.y + bounds.height) - 1)));
                const width = Math.max(1, Math.round(Math.min((rect.x + rect.width), (bounds.x + bounds.width))) - x);
                const height = Math.max(1, Math.round(Math.min((rect.y + rect.height), (bounds.y + bounds.height))) - y);
                const target = Qt.rect(x, y, width, height);
                if (slot.lastMinimizeTarget === target && slot.publishedIds === slot.windowIds) continue;
                minimizeAnchor.x = x; minimizeAnchor.y = y;
                minimizeAnchor.width = width; minimizeAnchor.height = height;
                taskSource.item.publishMinimizeTarget(root.nativeRow(row), target, minimizeAnchor);
                slot.lastMinimizeTarget = target;
                slot.publishedIds = slot.windowIds;
            }
        }
    }
    Connections {
        target: root.Window.window
        function onVisibleChanged() { root.queueGeometry(); }
    }
    function queueGeometry() {
        Qt.callLater(syncGeometry);
        if (!dockOptions.demo && !minimizeUpdates.running) minimizeUpdates.start();
    }
    onWidthChanged: queueGeometry()
    onHeightChanged: queueGeometry()
    Component.onCompleted: {
        // Size the first layer-shell configure from the populated model.
        // Later row replacements still coalesce through onCountChanged.
        syncTaskCount();
        dockController.setPointerTarget(root);
        queueGeometry();
    }

    Loader {
        id: taskSource
        objectName: "taskSourceLoader"
        source: dockOptions.demo ? "DemoTasks.qml" : "LiveTasks.qml"
        onStatusChanged: if (status === Loader.Error) Qt.exit(1)
    }
    // KDE can replace a launcher delegate with a startup/window delegate during
    // requestActivate(). Retain finite feedback by service identity, never row.
    property var launchFeedback: ({})
    property int launchSerial: 0
    function rememberLaunch(slot) {
        if (!slot || dockOptions.bounceEnabled === false || dockOptions.bounceOnLaunch === false) return;
        if (!slot.launchKey) { Qt.callLater(() => { if (slot) slot.triggerLaunchBounce(); }); return; }
        const now = Date.now();
        const entries = {};
        const keys = Object.keys(launchFeedback).filter(key => launchFeedback[key].until > now).slice(-63);
        for (const key of keys) entries[key] = launchFeedback[key];
        const duration = 910 * 100 / Math.max(50, Math.min(200, dockOptions.bounceSpeed || 100))
            * Math.max(1, Math.min(5, dockOptions.bounceCount || 3));
        entries[slot.launchKey] = {token: ++launchSerial, until: now + duration};
        launchFeedback = entries;
        Qt.callLater(resumeLaunchFeedback);
    }
    function resumeLaunchFeedback() {
        for (let i = 0; i < repeater.count; ++i) {
            const slot = repeater.slotAt(i);
            if (slot) slot.resumeLaunchFeedback();
        }
    }
    Connections {
        target: taskSource.item
        ignoreUnknownSignals: true
        function onLaunchRequested(row) { root.rememberLaunch(root.nativeSlot(row)); }
    }
    Loader {
        id: modulePopup
        active: false
        function openEntry(entry, icon) {
            active = true;
            item.showEntry(entry, icon);
        }
        sourceComponent: ModulePopup {
            launcherActions: dockOptions.demo || !taskSource.item ? null : ({
                pinned: url => taskSource.item.pinned(url),
                togglePinned: url => taskSource.item.togglePinned(url)
            })
            host: root
            capsule: bar
            paletteSource: dockPalette
            onVisibleChanged: root.refreshHover()
            onClosed: modulePopup.active = false
        }
    }
    DockPalette { id: dockPalette }
    readonly property var corners: [dockOptions.topLeftRadius, dockOptions.topRightRadius,
        dockOptions.bottomRightRadius, dockOptions.bottomLeftRadius].map(r => r ?? dockOptions.radius ?? 10)
    readonly property real endClearance: extended ? 0 : (dockOptions.borderWidth ?? 1) + Math.min(dockOptions.freeLayout ? dockOptions.capsuleThickness / 2 : dockOptions.iconSize / 2 + (dockOptions.verticalPadding ?? 10), Math.max(0, -Math.min(...corners)))
    CapsuleBackground {
        shadowEnabled: root.dockShadowEnabled
        shadowTint: dockPalette.resolve(dockOptions.dockShadowRole, dockOptions.dockShadowColor ?? "black", dockPalette.shadowColor)
        id: bar
        objectName: "capsuleBackground"
        x: root.vertical ? (dockOptions.edge === 2 ? root.edgeSpacing : root.width - width - root.edgeSpacing) : root.barStart
        y: root.vertical ? root.barStart : (dockOptions.edge === 1 ? root.edgeSpacing : root.height - height - root.edgeSpacing)
        width: root.vertical ? root.barThickness : root.barLength
        height: root.vertical ? root.barLength : root.barThickness
        corners: root.corners
        readonly property color defaultTint: backgroundType !== 4 ? Kirigami.Theme.backgroundColor
            : Kirigami.Theme.backgroundColor.hslLightness < 0.5 ? "#1f1f26" : "#f5f7ff"
        customBackgroundColor: backgroundType === 5
            ? dockPalette.resolve(dockOptions.gradientTopRole, dockOptions.gradientTopColor, Kirigami.Theme.backgroundColor)
            : dockPalette.resolve(dockOptions.backgroundRole, dockOptions.backgroundColor, defaultTint)
        lowerColor: dockPalette.resolve(dockOptions.gradientBottomRole, dockOptions.gradientBottomColor, Kirigami.Theme.highlightColor)
        topOpacity: dockOptions.gradientTopOpacity ?? 1
        bottomOpacity: dockOptions.gradientBottomOpacity ?? 1
        borderOpacity: dockOptions.borderOpacity ?? 1
        backgroundType: dockOptions.backgroundType === undefined ? 0 : dockOptions.backgroundType
        tintOpacity: backgroundType === 4 ? (dockOptions.glassOpacity ?? 0.35) : (dockOptions.backgroundOpacity ?? 1)
        midpoint: (dockOptions.gradientMidpoint ?? 50) / 100
        customBorderWidth: dockOptions.borderWidth === undefined ? 1 : dockOptions.borderWidth
        customBorderColor: dockPalette.resolve(dockOptions.borderRole, dockOptions.borderColor, Kirigami.Theme.disabledTextColor)
        edge: dockOptions.edge
        glowEnabled: dockOptions.glow
        glowPosition: Qt.point(dockController.pointerPosition.x - bar.x, dockController.pointerPosition.y - bar.y)
        glowHovering: dockController.pointerHovered && fillShape.contains(glowPosition)
        glowColor: root.applicationColor
        glowRadius: dockOptions.glowRadius > 0 ? dockOptions.glowRadius : root.maximum
        glowIntensity: (dockOptions.glowIntensity ?? 100) / 100
        glowOpacity: (dockOptions.glowOpacity ?? 30) / 100
        onCornersChanged: root.queueGeometry()
        onXChanged: root.queueGeometry()
        onYChanged: root.queueGeometry()
        onWidthChanged: root.queueGeometry()
        onHeightChanged: root.queueGeometry()
    }
    // Rotate the layout axis only; icons counter-rotate to stay upright.
    Item {
        id: axisFrame
        width: root.length
        height: root.depth
        x: root.interactionBounds.x + (root.interactionBounds.width - width) / 2 + (root.vertical ? (dockOptions.edge === 2 ? -1 : 1) * (dockOptions.borderWidth ?? 1) / 2 : 0)
        y: root.interactionBounds.y + (root.interactionBounds.height - height) / 2 + (!root.vertical ? (dockOptions.edge === 1 ? -1 : 1) * (dockOptions.borderWidth ?? 1) / 2 : 0)
        rotation: root.vertical ? 90 : 0
        // The row measures every delegate in model order. Side delegates paint
        // on this fixed surface while the center uses the clipped Flickable.
        readonly property real gap: taskRow.spacing + 6 * root.fitScale
        readonly property real leftWidth: root.leadingCount ? (repeater.slotAt(root.leadingCount - 1)?.cellEnd ?? 0) : 0
        readonly property real rightStart: root.trailingCount ? (repeater.slotAt(root.layoutCount - root.trailingCount)?.cellStart ?? taskRow.width) : taskRow.width
        readonly property real rightWidth: root.trailingCount ? taskRow.width - rightStart : 0
        readonly property real centerStart: root.leadingCount ? leftWidth + taskRow.spacing : 0
        readonly property real centerWidth: Math.max(0, rightStart - (root.trailingCount ? taskRow.spacing : 0) - centerStart)
        readonly property int previewZone: !externalDrop.preview?.moduleId ? 0
            : (dockOptions.moduleZones?.left ?? []).includes(externalDrop.preview.moduleId) ? -1 : 1
        readonly property real leftInset: root.endPadding + (root.leadingCount ? leftWidth + gap : 0)
            + (previewZone < 0 ? root.insertionSpace : 0)
        readonly property real rightInset: root.endPadding + (root.trailingCount ? rightWidth + gap : 0)
            + (previewZone > 0 ? root.insertionSpace : 0)
        readonly property real centerSpan: centerWidth + (previewZone === 0 ? root.insertionSpace : 0)
        onLeftWidthChanged: root.queueGeometry()
        onRightWidthChanged: root.queueGeometry()
        onCenterSpanChanged: root.queueGeometry()
        readonly property real centerOffset: Math.max(0, Math.min(viewport.width - centerSpan,
            (width - centerSpan) * root.alignmentFactor - leftInset))
        Flickable {
            id: viewport
            objectName: "taskViewport"
            x: root.split ? axisFrame.leftInset : 0
            width: root.split ? Math.max(1, axisFrame.width - axisFrame.leftInset - axisFrame.rightInset) : axisFrame.width
            height: axisFrame.height
            clip: root.split || !root.iconShadowEnabled || contentWidth > width
            contentWidth: Math.max(width, root.split ? axisFrame.centerSpan : root.occupiedLength)
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
                layoutDirection: Qt.LeftToRight
                LayoutMirroring.enabled: false
                x: root.split ? axisFrame.centerOffset - axisFrame.centerStart : root.endPadding + Math.max(0, viewport.width - 2 * root.endPadding - width - root.insertionSpace) * root.alignmentFactor
                height: viewport.height
                spacing: (dockOptions.iconSpacing === undefined ? 10 : dockOptions.iconSpacing) * root.fitScale
                onXChanged: root.queueGeometry()
                onWidthChanged: root.queueGeometry()
                Repeater {
                    id: repeater
                    function slotAt(row) { return itemAt(row)?.visualSlot ?? null; }
                    model: taskSource.item ? (root.taskRows ? (root.taskRows.taskModel ? root.taskRows : null) : taskSource.item.tasks) : null
                    onCountChanged: { Qt.callLater(root.syncAnimatedWeight); Qt.callLater(root.remapPointer); Qt.callLater(root.syncTaskCount); previewPanel.dismiss(); root.finishDrag(); root.queueGeometry(); }
                    delegate: Item {
                        id: cell
                        required property int index
                        required property var model
                        width: visualSlot.width
                        height: viewport.height
                        property Item visualSlot: Item {
                            id: slot
                            readonly property int index: cell.index
                            readonly property var model: cell.model
                            readonly property int zone: model.dockZone ?? 0
                            readonly property real cellStart: cell.x
                            readonly property real cellEnd: cell.x + width
                            parent: root.split && (zone || root.dragIndex === index) ? axisFrame : cell
                            x: parent === cell ? 0 : !zone ? viewport.x + taskRow.x + cell.x - viewport.contentX
                                : zone < 0 ? root.endPadding + cell.x
                                : axisFrame.width - root.endPadding - (taskRow.width - cell.x)
                                    - (axisFrame.previewZone > 0 ? root.insertionSpace : 0)
                            objectName: "task" + index
                            onZoneChanged: Qt.callLater(root.syncTaskCount)
                            readonly property int nativeIndex: root.taskRows ? model.nativeTaskRow : index
                            readonly property var entry: root.taskRows ? model.moduleEntry : null
                            readonly property bool separatorAfter: !root.split && root.taskRows ? !!model.separatorAfter : false
                            // Keep logical slots fixed while their artwork makes room for the drop.
                            z: root.dragIndex === index ? 1 : 0
                            transform: Translate {
                                x: {
                                    if (!root.dragging) return root.insertionRow >= 0 && slot.index >= root.insertionRow && (!root.split || slot.zone === axisFrame.previewZone) ? root.insertionStride : 0;
                                    if (slot.index === root.dragIndex) {
                                        const p = slot.parent.mapFromItem(null, reorder.centroid.scenePosition.x, reorder.centroid.scenePosition.y);
                                        return p.x - slot.x - slot.size / 2;
                                    }
                                    const stride = (repeater.slotAt(root.dragIndex)?.size ?? root.base) + taskRow.spacing;
                                    if (slot.index > root.dragIndex && slot.index <= root.dragDestination) return -stride;
                                    if (slot.index < root.dragIndex && slot.index >= root.dragDestination) return stride;
                                    return 0;
                                }
                                Behavior on x {
                                    enabled: externalDrop.located || (root.dragging && root.dragIndex !== slot.index)
                                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                                }
                            }
                            onSeparatorAfterChanged: Qt.callLater(root.syncTaskCount)
                            function activateEntry() {
                                if (entry?.popup) modulePopup.openEntry(entry, icon);
                                else if (entry) dockModules.activate(entry.moduleId, entry.id);
                                else if (nativeIndex >= 0) taskSource.item.activate(nativeIndex);
                            }
                            readonly property bool taskHovered: !root.dragging && ((root.hovering && root.pointerTask === slot)
                                || (externalDrop.containsDrag && externalDrop.kind === "documents" && dropTarget.valid && dropTarget.index.row === nativeIndex))
                            onTaskHoveredChanged: if (taskHovered) root.applicationColor = colorLoader.item ? colorLoader.item.dominant : Kirigami.Theme.highlightColor
                            readonly property real factor: root.hovering && !root.dragging
                                && (!root.split || slot.zone === root.pointerTask?.zone) ? Adaptive.hoverWeight(root.pointerIndex - index, root.blastRadius) : 0
                            function restoreZoom() {
                                // A replacement can arrive at a different row. Reconcile
                                // its initial size before painting, without a shrink/grow.
                                zoomFrames.stop();
                                animatedFactor = factor;
                            }
                            property bool componentReady: false
                            property real animatedFactor: 0
                            onFactorChanged: {
                                if (!componentReady) return;
                                zoomFrames.remaining = dockOptions.hoverDuration ?? 90;
                                if (!zoomFrames.running) zoomFrames.start();
                            }
                            // Pointer events may arrive several times between paints. Update
                            // the target immediately, but keep the active frame clock running.
                            FrameAnimation {
                                id: zoomFrames
                                property real remaining: 0
                                onTriggered: {
                                    const dt = frameTime * 1000;
                                    if (dt >= remaining || Math.abs(slot.factor - slot.animatedFactor) < 0.001) {
                                        slot.animatedFactor = slot.factor;
                                        stop();
                                    } else {
                                        const fraction = 1 - Math.pow(1 - dt / remaining, 3);
                                        slot.animatedFactor += (slot.factor - slot.animatedFactor) * fraction;
                                        remaining -= dt;
                                    }
                                }
                            }
                            onAnimatedFactorChanged: Qt.callLater(root.syncAnimatedWeight)
                            readonly property real size: root.base + (root.maximum - root.base) * animatedFactor * root.zoomBudgetScale
                            property alias menuStatus: taskStatus
                            property alias previewOwner: taskTip
                            readonly property string windowIds: (model.WinIdList || []).join(",")
                            property string publishedIds: ""
                            property rect lastMinimizeTarget
                            onWindowIdsChanged: { publishedIds = ""; root.queueGeometry(); }
                            property alias iconItem: icon
                            property alias inputItem: inputLane
                            readonly property bool pinned: !!model.IsLauncher || !!model.HasLauncher
                            onIndexChanged: {

                                if (root.pointerTask === slot && index >= 0 && root.hovering && !root.dragging)
                                    root.pointerIndex = index + root.pointerFraction;
                                Qt.callLater(root.remapPointer);
                            }
                            readonly property string launchKey: String(model.LauncherUrlWithoutIcon || model.LauncherUrl || "")
                            property int launchToken: -1
                            function resumeLaunchFeedback() {
                                if (!root) return;
                                const pending = root.launchFeedback[launchKey];
                                if (!pending || pending.until <= Date.now() || pending.token === launchToken) return;
                                launchToken = pending.token;
                                bounce.launch();
                            }
                            onLaunchKeyChanged: { Qt.callLater(root.remapPointer); Qt.callLater(root.resumeLaunchFeedback); }
                            Component.onCompleted: { animatedFactor = factor; componentReady = true; Qt.callLater(root.remapPointer); Qt.callLater(root.resumeLaunchFeedback); }
                            width: size + (separatorAfter ? 6 * root.fitScale : 0)
                            Rectangle {
                                visible: slot.separatorAfter
                                objectName: "moduleSeparator" + slot.index
                                width: Math.max(1, root.fitScale)
                                height: root.base * 0.65
                                // Keep an appended shortcut on its own side of the separator.
                                property real previewOffset: root.insertionRow === slot.index + 1
                                    && (externalDrop.kind === "applications" ? slot.pinned
                                        : externalDrop.preview?.moduleId && externalDrop.preview.moduleId === slot.entry?.moduleId)
                                    ? root.insertionStride : 0
                                Behavior on previewOffset {
                                    enabled: externalDrop.located
                                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                                }
                                x: previewOffset + slot.size + (slot.width - slot.size + taskRow.spacing - width) / 2
                                y: (dockOptions.edge === 1 || dockOptions.edge === 3)
                                    ? root.iconEdge + (root.base - height) / 2
                                    : slot.height - root.iconEdge - (root.base + height) / 2
                                color: Kirigami.Theme.textColor
                                opacity: 0.45
                            }
                            height: viewport.height
                            onXChanged: root.queueGeometry()
                            onSizeChanged: root.queueGeometry()
                            // Follow the slot along the dock, but keep the capsule's
                            // resting cross-axis geometry throughout icon magnification.
                            Item {
                                width: slot.size
                                height: dockOptions.freeLayout ? root.barThickness : root.base
                                readonly property real edgeInset: dockOptions.freeLayout ? root.edgeSpacing : root.iconEdge
                                y: (dockOptions.edge === 1 || dockOptions.edge === 3)
                                    ? edgeInset
                                    : slot.height - height - edgeInset
                                z: -1
                                DockIndicators {
                                    objectName: "dockIndicators" + slot.index
                                    anchors.centerIn: parent
                                    anchors.alignWhenCentered: false
                                    width: root.vertical ? parent.height : parent.width
                                    height: root.vertical ? parent.width : parent.height
                                    rotation: root.vertical ? -90 : 0
                                    configuration: dockOptions
                                    task: slot.model
                                    taskIndex: slot.nativeIndex
                                    tasksModel: dockOptions.demo ? null : taskSource.item.tasks
                                    edge: dockOptions.edge
                                    padding: dockOptions.freeLayout ? 0 : root.taskPadding
                                    hovered: slot.taskHovered
                                    decorationExtent: icon.height + icon.lift + bounce.offset + (root.iconEdge - parent.edgeInset)
                                    dominantColor: colorLoader.item ? colorLoader.item.dominant : "transparent"
                                }
                            }
                            function triggerTestBounce() { bounce.test(); }
                            function triggerLaunchBounce() { bounce.launch(); }
                            TaskBounce {
                                id: bounce
                                objectName: "taskBounce" + slot.index
                                animationsEnabled: dockOptions.bounceEnabled !== false
                                launchEnabled: dockOptions.bounceOnLaunch !== false
                                attentionEnabled: dockOptions.bounceOnAttention !== false
                                attention: !!slot.model.IsDemandingAttention
                                startup: !!slot.model.IsStartup
                                suspended: root.dragging || previewPanel.displayed || dockController.hideRequested
                                amplitude: root.bounceHeight * root.fitScale
                                speed: dockOptions.bounceSpeed || 100
                                repetitions: dockOptions.bounceCount || 3
                            }
                            TaskStatus {
                                id: taskStatus
                                task: slot.model
                                taskIndex: slot.nativeIndex
                                tasksModel: dockOptions.demo ? null : taskSource.item.tasks
                                audio: audioService.item
                                players: statusPlayers
                                nativeEnabled: !dockOptions.demo && !slot.entry
                                audioEnabled: dockOptions.showAudioIndicator !== false || dockOptions.showMediaControls !== false || contextMenu.audioTarget === taskStatus
                                launcherEnabled: dockOptions.showBadges !== false || dockOptions.showProgress !== false
                            }
                            // A task owns its full inward animation envelope down to the
                            // physical screen edge. Bounce never moves its hit target.
                            Item {
                                id: inputLane
                                objectName: "taskInput" + slot.index
                                width: slot.size
                                height: root.iconEdge + slot.size + icon.lift + bounce.amplitude
                                y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? 0 : slot.height - height
                                onYChanged: root.queueGeometry()
                                onHeightChanged: root.queueGeometry()
                                TapHandler {
                                    enabled: !overlays.audioHovered
                                    onTapped: {
                                        if (reorder.active) return;
                                        if (slot.model.IsGroupParent && !dockOptions.groupClick) taskTip.showGroupWindows();
                                        else if (slot.model.IsGroupParent && dockOptions.groupClick === 1) {
                                            previewPanel.dismiss(); taskSource.item.cycle(root.nativeRow(slot.index), 1);
                                        }
                                        else { previewPanel.dismiss(); slot.activateEntry(); }
                                    }
                                }
                                TapHandler {
                                    objectName: "middleClick" + slot.index
                                    acceptedButtons: Qt.MiddleButton
                                    enabled: !slot.entry && !dockOptions.demo && !overlays.audioHovered && dockOptions.middleClick > 0
                                    onTapped: { previewPanel.dismiss(); taskSource.item.middle(root.nativeRow(slot.index)); }
                                }
                            }
                            Rectangle {
                                visible: root.keyboardItem === slot
                                anchors.fill: icon
                                radius: 5
                                color: "transparent"
                                border.width: 2
                                border.color: Kirigami.Theme.focusColor
                                z: icon.z + 1
                            }
                            Item {
                                id: icon
                                objectName: "icon" + slot.index
                                width: slot.size; height: width
                                // After a clockwise rotation, local bottom is the screen's left.
                                readonly property real lift: (dockOptions.hoverLift === undefined ? 0 : dockOptions.hoverLift) * root.fitScale * slot.animatedFactor * root.zoomBudgetScale
                                y: (dockOptions.edge === 1 || dockOptions.edge === 3)
                                    ? root.iconEdge + lift + bounce.offset
                                    : slot.height - height - root.iconEdge - lift - bounce.offset
                                onYChanged: root.queueGeometry()
                                rotation: root.vertical ? -90 : 0
                                opacity: slot.entry?.enabled === false ? 0.45 : (root.dragIndex === slot.index ? 0.65 : 1)
                                readonly property bool active: dockOptions.iconHoverHighlight !== false && slot.taskHovered
                                TaskIconArtwork {
                                    anchors.centerIn: parent
                                    maximumSize: root.maximum
                                    paintedSize: icon.width
                                    shadowPadding: root.iconShadowPad
                                    shadowEnabled: root.iconShadowEnabled
                                    highlighted: icon.active || (!!root.trashAction && root.trashDropRow === slot.index)
                                    iconSource: {
                                        if (slot.entry?.moduleId === "org.sarbalabs.trash") {
                                            if (root.draggingUsbVolume) return "media-eject";
                                            if (root.trashAction) return "window-unpin";
                                        }
                                        return slot.entry?.icon || slot.model.decoration;
                                    }
                                    paletteSource: dockPalette
                                }
                                Loader {
                                    active: slot.entry?.moduleId === "org.sarbalabs.trash" && root.draggingUsbVolume && !root.trashAction
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    width: parent.width * 0.52
                                    height: width
                                    sourceComponent: Rectangle {
                                        color: "#c83232"
                                        radius: width / 2
                                        border.color: "white"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            font.bold: true
                                            font.pixelSize: parent.height * 0.85
                                            color: "white"
                                        }
                                    }
                                }
                                PlasmaCore.ToolTipArea {
                                    id: taskTip
                                    property bool forceWindows: false
                                    function showGroupWindows() {
                                        forceWindows = true;
                                        // An already visible title tooltip may not emit aboutToShow again.
                                        if (previewPanel.toolTip === taskTip) previewPanel.windowsEnabled = true;
                                        showToolTip();
                                    }
                                    onToolTipVisibleChanged: toolTipVisible => {
                                        if (!toolTipVisible) forceWindows = false;
                                    }
                                    objectName: "taskTip" + slot.index
                                    anchors.fill: parent
                                    location: root.tooltipLocation
                                    mainText: slot.entry?.tooltip || slot.entry?.name || slot.model.AppName || slot.model.display || ""
                                    textFormat: Text.PlainText
                                    mainItem: previewPanel
                                    interactive: !slot.entry && (!!slot.model.IsWindow || !!slot.model.IsGroupParent || dockOptions.showMediaControls !== false)
                                    // Deactivating any ToolTipArea schedules dismissal of Plasma's shared popup.
                                    // Settle the active areas when selecting the task, before Enter opens it.
                                    active: !root.dragging && !modulePopup.item?.visible && !contextMenu.visibleMenu && (!root.keyboardActive || root.keyboardItem === slot)
                                    onAboutToShow: {
                                        previewPanel.windowsEnabled = !slot.entry && (dockOptions.showWindowPreviews !== false || forceWindows);
                                        forceWindows = false;
                                        previewPanel.status = slot.entry ? null : taskStatus;
                                        previewPanel.applicationName = mainText;
                                        previewPanel.applicationIcon = slot.entry?.icon || slot.model.decoration;
                                        if (slot.entry) windowPreviews.clear();
                                        else windowPreviews.select(dockOptions.demo ? null : taskSource.item.tasks, slot.nativeIndex);
                                    }
                                }
                                StatusOverlay {
                                    id: overlays
                                    anchors.fill: parent
                                    z: 2
                                    status: taskStatus
                                    configuration: dockOptions
                                }
                            }
                            Loader {
                                id: colorLoader
                                active: bar.drawGlow || (dockOptions.indicatorMode === 2
                                    && dockOptions.customIndicatorsEnabled !== false && dockOptions.indicatorColorSource === 1
                                    && (!!slot.model.IsWindow || !!slot.model.IsGroupParent))
                                sourceComponent: Kirigami.ImageColors {
                                    source: slot.model.decoration
                                    onPaletteChanged: if (slot.taskHovered) root.applicationColor = dominant
                                }
                            }
                            Rectangle {
                                // Each USB partition reports its own state, independently of the task indicator style.
                                readonly property bool volume: typeof slot.entry?.mounted === "boolean"
                                visible: volume || ((dockOptions.indicatorMode === undefined || dockOptions.indicatorMode === 0)
                                    && (!!slot.model.IsWindow || !!slot.model.IsGroupParent))
                                width: (volume ? 9 : 4) * root.fitScale; height: width; radius: width / 2
                                x: (slot.size - width) / 2
                                objectName: "macIndicator" + slot.index
                                readonly property real dotInset: root.edgeSpacing + (dockOptions.freeLayout ? 0 : 4 * root.fitScale)
                                y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? dotInset : slot.height - dotInset - height
                                color: volume ? (slot.entry.mounted ? "#39bb69" : "#e65354")
                                              : slot.model.IsActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                                border.width: volume ? 1 : 0
                                border.color: "#77202020"
                                // A horizontal mark also identifies the unmounted state without relying on hue.
                                Loader {
                                    active: parent.volume && !slot.entry.mounted
                                    anchors.centerIn: parent
                                    width: parent.width * 0.55
                                    height: Math.max(1, parent.height * 0.18)
                                    rotation: root.vertical ? -90 : 0
                                    sourceComponent: Rectangle { color: "white"; radius: height / 2 }
                                }
                            }
                        }
                    }
                }
            }
        }
        // Fixed separators appear independently when the pinned row reaches a side.
        Repeater {
            model: root.split ? 2 : 0
            Rectangle {
                required property int index
                objectName: "zoneSeparator" + index
                visible: axisFrame.centerWidth > 0 && (root.alignmentFactor === 0.5 || axisFrame.centerSpan >= viewport.width)
                    && (index === 0
                    ? root.leadingCount > 0 && axisFrame.centerOffset <= 0
                    : root.trailingCount > 0 && axisFrame.centerOffset + axisFrame.centerSpan >= viewport.width)
                width: Math.max(1, root.fitScale)
                height: root.base * 0.65
                x: (index === 0 ? viewport.x - axisFrame.gap / 2 : viewport.x + viewport.width + axisFrame.gap / 2) - width / 2
                y: (dockOptions.edge === 1 || dockOptions.edge === 3)
                    ? root.iconEdge + (root.base - height) / 2
                    : axisFrame.height - root.iconEdge - (root.base + height) / 2
                color: Kirigami.Theme.textColor
                opacity: 0.45
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
        if (viewport.contentWidth <= viewport.width || (split && !viewport.contains(viewport.mapFromItem(root, event.x, event.y)))) {
            const row = root.taskAt(Qt.point(event.x, event.y), false);
            if (row < 0 || root.nativeRow(row) < 0 || dockOptions.demo || dockOptions.wheelAction !== 1) { event.accepted = false; return; }
            const direction = Behavior.wheelCycle(axis === Qt.Vertical ? angle.y : angle.x,
                axis === Qt.Vertical ? pixel.y : pixel.x);
            if (direction) taskSource.item.cycle(root.nativeRow(row), direction);
            event.accepted = true;
            return;
        }
        viewport.contentX = Adaptive.scrollPosition(viewport.contentX,
            -(axis === Qt.Vertical ? delta.y : delta.x), viewport.contentWidth, viewport.width);
        root.updatePointer(Qt.point(event.x, event.y));
        event.accepted = true;
    }
    component DockWheelHandler: WheelHandler {
        target: null
        enabled: (viewport.contentWidth > viewport.width || dockOptions.wheelAction === 1) && !contextMenu.visibleMenu
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
                const row = root.taskAt(p, false);
                const slot = repeater.slotAt(row);
                if (slot && !slot.entry && !slot.pinned && slot.nativeIndex >= 0 && slot.launchKey) {
                    previewPanel.dismiss();
                    launcherResolver.dragTaskLauncher(root.Window.window, slot.launchKey);
                    return;
                }
                const hasTrash = externalDrop.hasTrash;
                // USB volumes can also be dragged to show why the target is unavailable.
                root.draggedModuleEntry = slot?.entry?.reorderable || (hasTrash
                    && (slot?.entry?.moduleId === "org.sarbalabs.usb" || root.moduleTrashAction(slot?.entry)))
                    ? slot.entry : null;
                root.dragIndex = root.draggedModuleEntry || (slot?.pinned && (!dockOptions.taskSort || hasTrash)) ? row : -1;
                root.draggedLauncher = slot?.launchKey ?? "";
                root.dragDestination = root.dragIndex;
                if (root.dragging) dockController.setHovered(true);
            }
        }
        onGrabChanged: (transition, point) => {
            if (transition === PointerDevice.UngrabExclusive) root.finishDrag(true, root.mapFromItem(null, point.scenePosition));
            else if (transition === PointerDevice.CancelGrabExclusive) root.finishDrag();
        }
        onActiveTranslationChanged: {
            if (!active || !root.dragging) return;
            const p = root.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
            root.trashDropRow = root.trashAction ? root.trashAt(p) : -1;
            if (root.trashDropRow >= 0 || (root.draggedModuleEntry ? !root.draggedModuleEntry.reorderable : dockOptions.taskSort)) {
                root.dragDestination = root.dragIndex;
                return;
            }

            // Hit-test layout positions, independent of animated translations.
            let nearest = root.dragIndex, distance = Infinity;
            for (let i = 0; i < repeater.count; ++i) {
                const slot = repeater.slotAt(i);
                if (!slot || (root.draggedModuleEntry
                    ? slot.entry?.moduleId !== root.draggedModuleEntry.moduleId || !slot.entry?.reorderable
                    : !slot.pinned)) continue;
                const axis = slot.parent.mapFromItem(root, p.x, p.y).x;
                const delta = Math.abs(axis - slot.x - slot.size / 2);
                if (delta < distance) { nearest = i; distance = delta; }
            }
            root.dragDestination = nearest;
        }
    }
    function dismissKeyboardMenu() {
        if (modulePopup.item?.keyboardSurface) modulePopup.item.close();
    }
    function toggleApplicationsMenu() {
        for (let i = 0; i < repeater.count; ++i) {
            const slot = repeater.slotAt(i);
            if (slot?.entry?.moduleId === "org.sarbalabs.appmenu" && slot.entry.popup) {
                if (modulePopup.item?.visible) modulePopup.item.close();
                else {
                    modulePopup.active = true;
                    modulePopup.item.keyboardSurface = dockHost.keyboardMenuSurface();
                    modulePopup.item.showEntry(slot.entry, slot.iconItem);
                }
                return;
            }
        }
    }
    function showContextMenu(row, position) {
        previewPanel.dismiss();
        contextMenu.showAt(position, dockOptions.demo ? null : taskSource.item, root.nativeRow(row),
                           row >= 0 && root.nativeRow(row) >= 0 ? repeater.slotAt(row)?.menuStatus : null,
                           root.taskRows?.settingsForRow(row) || {}, row >= 0 ? repeater.slotAt(row)?.entry : null);
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        onTapped: eventPoint => root.showContextMenu(dockOptions.demo ? -1 : root.taskAt(eventPoint.position, false), eventPoint.position)
    }
    ExternalDrop {
        id: externalDrop
        scrollView: viewport
        anchors.fill: parent
        enabled: !dockOptions.demo && !root.dragging
        tasksSource: taskSource.item
        resolver: launcherResolver
        target: dropTarget
        hitTest: point => root.nativeRow(root.taskAt(point, false))
        directoryReceiver: typeof dockModules === "undefined" ? null : dockModules
        readonly property bool hasTrash: typeof dockModules !== "undefined" && dockModules.entries.some(entry => entry.moduleId === "org.sarbalabs.trash")
        hasLocalMoveTarget: typeof dockModules !== "undefined" && dockModules.entries.some(entry => entry.localFileMove)
        moduleEntryAt: point => repeater.slotAt(root.taskAt(point, false))?.entry
        moduleDrop: (point, urls) => {
            const entry = moduleEntryAt(point);
            if (entry?.acceptsDocuments === undefined) return undefined;
            return entry.acceptsDocuments && dockModules.dropDocuments(entry.moduleId, entry.id, urls);
        }
        // Resolve launcher aliases once per drag, outside the pointer-motion path.
        readonly property var pinnedIds: kind === "applications"
            ? dockSettings.values.launchers.map(url => String(url).startsWith("applications:") ? String(url) : launcherResolver.launcher(url)) : []
        readonly property bool addingLauncher: launchers.some(id => !pinnedIds.includes(id))
        // A running task may be pinned only in the launcher section. Use layout
        // coordinates plus the visible gap so animated icons never fight hit testing.
        pinZoneContains: point => {
            if (root.split) return viewport.contains(viewport.mapFromItem(root, point));
            const axis = taskRow.mapFromItem(root, point.x, point.y).x;
            const leading = dockOptions.moduleZones?.left ?? [];
            let start = 0, end = taskRow.width;
            for (let row = 0; row < repeater.count; ++row) {
                const slot = repeater.slotAt(row);
                if (!slot || slot.pinned) continue;
                const owner = slot.entry?.moduleId || root.taskRows?.settingsForRow(row)?.id;
                if (leading.includes(owner)) start = slot.cellEnd;
                else { end = slot.cellStart; break; }
            }
            // Also expose an empty launcher section next to its module boundary.
            const margin = Math.max(taskRow.spacing / 2, root.base / 4);
            return axis >= start - margin && axis <= end + root.insertionSpace + margin;
        }
        insertionAt: (point, payloadKind) => {
            const folders = payloadKind === "directories";
            if (!folders && (dockOptions.taskSort || !addingLauncher)) return null;
            let last = null, firstTrailing = repeater.count;
            const leading = dockOptions.moduleZones?.left ?? [];
            for (let row = 0; row < repeater.count; ++row) {
                const slot = repeater.slotAt(row);
                if (!slot) continue;
                if (folders) {
                    if (!slot.entry?.directoryInsertion) continue;
                } else if (!slot.pinned || slot.entry) {
                    if (!last && firstTrailing === repeater.count) {
                        const owner = slot.entry?.moduleId || root.taskRows?.settingsForRow(row)?.id;
                        if (!leading.includes(owner)) firstTrailing = row;
                    }
                    continue;
                }
                last = slot;
                if (slot.mapFromItem(root, point.x, point.y).x < slot.size / 2)
                    return {row: row, before: folders ? slot.entry.id : slot.launchKey, moduleId: slot.entry?.moduleId};
            }
            if (folders && !last) return null; // Empty or automatically sorted provider.
            return {row: last ? last.index + 1 : firstTrailing, before: "", moduleId: last?.entry?.moduleId};
        }
        onGroupHovered: row => {
            const slot = root.nativeSlot(row);
            if (slot) previewPanel.showForDrag(slot.previewOwner);
        }
        onTargetChangedDuringDrag: row => {
            if (row >= 0 && previewPanel.dragOwner !== root.nativeSlot(row)?.previewOwner)
                previewPanel.endDrag();
        }
        onContainsDragChanged: {
            if (containsDrag) previewPanel.dismiss();
            else previewPanel.leaveDock();
            root.refreshHover();
        }
        onDropped: previewPanel.endDrag()
        onOpenedFiles: row => root.rememberLaunch(root.nativeSlot(row))
    }
    ModuleSettingsHost { id: moduleSettingsWindow; profile: dockSettings }
    ContextMenu {
        launcherPopup: modulePopup.item
        onConfigureModuleRequested: module => moduleSettingsWindow.open(module)
        id: contextMenu
        objectName: "dockMenu"
        onOpenedChanged: root.refreshHover()
        onTestBounceRequested: row => {
            previewPanel.dismiss();
            const slot = root.nativeSlot(row);
            if (slot) slot.triggerTestBounce();
        }
    }
    Controls.Label {
        anchors.centerIn: bar
        visible: repeater.count === 0
        text: qsTr("Plasma Next Dock")
    }
    Connections {
        target: dockController
        function onPointerPositionChanged() { root.updatePointer(dockController.pointerPosition); }
        function onPointerHoveredChanged() { root.refreshHover(); }
    }
}
