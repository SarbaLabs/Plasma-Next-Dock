// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

RowLayout {
    id: page
    property var configuration: ({})
    signal edited(var options)
    Controls.Label { text: i18n("Unpinned application order:") }
    Controls.ComboBox {
        Layout.fillWidth: true
        objectName: "unpinnedSortControl"
        readonly property var modes: ["name", "recent", "desktop", "activity"]
        model: [i18n("Alphabetically"), i18n("Last activated"), i18n("Virtual desktop"), i18n("Activity")]
        currentIndex: Math.max(0, modes.indexOf(page.configuration.sort))
        onActivated: index => page.edited({sort: modes[index]})
    }
}
