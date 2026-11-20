// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SettingsForm {
    id: page
    objectName: "behaviorSettings"
    property var values: ({})
    function load(configuration) { const copy = {}; for (const key of ["groupApplications", "groupClick", "minimizeActive", "middleClick", "wheelAction", "skipMinimized", "filterDesktop", "filterActivity", "filterScreen", "onlyMinimized", "layoutDirection", "showSeparator", "revealAttention", "bounceEnabled", "bounceOnLaunch", "bounceOnAttention", "bounceHeight", "bounceSpeed", "bounceCount"]) copy[key] = configuration[key]; values = copy; }
    function change(key, value) { const copy = Object.assign({}, values); copy[key] = value; values = copy; }
    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Window grouping") }
    Controls.CheckBox {
        objectName: "groupApplicationsControl"
        text: i18n("Group windows by application")
        checked: page.values.groupApplications === true
        onToggled: page.change("groupApplications", checked)
    }
    Controls.ComboBox {
        objectName: "groupClickControl"
        enabled: page.values.groupApplications !== false
        implicitWidth: Kirigami.Units.gridUnit * 18
        Kirigami.FormData.label: i18n("Clicking a group:")
        model: [i18n("Show window previews"), i18n("Cycle through windows"), i18n("Activate the group")]
        currentIndex: page.values.groupClick || 0
        onActivated: page.change("groupClick", currentIndex)
    }
    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Mouse actions") }
    Controls.CheckBox {
        objectName: "minimizeActiveControl"
        text: i18n("Minimize the active task on click")
        checked: page.values.minimizeActive === true
        onToggled: page.change("minimizeActive", checked)
    }
    Controls.ComboBox {
        objectName: "middleClickControl"
        implicitWidth: Kirigami.Units.gridUnit * 18
        Kirigami.FormData.label: i18n("Middle-click:")
        model: [i18n("Do nothing"), i18n("Open a new instance"), i18n("Close the task"), i18n("Toggle minimization")]
        currentIndex: page.values.middleClick || 0
        onActivated: page.change("middleClick", currentIndex)
    }
    Controls.ComboBox {
        objectName: "wheelActionControl"
        implicitWidth: Kirigami.Units.gridUnit * 18
        Kirigami.FormData.label: i18n("Mouse wheel:")
        model: [i18n("Scroll overflowing dock only"), i18n("Cycle through the hovered group")]
        currentIndex: page.values.wheelAction || 0
        onActivated: page.change("wheelAction", currentIndex)
    }
    Controls.CheckBox {
        objectName: "skipMinimizedControl"
        enabled: page.values.wheelAction === 1 || page.values.groupClick === 1
        text: i18n("Skip minimized windows when cycling")
        checked: page.values.skipMinimized === true
        onToggled: page.change("skipMinimized", checked)
    }
    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Filters") }
    Controls.CheckBox {
        objectName: "filterScreenControl"
        text: i18n("Only tasks on this screen")
        checked: page.values.filterScreen === true
        onToggled: page.change("filterScreen", checked)
    }
    Controls.CheckBox {
        objectName: "filterDesktopControl"
        text: i18n("Only tasks on the current desktop")
        checked: page.values.filterDesktop === true
        onToggled: page.change("filterDesktop", checked)
    }
    Controls.CheckBox {
        objectName: "filterActivityControl"
        text: i18n("Only tasks on the current activity")
        checked: page.values.filterActivity === true
        onToggled: page.change("filterActivity", checked)
    }
    Controls.CheckBox {
        objectName: "onlyMinimizedControl"
        text: i18n("Only minimized tasks")
        checked: page.values.onlyMinimized === true
        onToggled: page.change("onlyMinimized", checked)
    }
    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Layout and attention") }
    Controls.ComboBox {
        objectName: "layoutDirectionControl"
        implicitWidth: Kirigami.Units.gridUnit * 18
        Kirigami.FormData.label: i18n("Task direction:")
        model: [i18n("Follow system language"), i18n("Left to right / top to bottom"), i18n("Right to left / bottom to top")]
        currentIndex: page.values.layoutDirection || 0
        onActivated: page.change("layoutDirection", currentIndex)
    }
    Controls.CheckBox {
        objectName: "showSeparatorControl"
        text: i18n("Separate pinned and unpinned applications")
        checked: page.values.showSeparator === true
        onToggled: page.change("showSeparator", checked)
    }
    Controls.CheckBox {
        objectName: "revealAttentionControl"
        text: i18n("Reveal the dock when a task requests attention")
        checked: page.values.revealAttention === true
        onToggled: page.change("revealAttention", checked)
    }
    Controls.Label { Layout.fillWidth: true; Layout.preferredWidth: Kirigami.Units.gridUnit * 22; wrapMode: Text.WordWrap; text: i18n("Overflow scrolling takes priority over window cycling. Manual dragging is available only with manual sorting.") }
    Controls.Label { Layout.fillWidth: true; Layout.preferredWidth: Kirigami.Units.gridUnit * 22; wrapMode: Text.WordWrap; text: i18n("Reversing the direction also moves unpinned applications to the opposite side. Display filters do not change window avoidance.") }
}
