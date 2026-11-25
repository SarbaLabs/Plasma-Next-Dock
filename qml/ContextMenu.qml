/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
// Focused standalone adaptation of KDE taskmanager's ContextMenu.qml.
// PlasmaExtras owns the native QMenu and its theme; no custom popup painting.
import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

Item {
    id: controller
    property var activeMenu: null
    property var launcherPopup: null
    property Item audioTarget: null
    readonly property bool hasTaskAudio: !!audioTarget && menuTarget.valid
        && audioTarget.taskIndex === menuTarget.index.row && audioTarget.streams.length > 0
    property var source: null
    property var moduleEntry: null
    property var moduleInfo: ({})
    signal configureModuleRequested(var moduleInfo)
    property string launcherUrl: ""
    property bool allPlaces: false
    readonly property bool visibleMenu: activeMenu !== null && activeMenu.status === PlasmaExtras.Menu.Open
    // Kept as an Item wrapper so menu lifetime never follows a moving task delegate.
    signal openedChanged(bool opened)
    signal testBounceRequested(int row)
    onVisibleMenuChanged: openedChanged(visibleMenu)
    readonly property string domain: "plasma_applet_org.kde.plasma.taskmanager"
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    Mpris.Mpris2Model { id: players }
    TextMetrics {
        id: actionMetrics
        font: Kirigami.Theme.defaultFont
        elide: Qt.ElideRight
        elideWidth: Kirigami.Units.gridUnit * 24
    }
    Item { id: anchorItem; width: 1; height: 1; LayoutMirroring.enabled: false }
    Component { id: menuFactory; PlasmaExtras.Menu {} }
    Component { id: itemFactory; PlasmaExtras.MenuItem {} }
    Connections {
        target: menuTarget
        function onInvalidated() { controller.close(); }
    }
    Connections {
        target: applicationMenus
        function onShowAllPlaces() {
            controller.allPlaces = true;
            // The old menu must finish handling its action before being destroyed.
            const oldMenu = controller.activeMenu;
            const status = controller.audioTarget;
            Qt.callLater(() => {
                if (oldMenu !== controller.activeMenu || !menuTarget.valid) return;
                controller.audioTarget = status;
                controller.buildAndOpen();
            });
        }
    }
    function get(role) { return menuTarget.data(role); }
    function kde(context, text) {
        const translated = i18ndc(domain, context, text);
        if (translated !== text) return translated;
        // Plasma 6.3 used a separate group-close context and stored most
        // other window actions directly under their source text.
        return text === "&Close All" ? i18ndc(domain, "@item:inmenu", text) : i18nd(domain, text);
    }
    function request(method, argument) {
        if (!menuTarget.valid || !source || !source.tasks) return;
        if (method === "requestNewInstance" && typeof source.launchRequested === "function")
            source.launchRequested(menuTarget.index.row);
        if (argument === undefined) source.tasks[method](menuTarget.index);
        else source.tasks[method](menuTarget.index, argument);
    }
    function add(menu, text, icon, callback, enabled, checked) {
        const item = itemFactory.createObject(menu, {
            text: text, icon: icon || "", enabled: enabled === undefined || !!enabled,
            checkable: checked !== undefined, checked: checked === undefined ? false : !!checked
        });
        if (callback) item.clicked.connect(callback);
        menu.addMenuItem(item);
        return item;
    }
    function separator(menu) {
        const item = itemFactory.createObject(menu, {separator: true});
        menu.addMenuItem(item);
    }
    function section(menu, text) {
        const item = itemFactory.createObject(menu, {text: text, section: true});
        menu.addMenuItem(item);
    }
    function submenu(menu, text, icon, enabled = true) {
        const item = add(menu, text, icon, null, enabled);
        return menuFactory.createObject(menu, {visualParent: item.action});
    }
    function actionItem(menu, action) {
        // Like the task manager, bound long recent URLs without shell parsing.
        actionMetrics.text = action.text.replace(/&/g, "&&");
        action.text = actionMetrics.elidedText;
        return itemFactory.createObject(menu, {action: action});
    }
    function appendActions(menu, title, actions) {
        if (!actions.length) return false;
        if (typeof actions[0] === "string") title = actions.shift();
        if (!actions.length) return false;
        section(menu, title);
        for (const action of actions) {
            const item = actionItem(menu, action);
            menu.addMenuItem(item);
        }
        return true;
    }
    function close() { if (activeMenu) activeMenu.close(); }
    function showAt(point, taskSource, row, status = null, module = {}, entry = null) {
        moduleEntry = entry;
        moduleInfo = module;
        close();
        source = taskSource;
        audioTarget = status;
        menuTarget.bind(source ? source.tasks : null, row);
        launcherUrl = menuTarget.valid ? String(get("LauncherUrlWithoutIcon") || get("LauncherUrl") || "") : "";
        allPlaces = false;
        anchorItem.x = point.x;
        anchorItem.y = point.y;
        buildAndOpen();
    }
    function addModuleActions(menu, actions, owner) {
        for (const action of actions) {
            if (action.children?.length) {
                const child = submenu(menu, action.text, action.icon, owner.enabled !== false && action.enabled !== false);
                addModuleActions(child, action.children, owner);
            } else add(menu, action.text, action.icon,
                () => dockModules.trigger(owner.moduleId, owner.id, action.id), owner.enabled !== false && action.enabled !== false);
        }
    }
    function buildAndOpen() {
        if (activeMenu) { activeMenu.close(); activeMenu.destroy(); activeMenu = null; }
        const placements = [PlasmaExtras.Menu.TopPosedLeftAlignedPopup, PlasmaExtras.Menu.BottomPosedLeftAlignedPopup,
            PlasmaExtras.Menu.RightPosedTopAlignedPopup, PlasmaExtras.Menu.LeftPosedTopAlignedPopup];
        const menu = menuFactory.createObject(controller, {visualParent: anchorItem, placement: placements[dockOptions.edge]});
        activeMenu = menu;
        menu.statusChanged.connect(() => {
            if (menu.status === PlasmaExtras.Menu.Closed) Qt.callLater(() => {
                if (menu === activeMenu && menu.status === PlasmaExtras.Menu.Closed)
                    controller.audioTarget = null;
            });
        });
        if (launcherUrl.length) {
            const places = applicationMenus.placesActions(launcherUrl, allPlaces, menu);
            const recent = places.length ? [] : applicationMenus.recentDocumentActions(launcherUrl, menu);
            appendActions(menu, kde("@title:group for section of menu items", "Places"), places);
            appendActions(menu, kde("@title:group for section of menu items", "Recent Files"), recent);
            const actions = applicationMenus.jumpListActions(launcherUrl, menu);
            if (actions.length && (places.length || recent.length)) {
                appendActions(menu, kde("@title:group for section of menu items", "Actions"), actions);
            } else {
                for (const action of actions) menu.addMenuItem(actionItem(menu, action));
            }
            addMedia(menu);
        }
        if (audioTarget) {
            const mute = add(menu, kde("@option:check inmenu, no separate unmute action", "Mute"), "audio-volume-muted",
                () => { if (hasTaskAudio) audioTarget.muteToggle(); }, true, false);
            mute.visible = Qt.binding(() => controller.hasTaskAudio);
            mute.checked = Qt.binding(() => controller.hasTaskAudio && controller.audioTarget.muted);
        }
        if (menuTarget.valid && get("CanLaunchNewInstance"))
            add(menu, kde("action:inmenu", "Open New Window"), "window-new", () => request("requestNewInstance"));
        if (menuTarget.valid && (get("IsWindow") || get("IsGroupParent"))) addWindowActions(menu);
        if (launcherUrl.length) {
            separator(menu);
            const url = launcherUrl;
            const pinned = source.pinned(url);
            add(menu, pinned ? i18n("Unpin from Dock") : i18n("Pin to Dock"), pinned ? "window-unpin" : "window-pin",
                () => source.togglePinned(url));
        }
        if (menuTarget.valid) {
            add(menu, i18n("Test Bounce Animation"), "view-refresh", () => {
                if (menuTarget.valid) controller.testBounceRequested(menuTarget.index.row);
            }, dockOptions.bounceEnabled !== false);
        }
        if (moduleEntry?.actions?.length) addModuleActions(menu, moduleEntry.actions, moduleEntry);
        separator(menu);
        if ((menuTarget.valid || moduleEntry) && moduleInfo.settingsUrl) {
            const owner = moduleInfo;
            add(menu, i18n("Configure module: %1…", owner.name), "configure",
                () => controller.configureModuleRequested(owner));
        }
        add(menu, i18n("Configure Plasma Next Dock…"), "configure", () => dockSettings.configure());
        add(menu, i18n("Quit Plasma Next Dock"), "application-exit", () => Qt.quit());
        // A second grabbed popup must use the open launcher's surface as parent.
        const nested = launcherPopup?.visible ? launcherPopup.contextAnchor : null;
        if (nested) {
            const click = anchorItem.mapToItem(nested.parent, 0, 0);
            nested.x = click.x;
            nested.y = click.y;
            menu.visualParent = nested;
        }
        dockMenuAnchor.prepareContextMenu(menu.visualParent, dockOptions.edge);
        menu.openRelative();
    }
    function addWindowActions(menu) {
        separator(menu);
        if (desktops.numberOfDesktops > 1 && get("IsVirtualDesktopsChangeable")) {
            const sub = submenu(menu, kde("action:inmenu", "Move to &Desktop"), "virtual-desktops");
            add(sub, kde("action:inmenu", "Move &To Current Desktop"), "", () => request("requestVirtualDesktops", [desktops.currentDesktop]));
            add(sub, kde("action:inmenu", "&All Desktops"), "", () => request("requestVirtualDesktops", []), true, get("IsOnAllVirtualDesktops"));
            separator(sub);
            for (let i = 0; i < desktops.desktopIds.length; ++i) {
                const id = desktops.desktopIds[i];
                add(sub, desktops.desktopNames[i], "", () => request("requestVirtualDesktops", [id]), true, (get("VirtualDesktops") || []).indexOf(id) >= 0);
            }
            separator(sub);
            add(sub, kde("action:inmenu", "&New Desktop"), "list-add", () => request("requestNewVirtualDesktop"));
        }
        if (activities.numberOfRunningActivities > 1) {
            const sub = submenu(menu, kde("action:inmenu", "Show in &Activities"), "activities");
            add(sub, kde("action:inmenu", "All Activities"), "", () => request("requestActivities", []), true, (get("Activities") || []).length === 0);
            for (const id of activities.runningActivities()) {
                add(sub, activities.activityName(id), activities.activityIcon(id), () => {
                    let ids = (get("Activities") || []).slice();
                    const i = ids.indexOf(id);
                    if (i < 0) ids.push(id); else ids.splice(i, 1);
                    request("requestActivities", ids);
                }, true, (get("Activities") || []).indexOf(id) >= 0);
            }
        }
        // Qt exposes actual QScreen objects. Older Plasma lacks requestSendToOutput.
        if (applicationMenus.screens().length > 1 && typeof source.tasks.requestSendToOutput === "function") {
            const sub = submenu(menu, kde("action:inmenu", "Move to &Screen"), "computer");
            for (const screen of applicationMenus.screens())
                add(sub, screen.name, "", () => request("requestSendToOutput", screen));
        }
        const more = submenu(menu, kde("item:inmenu opens submenu", "More"), "view-more-symbolic");
        const commands = [
            ["&Move", "transform-move", "requestMove", "IsMovable"],
            ["Re&size", "transform-scale", "requestResize", "IsResizable"],
            ["Ma&ximize", "window-maximize", "requestToggleMaximized", "IsMaximizable", "IsMaximized"],
            ["Mi&nimize", "window-minimize", "requestToggleMinimized", "IsMinimizable", "IsMinimized"],
            ["Keep &Above Others", "window-keep-above", "requestToggleKeepAbove", "", "IsKeepAbove"],
            ["Keep &Below Others", "window-keep-below", "requestToggleKeepBelow", "", "IsKeepBelow"],
            ["&Fullscreen", "view-fullscreen", "requestToggleFullScreen", "IsFullScreenable", "IsFullScreen"],
            ["&Shade", "window-shade", "requestToggleShaded", "IsShadeable", "IsShaded"]
        ];
        for (const command of commands) {
            if (typeof source.tasks[command[2]] !== "function") continue;
            add(more, kde("action:inmenu", command[0]), command[1], () => request(command[2]),
                !command[3] || get(command[3]), command[4] ? get(command[4]) : undefined);
        }
        if (typeof source.tasks.requestToggleNoBorder === "function")
            add(more, kde("@action:inmenu", "&No Titlebar and Frame"), "window",
                () => request("requestToggleNoBorder"), get("CanSetNoBorder"), !!get("HasNoBorder"));
        if (typeof source.tasks.requestToggleExcludeFromCapture === "function")
            add(more, kde("@action:inmenu", "&Hide from Screencast"), "view-hidden",
                () => request("requestToggleExcludeFromCapture"), true, !!get("IsExcludedFromCapture"));
        if (dockOptions.groupApplications !== false && source.toggleGrouping && (get("AppId") || launcherUrl)) {
            separator(more);
            add(more, kde("@option:check inmenu", "Allow this program to be grouped"), "",
                () => { if (menuTarget.valid) source.toggleGrouping(menuTarget.index); }, true, !!get("IsGroupable"));
        }
        const kills = menuTarget.killActions(menu);
        const processes = kills.processes || [];
        if (processes.length) {
            separator(more);
            if (processes.length > 1 || !kills.all) {
                const destination = processes.length === 1 ? more : submenu(more, i18n("Kill"), "process-stop");
                for (const action of processes) add(destination, action.text, "process-stop", () => action.trigger());
            }
            if (kills.all) add(more, kills.all.text, "process-stop", () => kills.all.trigger());
        }
        add(menu, get("IsGroupParent") ? kde("@action:inmenu", "&Close All") : kde("@action:inmenu", "&Close"), "window-close", () => request("requestClose"), get("IsClosable"));
    }
    function addMedia(menu) {
        if ((get("WinIdList") || []).length > 1) return;
        const player = players.playerForLauncherUrl(launcherUrl, get("AppPid") || 0);
        if (!player || !player.canControl) return;
        separator(menu);
        add(menu, kde("Play previous track", "Previous Track"), "media-skip-backward", () => player.Previous(), player.canGoPrevious);
        const pause = player.playbackStatus === Mpris.PlaybackStatus.Playing && player.canPause;
        add(menu, pause ? kde("Pause playback", "Pause") : kde("Start playback", "Play"), pause ? "media-playback-pause" : "media-playback-start",
            () => { if (pause) player.Pause(); else player.Play(); }, pause ? player.canPause : player.canPlay);
        add(menu, kde("Play next track", "Next Track"), "media-skip-forward", () => player.Next(), player.canGoNext);
        add(menu, kde("Stop playback", "Stop"), "media-playback-stop", () => player.Stop(), player.canStop);
        if (!get("IsWindow") && player.canRaise)
            add(menu, kde("Open or bring to the front window of media player app", "Restore"), "window-restore", () => player.Raise());
        if (!get("IsWindow") && player.canQuit)
            add(menu, kde("Quit media player app", "Quit"), "application-exit", () => player.Quit());
    }
}
