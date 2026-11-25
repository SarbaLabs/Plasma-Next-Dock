// SPDX-License-Identifier: GPL-2.0-or-later
import org.sarbalabs.nextdock.modules 1.0
import "native" as Native
DockModule {
    readonly property Native.MenuTools tools: Native.MenuTools {}
    entries: [{id: "menu", name: i18n("Applications menu"), icon: configuration.icon || "start-here-kde", popup: true, preferredPopupWidth: 960,
               actions: [{id: "edit", text: i18n("Edit Applications…"), enabled: tools.editorAvailable}]}]
    onActionTriggered: (entryId, actionId) => { if (actionId === "edit") tools.editApplications(); }
}
