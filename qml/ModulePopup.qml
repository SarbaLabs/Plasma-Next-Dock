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
    padding: inset + 8
    property size dragSize: Qt.size(0,0)
    width: Math.min(outputSize.width, (dragSize.width || Number(options.width ?? preferredWidth)) + inset * 2)
    height: Math.min(outputSize.height, (dragSize.height || Number(options.height ?? 490)) + inset * 2)
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
        const ax = edge === 2 ? capsule.x + capsule.width : edge === 3 ? capsule.x : center.x;
        const ay = edge === 0 ? Math.min(capsule.y, center.y-icon.height/2) : edge === 1 ? Math.max(capsule.y+capsule.height, center.y+icon.height/2) : center.y;
        dockMenuAnchor.prepare(host, Qt.point(ax, ay), edge);
        x = edge === 2 ? ax : edge === 3 ? ax-width : ax-width/2;
        y = edge === 0 ? ay-height : edge === 1 ? ay : ay-height/2;
        open();
    }
    function refreshBlur() {
        if (opened) dockController.popupBlur(surface, radii, dockOptions.edge >= 2, !!dockOptions.systemBlur);
    }
    onWidthChanged: Qt.callLater(refreshBlur)
    onHeightChanged: Qt.callLater(refreshBlur)
    onOpened: {
        if (loader.item) loader.item.forceActiveFocus();
        refreshBlur();
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
    component ResizeGrip: MouseArea {
        required property int horizontal
        required property int vertical
        readonly property int dx: (dockOptions.edge === 2 && horizontal < 0) || (dockOptions.edge === 3 && horizontal > 0) ? 0 : horizontal
        readonly property int dy: (dockOptions.edge === 1 && vertical < 0) || (dockOptions.edge === 0 && vertical > 0) ? 0 : vertical
        enabled: dx !== 0 || dy !== 0
        cursorShape: !dx ? Qt.SizeVerCursor : !dy ? Qt.SizeHorCursor : dx === dy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
        property point start
        property size initial
        preventStealing: true
        onPressed: mouse => {
            start = mapToGlobal(mouse.x, mouse.y);
            initial = Qt.size(popup.width - 2*popup.inset, popup.height - 2*popup.inset);
        }
        onPositionChanged: mouse => {
            if (!pressed) return;
            const pt = mapToGlobal(mouse.x, mouse.y);
            popup.dragSize = Qt.size(Math.max(420, Math.min(outputSize.width - popup.inset*2, initial.width + dx*(pt.x-start.x))),
                                     Math.max(300, Math.min(outputSize.height - popup.inset*2, initial.height + dy*(pt.y-start.y))));
        }
        onReleased: {
            if (popup.dragSize.width > 0) dockSettings.updateModuleSettings(popup.moduleId, {width: Math.round(popup.dragSize.width), height: Math.round(popup.dragSize.height)});
            popup.dragSize = Qt.size(0,0);
        }
        onCanceled: popup.dragSize = Qt.size(0,0)
    }
    contentItem: Loader {
        id: loader
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
}
