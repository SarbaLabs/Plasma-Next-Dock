// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Controls.ApplicationWindow {
    id: page
    property var configuration: ({})
    signal edited(var options)
    title: i18n("Folders")
    color: Kirigami.Theme.backgroundColor
    flags: Qt.Dialog
    width: 600
    height: 420
    minimumWidth: 460
    minimumHeight: 280
    property string draggedUrl: ""
    property int dropIndex: -1
    property real pointerY: 0
    function updateDrop() {
        const y = Math.max(0, Math.min(view.height - 1, pointerY));
        dropIndex = view.indexAt(1, y + view.contentY);
    }
    Folders {
        id: folders
        objectName: "folderEditor"
        configuration: page.configuration
        onEdited: changes => page.edited(changes)
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        component IconButton: Controls.ToolButton {
            display: Controls.AbstractButton.IconOnly
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: text
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.Label { text: i18n("Folder order:") }
            Controls.ComboBox {
                id: sort
                objectName: "folderSortControl"
                Layout.fillWidth: true
                model: [i18n("Manually"), i18n("Alphabetically")]
                currentIndex: (folders.manual ? 0 : 1)
                onActivated: index => page.edited({sort: index === 0 ? "manual" : "name"})
            }
            Controls.Button {
                icon.name: "list-add"
                text: i18n("Add a folder…")
                onClicked: folders.chooseFolder()
            }
        }
        Controls.Label {
            Layout.fillWidth: true
            visible: !folders.manual
            wrapMode: Text.WordWrap
            text: i18n("Manual reordering is unavailable with this sort order.")
        }
        ListView {
            id: view
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: folders.rows
            Controls.ScrollBar.vertical: Controls.ScrollBar { id: scroll }
            highlight: Rectangle { visible: page.draggedUrl.length > 0; color: Kirigami.Theme.highlightColor; opacity: 0.22 }
            currentIndex: page.draggedUrl.length ? page.dropIndex : -1
            highlightMoveDuration: 0
            highlightFollowsCurrentItem: true
            DropArea {
                objectName: "folderDropArea"
                parent: view
                anchors.fill: parent
                onEntered: event => {
                    if ((event.supportedActions & Qt.CopyAction) && event.hasUrls && event.urls.some(url => !!folders.directory(url)))
                        event.accept(Qt.CopyAction);
                    else event.accepted = false;
                }
                onDropped: event => {
                    if ((event.supportedActions & Qt.CopyAction) && folders.add(event.urls)) event.accept(Qt.CopyAction);
                    else event.accepted = false;
                }
            }
            Controls.Label {
                parent: view
                anchors.centerIn: parent
                visible: view.count === 0
                text: i18n("Add a folder or drag folders here.")
            }
            delegate: RowLayout {
                id: row
                required property var modelData
                required property int index
                width: view.width - (scroll.visible ? scroll.width : 0)
                height: Math.max(38, implicitHeight)
                Kirigami.Icon {
                    id: handle
                    visible: folders.manual
                    source: "drag-handle-symbolic"
                    implicitWidth: 24; implicitHeight: 24
                    Accessible.name: i18n("Drag to reorder")
                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => {
                            page.draggedUrl = row.modelData.url;
                            page.pointerY = mapToItem(view, mouse.x, mouse.y).y;
                            page.updateDrop();
                        }
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            page.pointerY = mapToItem(view, mouse.x, mouse.y).y;
                            page.updateDrop();
                        }
                        onReleased: {
                            if (page.draggedUrl === row.modelData.url) folders.move(page.draggedUrl, page.dropIndex);
                            page.draggedUrl = "";
                        }
                        onCanceled: page.draggedUrl = ""
                    }
                }
                Kirigami.Icon { source: row.modelData.icon || "folder"; implicitWidth: 26; implicitHeight: 26 }
                Controls.Label {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    elide: Text.ElideRight
                    Controls.ToolTip.visible: folderHover.hovered
                    Controls.ToolTip.text: row.modelData.path
                    HoverHandler { id: folderHover }
                }
                IconButton { visible: folders.manual; enabled: row.index > 0; icon.name: "go-up"; text: i18n("Up"); onClicked: folders.move(row.modelData.url, row.index - 1) }
                IconButton { visible: folders.manual; enabled: row.index + 1 < view.count; icon.name: "go-down"; text: i18n("Down"); onClicked: folders.move(row.modelData.url, row.index + 1) }
                IconButton { icon.name: "document-edit"; text: i18n("Choose an icon…"); onClicked: folders.chooseIcon(row.modelData.url, row.modelData.icon) }
                IconButton { enabled: row.modelData.custom; icon.name: "edit-undo"; text: i18n("Restore original icon"); onClicked: folders.setIcon(row.modelData.url, "") }
                IconButton { icon.name: "edit-delete"; text: i18n("Remove"); onClicked: folders.remove(row.modelData.url) }
            }
        }
        Timer {
            interval: 45; repeat: true
            running: page.draggedUrl.length > 0 && (page.pointerY < 24 || page.pointerY > view.height - 24)
            onTriggered: {
                view.contentY = Math.max(view.originY, Math.min(view.originY + view.contentHeight - view.height,
                    view.contentY + (page.pointerY < 24 ? -10 : 10)));
                page.updateDrop();
            }
        }
    }
    footer: Controls.DialogButtonBox {
        standardButtons: Controls.DialogButtonBox.Close
        onRejected: page.close()
    }
    Shortcut { sequence: "Escape"; onActivated: page.close() }
}
