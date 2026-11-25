// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as C
import QtQuick.Layouts
import org.kde.kirigami as K
import "native" as Native

FocusScope {
    id: page
    property var configuration: ({})
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
                        highlighted: hovered || (view.activeFocus && view.currentIndex === index)
                        onClicked: page.enter(modelData)
                        function context() {
                            if (!modelData.group) { actions.targetId = modelData.id; actions.popup(tile); }
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
                    C.Menu {
                        id: actions
                        property string targetId
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
