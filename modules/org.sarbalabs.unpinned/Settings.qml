// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Controls.ApplicationWindow {
    id: page
    property var configuration: ({})
    signal edited(var options)
    title: i18n("Unpinned applications")
    color: palette.window
    flags: Qt.Dialog
    width: Math.max(360, form.implicitWidth + 32)
    height: form.implicitHeight + 32 + footer.implicitHeight
    minimumWidth: form.implicitWidth + 32
    minimumHeight: form.implicitHeight + 32 + footer.implicitHeight

    RowLayout {
        id: form
        anchors.fill: parent
        anchors.margins: 16
        Controls.Label { color: page.palette.windowText; text: i18n("Unpinned application order:") }
        Controls.ComboBox {
            Layout.fillWidth: true
            objectName: "unpinnedSortControl"
            readonly property var modes: ["name", "recent", "desktop", "activity"]
            model: [i18n("Alphabetically"), i18n("Last activated"), i18n("Virtual desktop"), i18n("Activity")]
            currentIndex: Math.max(0, modes.indexOf(page.configuration.sort))
            onActivated: index => page.edited({sort: modes[index]})
        }
    }
    footer: Controls.DialogButtonBox {
        standardButtons: Controls.DialogButtonBox.Close
        onRejected: page.close()
    }
    Shortcut { sequence: "Escape"; onActivated: page.close() }
}
