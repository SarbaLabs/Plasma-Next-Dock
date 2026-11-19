// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Controls.Dialog {
    id: root
    objectName: "applicationChooser"
    title: i18n("Add an application")
    modal: true
    anchors.centerIn: parent
    width: Math.min(480, parent.width - 32)
    height: Math.min(520, parent.height - 32)
    standardButtons: Controls.Dialog.Close
    property var applications: []
    readonly property var matches: applications.filter(app => (app.name + " " + app.description + " " + app.url).toLocaleLowerCase().includes(search.text.toLocaleLowerCase()))
    signal chosen(string url)
    function choose(index) {
        if (index < 0 || index >= matches.length) return;
        chosen(matches[index].url);
        close();
    }
    onOpened: { applications = launcherResolver.applications(); search.clear(); search.forceActiveFocus(); }
    contentItem: ColumnLayout {
        Controls.TextField {
            id: search
            objectName: "applicationSearch"
            Layout.fillWidth: true
            placeholderText: i18n("Search installed applications…")
            Accessible.name: placeholderText
            onTextChanged: list.currentIndex = 0
            onAccepted: root.choose(list.currentIndex)
            Keys.onDownPressed: { list.forceActiveFocus(); list.currentIndex = Math.max(0, list.currentIndex); }
        }
        ListView {
            id: list
            objectName: "applicationResults"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: root.matches
            currentIndex: 0
            keyNavigationEnabled: true
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            Keys.onReturnPressed: root.choose(currentIndex)
            Keys.onEnterPressed: root.choose(currentIndex)
            delegate: Controls.ItemDelegate {
                required property var modelData
                required property int index
                width: ListView.view.width
                text: modelData.name
                icon.name: modelData.icon
                highlighted: ListView.isCurrentItem
                onClicked: root.choose(index)
                Controls.ToolTip.visible: hovered && modelData.description.length > 0
                Controls.ToolTip.text: modelData.description
            }
        }
        Controls.Label { visible: root.matches.length === 0; text: i18n("No matching applications") }
    }
}
