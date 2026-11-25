// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as C
import QtQuick.Layouts
import org.kde.plasma.private.sessions as Sessions

RowLayout {
    id: bar
    signal dismiss()
    Sessions.SessionManagement { id: session }
    Item { Layout.fillWidth: true }
    C.ToolButton {
        text: i18n("Power")
        icon.name: "system-shutdown"
        onClicked: power.open()
        C.Menu {
            id: power
            y: -height
            C.MenuItem { text: i18n("Sleep"); enabled: session.canSuspend; onTriggered: { session.suspend(); bar.dismiss(); } }
            C.MenuItem { text: i18n("Hibernate"); enabled: session.canHibernate; onTriggered: { session.hibernate(); bar.dismiss(); } }
            C.MenuItem { text: i18n("Restart…"); enabled: session.canReboot; onTriggered: { session.requestReboot(); bar.dismiss(); } }
            C.MenuItem { text: i18n("Shut Down…"); enabled: session.canShutdown; onTriggered: { session.requestShutdown(); bar.dismiss(); } }
        }
    }
    C.ToolButton {
        text: i18n("Session")
        icon.name: "system-log-out"
        onClicked: menu.open()
        C.Menu {
            id: menu
            y: -height
            C.MenuItem { text: i18n("Lock"); enabled: session.canLock; onTriggered: { session.lock(); bar.dismiss(); } }
            C.MenuItem { text: i18n("Switch User"); enabled: session.canSwitchUser; onTriggered: { session.switchUser(); bar.dismiss(); } }
            C.MenuItem { text: i18n("Log Out…"); enabled: session.canLogout; onTriggered: { session.requestLogout(); bar.dismiss(); } }
        }
    }
}
