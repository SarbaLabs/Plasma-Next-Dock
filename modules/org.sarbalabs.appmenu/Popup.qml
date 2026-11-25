// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as C
import QtQuick.Layouts
import QtQml.Models
import org.kde.kirigami as K
import org.kde.kirigamiaddons.components as Components
import org.kde.coreaddons as Core
import org.kde.config as Config
import org.kde.kcmutils as KCM
import "native" as Native

FocusScope {
    id: page
    property var configuration: ({})
    property var launcherActions: null
    signal edited(var changes)
    signal dismiss()
    readonly property var currentView: stack.currentItem
    readonly property var history: currentView?.path ?? []
    readonly property int wheelSpeed: Math.max(1, Math.min(10, configuration.wheelSpeed ?? 4))
    property int revision: 0
    readonly property string searchTerm: search.text.trim()
    readonly property bool searching: searchTerm.length > 0
    readonly property bool favoritesPage: !searching && history.length === 0
    readonly property var favorites: configuration.favorites ?? ["org.kde.dolphin.desktop", "org.kde.konsole.desktop"]
    readonly property int format: configuration.format ?? 0
    Native.Catalog { id: catalog; onChanged: ++page.revision }
    Loader {
        id: runner
        active: page.searching
        sourceComponent: Native.SearchModel {
            queryString: page.searchTerm
            onQueryStringChangeRequested: (query, pos) => {
                search.text = query;
                search.cursorPosition = pos;
                search.forceActiveFocus();
            }
        }
    }
    function group(path, sorted) { page.revision; return catalog.group(path, sorted); }
    function navigate(path, transition) {
        const hadFocus = currentView.activeFocus;
        const next = stack.replaceCurrentItem(contents, {path: path}, transition);
        if (hadFocus && next) next.forceActiveFocus();
    }
    function back() {
        if (!searching && history.length > 1)
            navigate(history.slice(0, -1), C.StackView.PopTransition);
    }
    function enter(row) {
        if (row.group && history.length) navigate(history.concat([row]), C.StackView.PushTransition);
        else if (row.group) currentView.path = [row];
        else { catalog.launch(row.id); dismiss(); }
    }
    function updateFavorite(id) {
        const next = favorites.includes(id) ? favorites.filter(f => f !== id) : favorites.concat([id]);
        edited({favorites: next});
    }
    function moveFavorite(id, destination) {
        if (!favoritesPage || id === destination || !favorites.includes(destination)) return;
        shiftFavorite(id, favorites.indexOf(destination) - favorites.indexOf(id));
    }
    function shiftFavorite(id, offset) {
        const next = favorites.slice();
        const index = next.indexOf(id);
        if (index < 0 || index + offset < 0 || index + offset >= next.length) return;
        next.splice(index, 1);
        next.splice(index + offset, 0, id);
        edited({favorites: next});
    }
    Shortcut { sequence: "Alt+Left"; enabled: !page.searching && page.history.length > 1; onActivated: page.back() }
    component PaneSlide: Transition {
        id: slide
        required property real start
        required property real end
        NumberAnimation {
            property: "x"
            from: slide.start
            to: slide.end
            duration: K.Units.longDuration
            easing.type: Easing.InOutCubic
        }
    }
    component MenuWheel: WheelHandler {
        id: wheelHandler
        required property real notch
        required property Flickable list
        parent: list
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property NumberAnimation motion: NumberAnimation {
            target: wheelHandler.list
            property: "contentY"
            duration: K.Units.shortDuration
            easing.type: Easing.OutCubic
        }
        onWheel: event => {
            const pixels = event.pixelDelta.y;
            const delta = -(pixels || event.angleDelta.y / 120 * notch) * page.wheelSpeed;
            if (!delta) return;
            // Wayland also reports discrete wheel ticks as touchpad pixel deltas.
            // Only a phased pixel stream should bypass the wheel animation.
            const continuous = pixels !== 0 && event.phase !== Qt.NoScrollPhase;
            // Accumulate quick notches but respond immediately to a direction reversal.
            const remaining = !continuous && motion.running ? motion.to - list.contentY : 0;
            const start = list.contentY + (remaining * delta > 0 ? remaining : 0);
            const end = Math.max(list.originY, Math.min(list.originY + list.contentHeight - list.height, start + delta));
            motion.stop();
            if (continuous)
                list.contentY = end;
            else if (end !== list.contentY) {
                motion.from = list.contentY;
                motion.to = end;
                motion.start();
            }
            event.accepted = true;
        }
    }
    ColumnLayout {
        anchors.fill: parent
        RowLayout {
            Layout.fillWidth: true
            C.ItemDelegate {
                id: profile
                Core.KUser { id: user }
                readonly property string displayName: user.fullName || user.loginName
                enabled: Config.KAuthorized.authorizeControlModule("kcm_users")
                Layout.maximumWidth: page.width / 2
                Accessible.name: displayName
                Accessible.description: i18n("Open user settings")
                contentItem: RowLayout {
                    Components.Avatar {
                        Layout.preferredWidth: K.Units.iconSizes.medium
                        Layout.preferredHeight: K.Units.iconSizes.medium
                        name: profile.displayName
                        source: user.faceIconUrl
                        cache: false
                    }
                    C.Label {
                        Layout.fillWidth: true
                        text: profile.displayName
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                }
                C.ToolTip.visible: hovered
                C.ToolTip.text: Accessible.description
                onClicked: {
                    KCM.KCMLauncher.openSystemSettings("kcm_users");
                    page.dismiss();
                }
            }
            K.SearchField {
                id: search
                objectName: "menuSearch"
                Layout.fillWidth: true
                focus: true
                autoAccept: false
                placeholderText: i18n("Search…")
                onAccepted: if (page.searching && !runner.item?.querying) page.currentView.activateCurrent()
                Keys.onDownPressed: page.currentView.forceActiveFocus()
                Keys.onEscapePressed: event => {
                    if (page.searching) clear();
                    else event.accepted = false;
                }
            }
        }
        K.Separator { Layout.fillWidth: true }
        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            layoutDirection: page.configuration.contentLeft ? Qt.RightToLeft : Qt.LeftToRight
            ListView {
                id: sidebar
                Layout.preferredWidth: Math.min(page.width * .32, 190)
                Layout.fillHeight: true
                clip: true
                model: [{name:i18n("Favorites"), icon:"bookmarks", id:""},
                        {name:i18n("All applications"), icon:"view-app-grid-symbolic", id:"@all"}].concat(page.group("", false).filter(r => r.group))
                delegate: C.ItemDelegate {
                    required property var modelData
                    width: sidebar.width
                    text: modelData.name
                    icon.name: modelData.icon || "folder"
                    highlighted: !page.searching && (page.history[0]?.id ?? "") === modelData.id
                    function selectCategory() { search.clear(); page.currentView.path = modelData.id ? [modelData] : []; }
                    onClicked: selectCategory()
                    HoverHandler { onPointChanged: if (hovered && !page.searching && page.configuration.hoverCategories) parent.selectCategory() }
                }
                MenuWheel { id: sidebarWheel; list: sidebar; notch: sidebar.currentItem?.height || K.Units.gridUnit * 2 }
                C.ScrollBar.vertical: C.ScrollBar { onPressedChanged: if (pressed) sidebarWheel.motion.stop() }
            }
            K.Separator { Layout.fillHeight: true }
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true
                    visible: !page.searching && page.history.length > 1
                    C.Button {
                        Layout.maximumWidth: page.width * 0.40
                        icon.name: "go-previous"
                        text: i18n("Back to %1", page.history[page.history.length - 2]?.name ?? "")
                        onClicked: page.back()
                    }
                    C.Label {
                        objectName: "subcategoryName"
                        Layout.fillWidth: true
                        text: page.history[page.history.length - 1]?.name ?? ""
                        textFormat: Text.PlainText
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
                C.StackView {
                    id: stack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    initialItem: contents
                    pushEnter: PaneSlide { start: stack.width; end: 0 }
                    pushExit: PaneSlide { start: 0; end: -stack.width }
                    popEnter: PaneSlide { start: -stack.width; end: 0 }
                    popExit: PaneSlide { start: 0; end: stack.width }
                }
            }
        }
        K.Separator { Layout.fillWidth: true }
        SessionBar { Layout.fillWidth: true; onDismiss: page.dismiss() }
    }
    Component {
        id: contents
        GridView {
            id: view
            objectName: "menuContents"
            property var path: []
            readonly property bool favoritesPage: !page.searching && path.length === 0
            readonly property bool grid: !page.searching && (favoritesPage ? page.configuration.favoritesGrid !== false : !!page.configuration.categoryGrid)
            clip: true
            interactive: false
            function scrollBy(delta) {
                wheel.motion.stop();
                contentY = Math.max(originY, Math.min(originY + contentHeight - height, contentY + delta));
            }
            MenuWheel { id: wheel; list: view; notch: view.cellHeight }
            // Each data source owns its delegate. Changing the query cannot
            // briefly bind a runner result to a catalog row (or vice versa).
            model: page.searching ? resultRows : catalogRows
            readonly property var catalogEntries: {
                page.revision;
                if (!view.path.length) return catalog.favorites(page.favorites);
                if (view.path[0].id === "@all") return catalog.allApplications();
                return page.group(view.path[view.path.length-1].id, !!page.configuration.alphabetical);
            }
            onCatalogEntriesChanged: if (!page.searching) resetTimer.restart()
            DelegateModel {
                id: catalogRows
                model: view.catalogEntries
                delegate: catalogDelegate
            }
            DelegateModel {
                id: resultRows
                model: runner.item
                delegate: resultDelegate
            }
            function resetPosition() {
                wheel.motion.stop();
                currentIndex = count ? 0 : -1;
                positionViewAtBeginning();
            }
            Timer { id: resetTimer; interval: 0; onTriggered: view.resetPosition() }
            onModelChanged: resetTimer.restart()
            onCountChanged: if (count && currentIndex < 0) currentIndex = 0
            cellWidth: view.grid ? width / Math.max(1, Math.floor(width/104)) : width
            cellHeight: view.grid ? 100 : 46
            C.ScrollBar.vertical: C.ScrollBar { onPressedChanged: if (pressed) wheel.motion.stop() }
            function activateCurrent() {
                if (currentItem?.enabled) currentItem.activate();
            }
            Keys.onReturnPressed: activateCurrent()
            Keys.onEnterPressed: activateCurrent()
            Keys.onEscapePressed: event => {
                if (page.searching) { search.clear(); search.forceActiveFocus(); }
                else event.accepted = false;
            }
            Keys.onMenuPressed: if (currentItem) currentItem.context()
            Component {
                id: catalogDelegate
                MenuEntry {
                    required property var modelData
                    applicationId: modelData.group ? "" : modelData.id
                    artwork: modelData.icon || (modelData.group ? "folder" : "application-x-executable")
                    readonly property string description: (page.format === 2 ? modelData.comment || modelData.generic : modelData.generic || modelData.comment) || ""
                    readonly property bool reversed: !modelData.group && description.length && [1,3].includes(page.format)
                    primary: reversed ? description : modelData.name
                    secondary: page.format >= 2 && description.length ? (reversed ? modelData.name : description) : ""
                    onActivate: page.enter(modelData)
                }
            }
            Component {
                id: resultDelegate
                MenuEntry {
                    required property var model
                    applicationId: model.launcherId
                    artwork: model.decoration
                    primary: model.display
                    secondary: model.subtext || ""
                    enabled: model.enabled
                    onActivate: {
                        const results = runner.item;
                        if (results && results.run(results.index(index, 0))) page.dismiss();
                    }
                }
            }
            component MenuEntry: C.ItemDelegate {
                id: tile
                required property int index
                required property string applicationId
                required property var artwork
                required property string primary
                required property string secondary
                signal activate()
                width: view.cellWidth
                height: view.cellHeight
                Accessible.name: primary
                highlighted: (favoriteDrop.containsDrag && favoriteDrop.targetIndex === index) || hovered
                           || ((view.activeFocus || (page.searching && search.activeFocus)) && view.currentIndex === index)
                // Translate delegates without moving their logical drop cells.
                readonly property int previewIndex: {
                    const from = favoriteDrop.sourceIndex, to = favoriteDrop.targetIndex;
                    if (from < 0 || to < 0) return index;
                    if (index === from) return to;
                    if (index > from && index <= to) return index - 1;
                    if (index < from && index >= to) return index + 1;
                    return index;
                }
                readonly property int columns: Math.max(1, Math.round(view.width / view.cellWidth))
                opacity: favoriteDrop.sourceIndex === index ? 0 : 1
                transform: Translate {
                    x: ((tile.previewIndex % tile.columns) - (tile.index % tile.columns)) * view.cellWidth
                    y: (Math.floor(tile.previewIndex / tile.columns) - Math.floor(tile.index / tile.columns)) * view.cellHeight
                    Behavior on x { enabled: favoriteDrop.containsDrag; NumberAnimation { duration: K.Units.shortDuration; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: favoriteDrop.containsDrag; NumberAnimation { duration: K.Units.shortDuration; easing.type: Easing.OutCubic } }
                }
                // Qt can send the button a release as the native drag ends.
                property bool consumedPress: false
                onPressed: consumedPress = false
                onClicked: if (!consumedPress) activate()
                function context() {
                    if (!applicationId) return;
                    actions.targetId = applicationId;
                    actions.pinned = page.launcherActions?.pinned(actions.targetUrl) ?? false;
                    actions.popup(tile);
                }
                DragHandler {
                    target: null
                    enabled: tile.applicationId.length > 0
                    acceptedButtons: Qt.LeftButton
                    onActiveChanged: {
                        if (!active) return;
                        tile.consumedPress = true;
                        favoriteDrop.sourceId = view.favoritesPage ? tile.applicationId : "";
                        catalog.dragApplication(tile.Window.window, tile.applicationId, view.favoritesPage);
                    }
                }
                TapHandler { acceptedButtons: Qt.RightButton; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus; onTapped: tile.context() }
                contentItem: GridLayout {
                    columns: view.grid ? 1 : 2
                    rowSpacing: 2
                    K.Icon {
                        source: tile.artwork
                        Layout.preferredWidth: view.grid ? 44 : 30
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.alignment: Qt.AlignCenter
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        C.Label {
                            Layout.fillWidth: true
                            text: tile.primary
                            textFormat: Text.PlainText
                            horizontalAlignment: view.grid ? Text.AlignHCenter : Text.AlignLeft
                            wrapMode: view.grid ? Text.Wrap : Text.NoWrap
                            maximumLineCount: view.grid ? 2 : 1
                            elide: Text.ElideRight
                        }
                        C.Label {
                            Layout.fillWidth: true
                            visible: !view.grid && text.length > 0
                            text: tile.secondary
                            textFormat: Text.PlainText
                            font.pointSize: K.Theme.smallFont.pointSize
                            opacity: .75
                            elide: Text.ElideRight
                        }
                    }
                }
            }
            C.Label {
                parent: view
                anchors.centerIn: parent
                visible: page.searching && view.count === 0
                text: runner.item?.querying ? i18n("Searching…") : i18n("No results")
            }
            DropArea {
                id: favoriteDrop
                parent: view
                anchors.fill: parent
                enabled: view.favoritesPage
                keys: [catalog.favoriteFormat]
                property string sourceId: ""
                readonly property int sourceIndex: containsDrag ? catalogRows.model.findIndex(row => row.id === sourceId) : -1
                function indexFor(x, y) {
                    const p = view.contentItem.mapFromItem(favoriteDrop, x, y);
                    const columns = Math.max(1, Math.round(view.width / view.cellWidth));
                    const index = Math.floor((p.y - view.originY) / view.cellHeight) * columns
                        + Math.max(0, Math.min(columns - 1, Math.floor(p.x / view.cellWidth)));
                    return Math.max(0, Math.min(view.count - 1, index));
                }
                readonly property int targetIndex: {
                    view.contentY;
                    return containsDrag ? indexFor(drag.x, drag.y) : -1;
                }
                Timer {
                    interval: 50
                    repeat: true
                    running: favoriteDrop.containsDrag && view.contentHeight > view.height &&
                        ((favoriteDrop.drag.y < 24 && !view.atYBeginning) ||
                         (favoriteDrop.drag.y > view.height - 24 && !view.atYEnd))
                    onTriggered: view.scrollBy(favoriteDrop.drag.y < 24 ? -12 : 12)
                }
                onDropped: event => {
                    const id = event.getDataAsString(catalog.favoriteFormat);
                    const dest = catalogRows.model[indexFor(event.x, event.y)];
                    if (!dest || !page.favorites.includes(id)) return;
                    event.accept(Qt.CopyAction);
                    Qt.callLater(page.moveFavorite, id, dest.id);
                }
            }
            C.Menu {
                id: actions
                property string targetId
                readonly property url targetUrl: catalog.launcherUrl(targetId)
                property bool pinned
                C.MenuItem {
                    objectName: "menuPinAction"
                    enabled: !!page.launcherActions
                    text: actions.pinned ? i18n("Unpin from Dock") : i18n("Pin to Dock")
                    icon.name: actions.pinned ? "list-remove" : "list-add"
                    onTriggered: page.launcherActions.togglePinned(actions.targetUrl)
                }
                C.MenuItem {
                    visible: view.favoritesPage
                    enabled: page.favorites.indexOf(actions.targetId) > 0
                    text: i18n("Move earlier")
                    onTriggered: page.shiftFavorite(actions.targetId, -1)
                }
                C.MenuItem {
                    visible: view.favoritesPage
                    enabled: page.favorites.indexOf(actions.targetId) < page.favorites.length - 1
                    text: i18n("Move later")
                    onTriggered: page.shiftFavorite(actions.targetId, 1)
                }
                C.MenuItem {
                    text: page.favorites.includes(actions.targetId) ? i18n("Remove from favorites") : i18n("Add to favorites")
                    onTriggered: page.updateFavorite(actions.targetId)
                }
            }
        }
    }
}
