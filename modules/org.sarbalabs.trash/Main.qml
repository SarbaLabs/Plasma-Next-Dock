// SPDX-License-Identifier: GPL-2.0-or-later
import org.sarbalabs.nextdock.modules 1.0
import "native" as Native

DockModule {
    readonly property Native.TrashTools trash: Native.TrashTools {}
    entries: [{
        id: "trash", name: i18n("Trash"), icon: trash.full ? "user-trash-full" : "user-trash",
        localFileMove: true, acceptsDocuments: !trash.busy,
        actions: [
            {id: "open", text: i18n("Open Trash")},
            {id: "empty", text: i18n("Empty Trash…"), enabled: trash.full && !trash.busy}
        ]
    }]
    onActivated: trash.open()
    onDocumentsDropped: (entryId, urls) => trash.moveToTrash(urls)
    onActionTriggered: (entryId, actionId) => {
        if (actionId === "open") trash.open();
        else if (actionId === "empty") trash.empty();
    }
}
