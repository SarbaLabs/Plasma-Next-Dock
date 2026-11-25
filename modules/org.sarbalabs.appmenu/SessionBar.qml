// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as C
import org.kde.plasma.private.sessions as Sessions

Item {
    id: bar
    objectName: "sessionBar"
    signal dismiss()
    signal navigateUp()
    function availableButtons() {
        return power.availableButtons().concat(personal.availableButtons());
    }
    function focusFirst() {
        availableButtons()[0]?.forceActiveFocus(Qt.TabFocusReason);
    }
    Keys.onPressed: event => {
        const items = availableButtons();
        const index = items.findIndex(button => button.activeFocus);
        if (index < 0 || event.modifiers !== Qt.NoModifier) return;
        if (event.key === Qt.Key_Up) navigateUp();
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            const next = index + (event.key === Qt.Key_Left ? -1 : 1);
            items[next]?.forceActiveFocus(Qt.TabFocusReason);
        } else return;
        event.accepted = true;
    }
    Sessions.SessionManagement { id: session }
    property var backend: session
    implicitHeight: buttons.implicitHeight

    // Measure the actual translated buttons, including the current theme's
    // padding. Collapsing a group must not change its measured expanded width.
    component ActionGroup: Item {
        id: group
        required property list<C.Action> actions
        required property string title
        required property string iconName
        required property bool compact
        function availableButtons() {
            if (!visible) return [];
            if (compact) return [trigger];
            return Array.from(direct.children).filter(button => button.visible && button.enabled && button.action);
        }
        readonly property real directWidth: direct.implicitWidth
        readonly property real groupedWidth: trigger.implicitWidth
        visible: directWidth > 0
        implicitWidth: compact ? groupedWidth : directWidth
        implicitHeight: compact ? trigger.implicitHeight : direct.implicitHeight

        Row {
            id: direct
            visible: !group.compact
            Repeater {
                model: group.actions
                C.ToolButton {
                    required property var modelData
                    action: modelData
                    Keys.onReturnPressed: modelData.trigger()
                    display: C.AbstractButton.TextBesideIcon
                }
            }
        }
        C.ToolButton {
            id: trigger
            visible: group.compact
            text: group.title
            icon.name: group.iconName
            display: C.AbstractButton.TextBesideIcon
            Keys.onReturnPressed: menu.open()
            onClicked: menu.open()
            C.Menu {
                id: menu
                y: -height
                Repeater {
                    model: group.actions
                    C.MenuItem {
                        required property var modelData
                        action: modelData
                    }
                }
            }
        }
    }
    Row {
        id: buttons
        anchors.right: parent.right
        ActionGroup {
            id: power
            objectName: "powerActions"
            title: i18n("Power")
            iconName: "system-shutdown"
            compact: personal.compact && directWidth + personal.groupedWidth > bar.width
            actions: [
                C.Action { text: i18n("Sleep"); icon.name: "system-suspend"; enabled: bar.backend.canSuspend; onTriggered: { bar.backend.suspend(); bar.dismiss(); } },
                C.Action { text: i18n("Hibernate"); icon.name: "system-suspend-hibernate"; enabled: bar.backend.canHibernate; onTriggered: { bar.backend.hibernate(); bar.dismiss(); } },
                C.Action { text: i18n("Restart…"); icon.name: "system-reboot"; enabled: bar.backend.canReboot; onTriggered: { bar.backend.requestReboot(); bar.dismiss(); } },
                C.Action { text: i18n("Shut Down…"); icon.name: "system-shutdown"; enabled: bar.backend.canShutdown; onTriggered: { bar.backend.requestShutdown(); bar.dismiss(); } }
            ]
        }
        ActionGroup {
            id: personal
            objectName: "sessionActions"
            title: i18n("Session")
            iconName: "system-log-out"
            compact: directWidth > 0 && power.directWidth + directWidth > bar.width
            actions: [
                C.Action { text: i18n("Lock"); icon.name: "system-lock-screen"; enabled: bar.backend.canLock; onTriggered: { bar.backend.lock(); bar.dismiss(); } },
                C.Action { text: i18n("Switch User"); icon.name: "system-switch-user"; enabled: bar.backend.canSwitchUser; onTriggered: { bar.backend.switchUser(); bar.dismiss(); } },
                C.Action { text: i18n("Log Out…"); icon.name: "system-log-out"; enabled: bar.backend.canLogout; onTriggered: { bar.backend.requestLogout(); bar.dismiss(); } }
            ]
        }
    }
}
