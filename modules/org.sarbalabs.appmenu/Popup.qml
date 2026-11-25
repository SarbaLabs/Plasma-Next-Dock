// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as C
import QtQuick.Layouts
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
    property var history: []
    property int revision: 0
    readonly property bool favoritesPage: history.length === 0
    readonly property var favorites: configuration.favorites ?? ["org.kde.dolphin.desktop", "org.kde.konsole.desktop"]
    readonly property bool grid: favoritesPage ? configuration.favoritesGrid !== false : !!configuration.categoryGrid
    readonly property int format: configuration.format ?? 0
    Native.Catalog { id: catalog; onChanged: ++page.revision }
    function group(path, sorted) { page.revision; return catalog.group(path, sorted); }
    function back() { if (history.length > 1) history = history.slice(0,-1); }
    function enter(row) {
        if (row.group) history = history.concat([row]);
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
    Shortcut { sequence: "Alt+Left"; enabled: page.history.length > 1; onActivated: page.back() }
    ColumnLayout {
        anchors.fill: parent
        C.ItemDelegate {
            id: profile
            Core.KUser { id: user }
            readonly property string displayName: user.fullName || user.loginName
            enabled: Config.KAuthorized.authorizeControlModule("kcm_users")
            Layout.maximumWidth: page.width
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
                    highlighted: (page.history[0]?.id ?? "") === modelData.id
                    function selectCategory() { page.history = modelData.id ? [modelData] : []; }
                    onClicked: selectCategory()
                    HoverHandler { onPointChanged: if (hovered && page.configuration.hoverCategories) parent.selectCategory() }
                }
                C.ScrollBar.vertical: C.ScrollBar {}
            }
            K.Separator { Layout.fillHeight: true }
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                C.Button {
                    visible: page.history.length > 1
                    icon.name: "go-previous"
                    text: i18n("Back to %1", page.history[page.history.length - 2]?.name ?? "")
                    onClicked: page.back()
                }
                GridView {
                    id: view
                    objectName: "menuContents"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    focus: true
                    interactive: false
                    function scrollBy(delta) {
                        contentY = Math.max(originY, Math.min(originY + contentHeight - height, contentY + delta));
                    }
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const step = event.pixelDelta.y || event.angleDelta.y / 120 * view.cellHeight;
                            view.scrollBy(-step);
                            event.accepted = true;
                        }
                    }
                    model: {
                        page.revision;
                        if (page.favoritesPage) return catalog.favorites(page.favorites);
                        if (page.history[0].id === "@all") return catalog.allApplications();
                        return page.group(page.history[page.history.length-1].id, !!page.configuration.alphabetical);
                    }
                    onModelChanged: Qt.callLater(() => { currentIndex = 0; positionViewAtBeginning(); })
                    cellWidth: page.grid ? width / Math.max(1, Math.floor(width/104)) : width
                    cellHeight: page.grid ? 100 : 46
                    C.ScrollBar.vertical: C.ScrollBar {}
                    Keys.onReturnPressed: if (currentItem) page.enter(currentItem.modelData)
                    Keys.onMenuPressed: if (currentItem) currentItem.context()
                    delegate: C.ItemDelegate {
                        id: tile
                        required property var modelData
                        required property int index
                        width: view.cellWidth
                        height: view.cellHeight
                        readonly property string description: (page.format === 2 ? modelData.comment || modelData.generic : modelData.generic || modelData.comment) || ""
                        readonly property bool reversed: !modelData.group && description.length && [1,3].includes(page.format)
                        readonly property string primary: reversed ? description : modelData.name
                        readonly property string secondary: page.format >= 2 && description.length ? (reversed ? modelData.name : description) : ""
                        Accessible.name: primary
                        highlighted: (favoriteDrop.containsDrag && favoriteDrop.targetIndex === index) || hovered || (view.activeFocus && view.currentIndex === index)
                        // Qt can send the button a release as the native drag ends.
                        property bool consumedPress: false
                        onPressed: consumedPress = false
                        onClicked: if (!consumedPress) page.enter(modelData)
                        function context() {
                            if (modelData.group) return;
                            actions.targetId = modelData.id;
                            actions.pinned = page.launcherActions?.pinned(actions.targetUrl) ?? false;
                            actions.popup(tile);
                        }
                        DragHandler {
                            target: null
                            enabled: !tile.modelData.group
                            acceptedButtons: Qt.LeftButton
                            onActiveChanged: {
                                if (!active) return;
                                tile.consumedPress = true;
                                catalog.dragApplication(tile.Window.window, tile.modelData.id, page.favoritesPage);
                            }
                        }
                        TapHandler { acceptedButtons: Qt.RightButton; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus; onTapped: tile.context() }
                        contentItem: GridLayout {
                            columns: page.grid ? 1 : 2
                            rowSpacing: 2
                            K.Icon {
                                source: tile.modelData.icon || (tile.modelData.group ? "folder" : "application-x-executable")
                                Layout.preferredWidth: page.grid ? 44 : 30
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
                                    horizontalAlignment: page.grid ? Text.AlignHCenter : Text.AlignLeft
                                    wrapMode: page.grid ? Text.Wrap : Text.NoWrap
                                    maximumLineCount: page.grid ? 2 : 1
                                    elide: Text.ElideRight
                                }
                                C.Label {
                                    Layout.fillWidth: true
                                    visible: !page.grid && text.length > 0
                                    text: tile.secondary
                                    textFormat: Text.PlainText
                                    font.pointSize: K.Theme.smallFont.pointSize
                                    opacity: .75
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                    DropArea {
                        id: favoriteDrop
                        parent: view
                        anchors.fill: parent
                        enabled: page.favoritesPage
                        keys: [catalog.favoriteFormat]
                        function indexFor(x, y) {
                            const p = view.contentItem.mapFromItem(favoriteDrop, x, y);
                            const index = view.indexAt(p.x, p.y);
                            return index < 0 ? view.count - 1 : index;
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
                            const dest = view.model[indexFor(event.x, event.y)];
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
                            visible: page.favoritesPage
                            enabled: page.favorites.indexOf(actions.targetId) > 0
                            text: i18n("Move earlier")
                            onTriggered: page.shiftFavorite(actions.targetId, -1)
                        }
                        C.MenuItem {
                            visible: page.favoritesPage
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
        K.Separator { Layout.fillWidth: true }
        SessionBar { Layout.fillWidth: true; onDismiss: page.dismiss() }
    }
}
