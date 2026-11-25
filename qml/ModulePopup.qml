// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls

Controls.Popup {
    id: popup
    required property var launcherActions
    required property Item host
    required property Item capsule
    required property Item paletteSource
    property int preferredWidth: 640
    property string moduleId: ""
    property url contentUrl
    readonly property var options: dockOptions.moduleSettings?.[moduleId] ?? ({})
    readonly property var radii: ["tl","tr","br","bl"].map(key => Number(options[key] ?? 10))
    readonly property int inset: Math.ceil(host.dockShadowPad + capsule.customBorderWidth + Math.max(0, -Math.min(...radii)) + 1)
    property Item keyboardSurface: null
    parent: keyboardSurface || host
    popupType: keyboardSurface ? Controls.Popup.Item : Controls.Popup.Window
    focus: true
    padding: 0
    property alias contextAnchor: nestedAnchor
    property size dragSize: Qt.size(0,0)
    readonly property bool verticalDock: dockOptions.edge >= 2
    property point trigger
    readonly property int panelWidth: Math.min(outputSize.width, (dragSize.width || Number(options.width ?? preferredWidth)) + inset * 2)
    readonly property int panelHeight: Math.min(outputSize.height, (dragSize.height || Number(options.height ?? 490)) + inset * 2)
    readonly property real along: verticalDock ? trigger.y : trigger.x
    readonly property int panelLength: verticalDock ? panelHeight : panelWidth
    readonly property int panelDepth: verticalDock ? panelWidth : panelHeight
    readonly property int dockGap: Math.max(0, host.modulePopupDepth - inset)

    // The grabbed popup must also be a valid parent for a context menu on the
    // farthest dock icon. Only the visible panel gets an input/blur region.
    readonly property int frameLength: keyboardSurface ? (verticalDock ? keyboardSurface.height : keyboardSurface.width) : Math.min(verticalDock ? outputSize.height : outputSize.width,
        Math.max(panelLength, Math.ceil(2 * Math.max(along, (verticalDock ? host.height : host.width) - along))))
    readonly property int frameDepth: keyboardSurface ? (verticalDock ? keyboardSurface.width : keyboardSurface.height) : Math.min(verticalDock ? outputSize.width : outputSize.height,
        Math.max(dockGap + panelDepth, verticalDock ? host.width : host.height))
    implicitWidth: verticalDock ? frameDepth : frameLength
    implicitHeight: verticalDock ? frameLength : frameDepth

    // KWin may slide the native window near a corner. Align the visible panel
    // with its button in the final window, clamping it to the available space.
    readonly property real buttonInFrame: along + (verticalDock
        ? (host.Window.window?.y ?? 0) - (canvas.Window.window?.y ?? 0)
        : (host.Window.window?.x ?? 0) - (canvas.Window.window?.x ?? 0))
    readonly property int panelStart: Math.round(Math.max(0, Math.min(frameLength - panelLength, buttonInFrame - panelLength / 2)))
    readonly property int panelInset: Math.min(dockGap, frameDepth - panelDepth)
    readonly property int panelX: !verticalDock ? panelStart : dockOptions.edge === 2 ? panelInset : frameDepth - panelDepth - panelInset
    readonly property int panelY: verticalDock ? panelStart : dockOptions.edge === 1 ? panelInset : frameDepth - panelDepth - panelInset
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    function showEntry(entry, icon) {
        if (visible) { close(); return; }
        const url = dockModules.metadata(entry.moduleId).popupUrl;
        if (!url) return;
        preferredWidth = entry.preferredPopupWidth || 640;
        moduleId = entry.moduleId;
        contentUrl = url;
        trigger = icon.mapToItem(host, icon.width/2, icon.height/2);
        const edge = dockOptions.edge;
        const ax = edge === 2 ? 0 : edge === 3 ? host.width - 1 : trigger.x;
        const ay = edge === 1 ? 0 : edge === 0 ? host.height - 1 : trigger.y;
        if (keyboardSurface) {
            x = 0; y = 0;
            open();
            return;
        }
        dockMenuAnchor.prepare(host, Qt.point(ax, ay), edge, false, true);
        x = edge === 2 ? ax : edge === 3 ? ax-width : ax-width/2;
        y = edge === 0 ? ay-height : edge === 1 ? ay : ay-height/2;
        open();
    }
    function refreshSurface() {
        if (opened) dockController.updatePopupSurface(surface, radii, dockOptions.edge >= 2, surface.customBorderWidth, !!dockOptions.systemBlur);
    }
    Component.onDestruction: if (keyboardSurface) keyboardSurface.Window.window.hide()
    onAboutToHide: if (keyboardSurface) keyboardSurface.Window.window.hide()
    onOpened: {
        if (loader.item) loader.item.forceActiveFocus();
        refreshSurface();
    }
    Connections {
        target: typeof dockModules === "undefined" ? null : dockModules
        function onEntriesChanged() {
            if (popup.visible && !dockModules.entries.some(e => e.moduleId === popup.moduleId && e.popup)) popup.close();
        }
    }
    background: Item {
        Item {
            x: popup.panelX; y: popup.panelY
            width: popup.panelWidth; height: popup.panelHeight
            onXChanged: Qt.callLater(popup.refreshSurface)
            onYChanged: Qt.callLater(popup.refreshSurface)
            CapsuleBackground {
                shadowEnabled: popup.host.dockShadowEnabled
                shadowTint: popup.paletteSource.resolve(dockOptions.dockShadowRole, dockOptions.dockShadowColor, popup.paletteSource.shadowColor)
                id: surface
                anchors.fill: parent
                anchors.margins: popup.inset
                corners: popup.radii
                edge: dockOptions.edge
                backgroundType: popup.capsule.backgroundType === 5 ? 0 : popup.capsule.backgroundType
                customBackgroundColor: popup.capsule.customBackgroundColor
                tintOpacity: popup.capsule.backgroundType === 5 ? popup.capsule.topOpacity : popup.capsule.tintOpacity
                customBorderColor: popup.capsule.customBorderColor
                customBorderWidth: popup.capsule.customBorderWidth
                borderOpacity: popup.capsule.borderOpacity
                onDrawingChanged: Qt.callLater(popup.refreshSurface)
                onXChanged: Qt.callLater(popup.refreshSurface)
                onYChanged: Qt.callLater(popup.refreshSurface)
            }
        }
    }
    // Put the handles in the input layer above the module content. The
    // background layer may be rendered into a texture for its shadow.
    contentItem: Item {
        id: canvas
        MouseArea {
            anchors.fill: parent
            enabled: !!popup.keyboardSurface
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                const p = mapToItem(surface, mouse.x, mouse.y);
                if (!surface.contains(p)) popup.close();
            }
        }
        Item { id: nestedAnchor; width: 1; height: 1 }
        Loader {
            id: loader
            x: popup.panelX + popup.inset + 8
            y: popup.panelY + popup.inset + 8
            width: Math.max(0, popup.panelWidth - 2 * (popup.inset + 8))
            height: Math.max(0, popup.panelHeight - 2 * (popup.inset + 8))
            active: popup.visible
            source: popup.contentUrl
            onLoaded: {
                item.configuration = Qt.binding(() => popup.options);
                if ("launcherActions" in item) item.launcherActions = Qt.binding(() => popup.launcherActions);
            }
            Connections {
                target: loader.item
                function onEdited(changes) { dockSettings.updateModuleSettings(popup.moduleId, changes); }
                function onDismiss() { popup.close(); }
            }
        }
        Repeater {
            model: [[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]]
            delegate: ResizeGrip {
                required property var modelData
                horizontal: modelData[0]
                vertical: modelData[1]
                readonly property real band: 8
                width: horizontal ? band : surface.width - 2*band
                height: vertical ? band : surface.height - 2*band
                x: popup.panelX + surface.x + (horizontal === 1 ? surface.width-band : horizontal === 0 ? band : 0)
                y: popup.panelY + surface.y + (vertical === 1 ? surface.height-band : vertical === 0 ? band : 0)
            }
        }
    }
    // Resize only along free axes. A corner on the dock-facing edge can
    // still resize parallel to that edge. Store logical pixels on release.
    property point resizeAxes
    property size resizeStart
    // Profile changes reach this window through a queued host update. Keep
    // the released size until it arrives to avoid a one-frame snap back.
    onOptionsChanged: {
        if (dragSize.width > 0 && options.width === dragSize.width && options.height === dragSize.height)
            dragSize = Qt.size(0, 0);
    }
    component ResizeGrip: MouseArea {
        required property int horizontal
        required property int vertical
        readonly property int dx: (dockOptions.edge === 2 && horizontal < 0) || (dockOptions.edge === 3 && horizontal > 0) ? 0 : horizontal
        readonly property int dy: (dockOptions.edge === 1 && vertical < 0) || (dockOptions.edge === 0 && vertical > 0) ? 0 : vertical
        enabled: dx !== 0 || dy !== 0
        cursorShape: !dx ? Qt.SizeVerCursor : !dy ? Qt.SizeHorCursor : dx === dy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
        onPressed: mouse => {
            popup.resizeAxes = Qt.point(dx, dy);
            popup.resizeStart = Qt.size(popup.panelWidth - 2*popup.inset, popup.panelHeight - 2*popup.inset);
            dockController.beginPopupResize(this, Qt.point(mouse.x, mouse.y));
        }
    }
    Connections {
        target: dockController
        function onPopupResizeMoved(delta) {
            popup.dragSize = Qt.size(
                Math.max(420, Math.min(outputSize.width - 2*popup.inset, Math.round(popup.resizeStart.width + popup.resizeAxes.x*delta.x))),
                Math.max(300, Math.min(outputSize.height - 2*popup.inset, Math.round(popup.resizeStart.height + popup.resizeAxes.y*delta.y))));
        }
        function onPopupResizeFinished(commit) {
            if (!commit || popup.dragSize.width <= 0 || popup.dragSize === popup.resizeStart
                || !dockSettings.updateModuleSettings(popup.moduleId, {width: popup.dragSize.width, height: popup.dragSize.height}))
                popup.dragSize = Qt.size(0, 0);
        }
    }
}
