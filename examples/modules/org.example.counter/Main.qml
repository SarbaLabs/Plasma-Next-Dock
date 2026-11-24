// SPDX-License-Identifier: GPL-2.0-or-later
import org.sarbalabs.nextdock.modules 1.0

DockModule {
    property int count: 0
    entries: [{
        id: "counter",
        name: (configuration.label || qsTr("Counter")) + " (" + count + ")",
        icon: "accessories-calculator",
        actions: [{id: "reset", text: qsTr("Reset"), enabled: count > 0}]
    }]
    onActivated: entryId => { count += 1 }
    onActionTriggered: (entryId, actionId) => { if (actionId === "reset") count = 0 }
}
