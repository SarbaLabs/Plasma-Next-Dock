// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Window
import QtQuick.Effects
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "code/InteractionGeometry.js" as Interaction
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
    function nativeSlot(sourceRow) { return repeater.itemAt(taskRows ? taskRows.visualRow(sourceRow) : sourceRow); }
    readonly property real bounceHeight: dockOptions.bounceEnabled === false ? 0
        : (dockOptions.bounceHeight > 0 ? dockOptions.bounceHeight : Math.min(10, Math.max(6, Math.round(dockOptions.iconSize * 0.18))))
    readonly property bool vertical: dockOptions.edge >= 2
    // Coalesce launcher-to-window row replacement before resizing the surface.
    property int layoutCount: 0
    property int separators: 0
    function syncTaskCount() {
        layoutCount = repeater.count;
        let boundaries = 0;
        for (let row = 0; row < repeater.count; ++row)
            if (repeater.itemAt(row)?.separatorAfter) ++boundaries;
        separators = boundaries;
    }
    readonly property real availableLength: (vertical ? outputSize.height : outputSize.width) - 16 - 2 * endClearance
    // Retain room for an icon even if a saved margin exceeds the new output.
    readonly property int effectiveAlignmentMargin: (dockOptions.dockAlignment ?? 1) === 1 ? 0
        : Math.min(dockOptions.alignmentMargin ?? 0, Math.max(0, Math.floor(availableLength - dockOptions.iconSize)))
    readonly property var layoutMetrics: Adaptive.metrics(layoutCount, dockOptions.iconSize,
        dockOptions.zoom, availableLength - effectiveAlignmentMargin,
        (vertical ? outputSize.width : outputSize.height) - (dockOptions.borderWidth ?? 1),
        dockOptions.spacing === undefined ? 8 : dockOptions.spacing,
        dockOptions.iconSpacing === undefined ? 10 : dockOptions.iconSpacing,
        dockOptions.horizontalPadding === undefined ? 12 : dockOptions.horizontalPadding,
        dockOptions.freeLayout ? 0 : (dockOptions.verticalPadding ?? 10),
        blastRadius, dockOptions.hoverLift === undefined ? 0 : dockOptions.hoverLift, bounceHeight, separators * 6,
        dockOptions.freeLayout ? dockOptions.capsuleThickness : 0, dockOptions.iconOffset ?? 0)
    readonly property real fitScale: layoutMetrics.scale
    readonly property real base: layoutMetrics.base
    readonly property real edgeSpacing: layoutMetrics.gap
    readonly property real maximum: base * dockOptions.zoom
    // A custom marker can extend inward beyond a thin free capsule even with
    // small icons. Its drawing space is independent of the exclusive zone.
    readonly property real depth: dockOptions.freeLayout && dockOptions.indicatorMode === 2
        ? Math.max(layoutMetrics.depth, Math.min((vertical ? outputSize.width : outputSize.height) - (dockOptions.borderWidth ?? 1),
            edgeSpacing + (dockOptions.indicatorEdgeDistance ?? 2) + 24))
        : layoutMetrics.depth
    readonly property real length: layoutMetrics.length
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
    readonly property int startPad: alignmentFactor === 0 ? alignedPad : freePad
    readonly property int endPad: alignmentFactor === 1 ? alignedPad : freePad
    readonly property int surfaceMargin: effectiveAlignmentMargin - alignedPad
    readonly property real inwardPad: Math.min(shadowExtent, Math.max(0, (vertical ? outputSize.width : outputSize.height) - canvasDepth))
    width: vertical ? canvasDepth + inwardPad : canvasLength + startPad + endPad
    height: vertical ? canvasLength + startPad + endPad : canvasDepth + inwardPad
    readonly property rect interactionBounds: Qt.rect(vertical ? (dockOptions.edge === 3 ? inwardPad : 0) : startPad,
        vertical ? startPad : (dockOptions.edge === 0 ? inwardPad : 0), vertical ? canvasDepth : canvasLength, vertical ? canvasLength : canvasDepth)
    property int dragIndex: -1
    property var draggedModuleEntry: null
    readonly property bool dragging: dragIndex >= 0
    readonly property int tooltipLocation: [PlasmaCore.Types.BottomEdge, PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge][dockOptions.edge]
    property Item keyboardItem: null
    readonly property bool keyboardActive: keyboardItem !== null
    onKeyboardActiveChanged: {
        if (!keyboardActive && previewPanel.keyboardOwner) previewPanel.dismiss();
        refreshHover();
    }
    function selectKeyboardRow(row) {
        keyboardItem = repeater.itemAt(row);
        if (!keyboardItem) return;
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
        if (index < 0 || repeater.itemAt(index) !== selected) { keyboardItem = null; return; }
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
        dockController.setHovered(keyboardActive || dockController.pointerHovered || contextMenu.visibleMenu || dragging || externalDrop.containsDrag || previewPanel.displayed);
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
            if (!slot) continue;
            const p = slot.inputItem.mapFromItem(root, position.x, position.y);
            if (!nearest && p.x >= 0 && p.y >= 0 && p.x < slot.inputItem.width && p.y < slot.inputItem.height) return i;
            const center = slot.iconItem.mapToItem(root, slot.iconItem.width / 2, slot.iconItem.height / 2);
            const delta = Math.abs(vertical ? position.y - center.y : position.x - center.x);
            if (nearest && delta < distance) { distance = delta; result = i; }
        }
        return result;
    }
    function finishDrag() {
        if (!dragging) return;
        dragIndex = -1;
        if (!draggedModuleEntry && taskSource.item && taskSource.item.finishMove) taskSource.item.finishMove();
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
            sum += repeater.itemAt(row)?.animatedFactor ?? 0;
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
        if (!slot || slot.index < 0 || repeater.itemAt(slot.index) !== slot) {
            slot = null;
            if (pointerKey) {
                for (let i = 0; i < repeater.count; ++i) {
                    const candidate = repeater.itemAt(i);
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
    readonly property int reservedThickness: Math.ceil(Math.max(edgeSpacing + barThickness, layoutCount ? iconEdge + base : 0) + (dockOptions.borderWidth ?? 1))
    readonly property real alignmentFactor: (dockOptions.dockAlignment ?? 1) / 2
    readonly property real barStart: startPad + endClearance + (length - barLength) * alignmentFactor
    // Row updates its implicit width during polish. Size the painted path from
    // the same slot metrics before polish so an idle frame has the final shape.
    readonly property real occupiedLength: layoutMetrics.restingLength + (maximum - base) * animatedWeight * zoomBudgetScale
    readonly property real barLength: Math.min(length, Math.max(1, occupiedLength))

    // Match the exclusive depth, but only along the aligned dock at rest.
    readonly property rect dodgeBounds: {
        if (!dockOptions.freeLayout) return Qt.rect(0, 0, 0, 0);
        const span = Math.min(length, Math.max(1, layoutMetrics.restingLength));
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
            const slot = repeater.itemAt(i);
            if (!slot) continue;
            const center = slot.mapToItem(root, slot.size / 2, slot.height / 2);
            const delta = coordinate - (vertical ? center.y : center.x);
            if (Math.abs(delta) < distance) {
                distance = Math.abs(delta);
                nearest = i;
                fraction = delta / (slot.size + taskRow.spacing);
            }
        }
        pointerTask = nearest < 0 ? null : repeater.itemAt(nearest);
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
        const end = Math.min(viewport.width, taskRow.x + taskRow.width - viewport.contentX);
        const y = dockOptions.edge === 1 || dockOptions.edge === 3 ? 0 : viewport.height - hoverDepth;
        const band = end > start && repeater.count
            ? [viewport.mapToItem(root, Qt.rect(start, y, end - start, hoverDepth))] : [];
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
            const bounds = viewport.mapToItem(root, Qt.rect(0, 0, viewport.width, viewport.height));
            for (let row = 0; row < repeater.count; ++row) {
                const slot = repeater.itemAt(row);
                if (!slot?.windowIds) continue;
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
            const slot = repeater.itemAt(i);
            if (slot) slot.resumeLaunchFeedback();
        }
    }
    Connections {
        target: taskSource.item
        ignoreUnknownSignals: true
        function onLaunchRequested(row) { root.rememberLaunch(root.nativeSlot(row)); }
    }
    DockPalette { id: dockPalette }
    readonly property var corners: [dockOptions.topLeftRadius, dockOptions.topRightRadius,
        dockOptions.bottomRightRadius, dockOptions.bottomLeftRadius].map(r => r ?? dockOptions.radius ?? 10)
    readonly property real endClearance: (dockOptions.borderWidth ?? 1) + Math.min(dockOptions.freeLayout ? dockOptions.capsuleThickness / 2 : dockOptions.iconSize / 2 + (dockOptions.verticalPadding ?? 10), Math.max(0, -Math.min(...corners)))
    Item {
        id: dockArtwork
        anchors.fill: parent
        layer.enabled: root.dockShadowEnabled
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            shadowEnabled: true
            blurMax: Math.max(1, dockOptions.dockShadowSize ?? 0)
            shadowBlur: dockOptions.dockShadowSize > 0 ? 1 : 0
            shadowHorizontalOffset: dockOptions.dockShadowX ?? 0
            shadowVerticalOffset: dockOptions.dockShadowY ?? 2
            shadowOpacity: (dockOptions.dockShadowStrength ?? 0) / 100
            shadowColor: dockPalette.resolve(dockOptions.dockShadowRole, dockOptions.dockShadowColor ?? "black", dockPalette.shadowColor)
        }
    }
    CapsuleBackground {
        parent: dockArtwork
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
    Flickable {
        id: viewport
        objectName: "taskViewport"
        width: root.length
        height: root.depth
        x: root.interactionBounds.x + (root.interactionBounds.width - width) / 2 + (root.vertical ? (dockOptions.edge === 2 ? -1 : 1) * (dockOptions.borderWidth ?? 1) / 2 : 0)
        y: root.interactionBounds.y + (root.interactionBounds.height - height) / 2 + (!root.vertical ? (dockOptions.edge === 1 ? -1 : 1) * (dockOptions.borderWidth ?? 1) / 2 : 0)
        rotation: root.vertical ? 90 : 0
        clip: !root.iconShadowEnabled || contentWidth > width
        contentWidth: Math.max(width, root.occupiedLength)
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
            x: root.endPadding + Math.max(0, viewport.width - 2 * root.endPadding - width) * root.alignmentFactor
            height: viewport.height
            spacing: (dockOptions.iconSpacing === undefined ? 10 : dockOptions.iconSpacing) * root.fitScale
            onXChanged: root.queueGeometry()
            onWidthChanged: root.queueGeometry()
            Repeater {
                id: repeater
                model: taskSource.item ? (root.taskRows ? (root.taskRows.taskModel ? root.taskRows : null) : taskSource.item.tasks) : null
                onCountChanged: { Qt.callLater(root.syncAnimatedWeight); Qt.callLater(root.remapPointer); Qt.callLater(root.syncTaskCount); previewPanel.dismiss(); root.finishDrag(); root.queueGeometry(); }
                delegate: Item {
                    id: slot
                    objectName: "task" + index
                    required property int index
                    required property var model
                    readonly property int nativeIndex: root.taskRows ? model.nativeTaskRow : index
                    readonly property var entry: root.taskRows ? model.moduleEntry : null
                    readonly property bool separatorAfter: root.taskRows ? !!model.separatorAfter : false
                    onSeparatorAfterChanged: Qt.callLater(root.syncTaskCount)
                    function activateEntry() {
                        if (entry) dockModules.activate(entry.moduleId, entry.id);
                        else if (nativeIndex >= 0) taskSource.item.activate(nativeIndex);
                    }
                    readonly property bool taskHovered: !root.dragging && ((root.hovering && root.pointerTask === slot)
                        || (externalDrop.containsDrag && externalDrop.kind === "documents" && dropTarget.valid && dropTarget.index.row === nativeIndex))
                    onTaskHoveredChanged: if (taskHovered) root.applicationColor = colorLoader.item ? colorLoader.item.dominant : Kirigami.Theme.highlightColor
                    readonly property real factor: root.hovering && !root.dragging ? Adaptive.hoverWeight(root.pointerIndex - index, root.blastRadius) : 0
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
                        x: slot.size + (slot.width - slot.size + taskRow.spacing - width) / 2
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
                            highlighted: icon.active
                            iconSource: slot.entry?.icon || slot.model.decoration
                            paletteSource: dockPalette
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
                            mainText: slot.entry?.name || slot.model.AppName || slot.model.display || ""
                            textFormat: Text.PlainText
                            mainItem: previewPanel
                            interactive: !slot.entry && (!!slot.model.IsWindow || !!slot.model.IsGroupParent || dockOptions.showMediaControls !== false)
                            // Deactivating any ToolTipArea schedules dismissal of Plasma's shared popup.
                            // Settle the active areas when selecting the task, before Enter opens it.
                            active: !root.dragging && !contextMenu.visibleMenu && (!root.keyboardActive || root.keyboardItem === slot)
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
                        visible: (dockOptions.indicatorMode === undefined || dockOptions.indicatorMode === 0) && (!!slot.model.IsWindow || !!slot.model.IsGroupParent)
                        width: 4 * root.fitScale; height: width; radius: width / 2
                        x: (slot.size - width) / 2
                        objectName: "macIndicator" + slot.index
                        readonly property real dotInset: root.edgeSpacing + (dockOptions.freeLayout ? 0 : 4 * root.fitScale)
                        y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? dotInset : slot.height - dotInset - height
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
        if (viewport.contentWidth <= viewport.width) {
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
                const slot = repeater.itemAt(row);
                root.draggedModuleEntry = slot?.entry?.reorderable ? slot.entry : null;
                root.dragIndex = root.draggedModuleEntry || (slot?.pinned && !dockOptions.taskSort) ? row : -1;
                if (root.dragging) dockController.setHovered(true);
            } else root.finishDrag();
        }
        onActiveTranslationChanged: {
            if (!active || !root.dragging) return;
            const p = root.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
            const targetIndex = root.taskAt(p, true);
            if (targetIndex < 0 || targetIndex === root.dragIndex) return;
            const target = repeater.itemAt(targetIndex);
            const source = root.draggedModuleEntry;
            if (source) {
                if (target?.entry?.moduleId === source.moduleId && target.entry.reorderable
                    && dockModules.moveEntry(source.moduleId, source.id, target.entry.id))
                    root.dragIndex = targetIndex;
            } else if (!dockOptions.taskSort && target?.pinned
                       && taskSource.item.moveTask(root.nativeRow(root.dragIndex), root.nativeRow(targetIndex))) {
                root.dragIndex = targetIndex;
            }
        }
    }
    function showContextMenu(row, position) {
        previewPanel.dismiss();
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
            Qt.rect(left, top, right - left, bottom - top), position, 6);
        contextMenu.showAt(Qt.point(anchor.x, anchor.y), dockOptions.demo ? null : taskSource.item, root.nativeRow(row),
                           row >= 0 && root.nativeRow(row) >= 0 ? repeater.itemAt(row)?.menuStatus : null,
                           root.taskRows?.settingsForRow(row) || {}, row >= 0 ? repeater.itemAt(row)?.entry : null);
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
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
        hasLocalMoveTarget: typeof dockModules !== "undefined" && dockModules.entries.some(entry => entry.localFileMove)
        moduleEntryAt: point => repeater.itemAt(root.taskAt(point, false))?.entry
        moduleDrop: (point, urls) => {
            const entry = moduleEntryAt(point);
            if (entry?.acceptsDocuments === undefined) return undefined;
            return entry.acceptsDocuments && dockModules.dropDocuments(entry.moduleId, entry.id, urls);
        }
        insertionAnchor: point => {
            const list = dockSettings.values.launchers;
            const canonical = list.map(url => launcherResolver.launcher(url));
            const coordinate = root.vertical ? point.y : point.x;
            let nearest = -1, distance = Infinity, centerCoordinate = 0;
            // Select a pinned boundary even when dropping over the unpinned group.
            for (let row = 0; row < repeater.count; ++row) {
                const slot = repeater.itemAt(row);
                const url = slot.model.LauncherUrlWithoutIcon || slot.model.LauncherUrl || "";
                const id = launcherResolver.launcher(url);
                const index = id ? canonical.indexOf(id) : -1;
                if (index < 0) continue;
                const center = slot.iconItem.mapToItem(root, slot.iconItem.width / 2, slot.iconItem.height / 2);
                const axis = root.vertical ? center.y : center.x;
                if (Math.abs(axis - coordinate) < distance) {
                    distance = Math.abs(axis - coordinate); nearest = index; centerCoordinate = axis;
                }
            }
            if (nearest < 0) return "";
            const before = coordinate < centerCoordinate;
            return before ? list[nearest] : (list[nearest + 1] || "");
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
