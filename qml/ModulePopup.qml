// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Effects

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
    parent: host
    popupType: Controls.Popup.Window
    focus: true
    padding: 0
    property size dragSize: Qt.size(0,0)
    // Qt 6.8 propagates the implicit size to an already open popup window.
    implicitWidth: Math.min(outputSize.width, (dragSize.width || Number(options.width ?? preferredWidth)) + inset * 2)
    implicitHeight: Math.min(outputSize.height, (dragSize.height || Number(options.height ?? 490)) + inset * 2)
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    function showEntry(entry, icon) {
        if (visible) { close(); return; }
        const url = dockModules.metadata(entry.moduleId).popupUrl;
        if (!url) return;
        preferredWidth = entry.preferredPopupWidth || 640;
        moduleId = entry.moduleId;
        contentUrl = url;
        const center = icon.mapToItem(host, icon.width/2, icon.height/2);
        const edge = dockOptions.edge;
        // Measure the gap between the resting dock and the menu surface.
        // Its transparent shadow inset may overlap the gap.
        const offset = host.modulePopupDepth - inset;
        const ax = edge === 2 ? offset : edge === 3 ? host.width - offset : center.x;
        const ay = edge === 1 ? offset : edge === 0 ? host.height - offset : center.y;
        const availableDepth = (host.vertical ? outputSize.width : outputSize.height) - host.modulePopupDepth;
        const needsCrossSlide = (host.vertical ? width : height) - inset > availableDepth;
        dockMenuAnchor.prepare(host, Qt.point(ax, ay), edge, needsCrossSlide);
        x = edge === 2 ? ax : edge === 3 ? ax-width : ax-width/2;
        y = edge === 0 ? ay-height : edge === 1 ? ay : ay-height/2;
        open();
    }
    function refreshSurface() {
        if (opened) dockController.updatePopupSurface(surface, radii, dockOptions.edge >= 2, surface.customBorderWidth, !!dockOptions.systemBlur);
    }
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
        layer.enabled: popup.host.dockShadowEnabled
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            shadowEnabled: true
            blurMax: Math.max(1, dockOptions.dockShadowSize ?? 0)
            shadowBlur: dockOptions.dockShadowSize > 0 ? 1 : 0
            shadowHorizontalOffset: dockOptions.dockShadowX ?? 0
            shadowVerticalOffset: dockOptions.dockShadowY ?? 2
            shadowOpacity: (dockOptions.dockShadowStrength ?? 0)/100
            shadowColor: popup.paletteSource.resolve(dockOptions.dockShadowRole, dockOptions.dockShadowColor, popup.paletteSource.shadowColor)
        }
        CapsuleBackground {
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
    // Put the handles in the input layer above the module content. The
    // background layer may be rendered into a texture for its shadow.
    contentItem: Item {
        Loader {
            id: loader
            anchors.fill: parent
            anchors.margins: popup.inset + 8
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
                x: surface.x + (horizontal === 1 ? surface.width-band : horizontal === 0 ? band : 0)
                y: surface.y + (vertical === 1 ? surface.height-band : vertical === 0 ? band : 0)
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
            popup.resizeStart = Qt.size(popup.width - 2*popup.inset, popup.height - 2*popup.inset);
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
