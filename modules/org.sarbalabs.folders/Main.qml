// SPDX-License-Identifier: GPL-2.0-or-later
import QtQml
import org.sarbalabs.nextdock.modules 1.0

DockModule {
    id: provider
    readonly property Folders folders: Folders {
        configuration: provider.configuration
        onEdited: options => provider.preferencesEdited(options)
    }
    entries: folders.rows.map(row => ({
        id: row.url, name: row.name, icon: row.icon, acceptsDocuments: row.available, reorderable: folders.manual,
        actions: [
            {id: "open", text: i18n("Open folder"), enabled: row.available},
            {id: "icon", text: i18n("Choose an icon…")},
            {id: "reset", text: i18n("Restore original icon"), enabled: row.custom},
            {id: "remove", text: i18n("Remove folder shortcut")}
        ]
    }))
    acceptsDirectoryDrops: true
    onMoveRequested: (entryId, destinationId) => folders.move(entryId, folders.shortcuts.findIndex(item => item.url === destinationId))
    onDirectoriesDropped: urls => folders.add(urls)
    onActivated: entryId => folders.open(entryId)
    onDocumentsDropped: (entryId, urls) => folders.copy(urls, entryId)
    onActionTriggered: (entryId, actionId) => {
        const row = folders.rows.find(item => item.url === entryId);
        if (!row) return;
        if (actionId === "icon") folders.chooseIcon(entryId, row.icon);
        else if (actionId === "reset") folders.setIcon(entryId, "");
        else if (actionId === "remove") folders.remove(entryId);
        else if (actionId === "open") folders.open(entryId);
    }
}
