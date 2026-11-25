// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    Plasmoid.status: PlasmaCore.Types.HiddenStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    implicitWidth: 1
    implicitHeight: 1
    preferredRepresentation: fullRepresentation
    fullRepresentation: Component { Item {} }
    Plasmoid.onActivated: DBus.SessionBus.asyncCall({
        service: "org.sarbalabs.PlasmaNextDock",
        path: "/Launcher", iface: "org.sarbalabs.PlasmaNextDock.Launcher",
        member: "Activate"
    })
}
