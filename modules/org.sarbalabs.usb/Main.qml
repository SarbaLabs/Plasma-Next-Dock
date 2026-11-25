// SPDX-License-Identifier: GPL-2.0-or-later
import org.sarbalabs.nextdock.modules 1.0
import "native" as Native

DockModule {
    readonly property Native.UsbTools usb: Native.UsbTools {}
    entries: usb.volumes.map(volume => {
        const actions = [{id: "open", text: i18n("Open volume")}];
        if (!volume.mounted)
            actions.push({id: "mount", text: i18n("Mount")});
        if (volume.canUnmount)
            actions.push({id: "unmount", text: i18n("Unmount")});
        if (volume.removal)
            actions.push({id: "remove", text: volume.removal === "PowerOff" ? i18n("Safely remove drive") : i18n("Eject"), enabled: volume.canRemove});
        return {id: volume.id, name: volume.name, icon: volume.icon, enabled: !volume.busy, trashDropAction: "unmount", actions: actions};
    })
    onActivated: entryId => usb.run(entryId, "open")
    onActionTriggered: (entryId, actionId) => usb.run(entryId, actionId)
}
