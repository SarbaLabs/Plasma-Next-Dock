// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

ColumnLayout {
    id: page
    property var tasks: null
    signal addRequested()
    readonly property int sortMode: dockSettings.values.taskSort
    readonly property bool manual: sortMode === 0
    readonly property var pins: dockSettings.values.launchers
    readonly property var details: pins.map(url => launcherResolver.describe(url))
    property var entries: []
    property string draggedUrl: ""
    property int dropIndex: -1
    property real pointerY: 0

    function refresh() {
        if (!visible) return;
        const rows = details.slice();
        if (!manual) {
            const positions = new Map();
            if (tasks) {
                const nativePins = tasks.launcherList;
                for (let row = 0; row < tasks.rowCount(); ++row) {
                    const url = tasks.data(tasks.makeModelIndex(row), TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
                    const pin = tasks.launcherPosition(url);
                    if (pin >= 0 && !positions.has(nativePins[pin]))
                        positions.set(nativePins[pin], row);
                }
            }
            rows.sort((a, b) => (positions.get(a.url) ?? Infinity) - (positions.get(b.url) ?? Infinity)
                || a.name.localeCompare(b.name));
        }
        if (JSON.stringify(rows) !== JSON.stringify(entries)) entries = rows;
    }
    function queueRefresh() { Qt.callLater(refresh); }
    onVisibleChanged: queueRefresh()
    onDetailsChanged: queueRefresh()
    onSortModeChanged: { draggedUrl = ""; queueRefresh(); }
    onTasksChanged: queueRefresh()
    Component.onCompleted: queueRefresh()
    Connections {
        target: page.visible && !page.manual ? page.tasks : null
        function onLayoutChanged() { page.queueRefresh(); }
        function onRowsInserted() { page.queueRefresh(); }
        function onRowsRemoved() { page.queueRefresh(); }
        function onRowsMoved() { page.queueRefresh(); }
        function onModelReset() { page.queueRefresh(); }
        function onDataChanged() { page.queueRefresh(); }
    }
    function move(url, destination) {
        const list = pins.slice();
        const from = list.indexOf(url);
        if (!manual || from < 0 || destination < 0 || destination >= list.length || from === destination) return;
        list.splice(from, 1);
        list.splice(destination, 0, url);
        dockSettings.saveLaunchers(list);
    }
    function remove(url) {
        dockSettings.saveLaunchers(pins.filter(pin => pin !== url));
    }
    function updateDrop() {
        const y = Math.max(0, Math.min(view.height - 1, pointerY));
        dropIndex = view.indexAt(1, y + view.contentY);
    }
    component IconButton: Controls.ToolButton {
        display: Controls.AbstractButton.IconOnly
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.text: text
    }
    RowLayout {
        Layout.fillWidth: true
        Controls.Label { text: i18n("Pinned application order:") }
        Controls.ComboBox {
            id: sort
            objectName: "taskSortControl"
            Layout.fillWidth: true
            model: [i18n("Manually"), i18n("Alphabetically"), i18n("Last activated"), i18n("Virtual desktop"), i18n("Activity")]
            currentIndex: page.sortMode
            onActivated: index => { dockSettings.apply({taskSort: index}); currentIndex = Qt.binding(() => page.sortMode); }
        }
        Controls.Button {
            icon.name: "list-add"
            text: i18n("Add an application…")
            onClicked: page.addRequested()
        }
    }
    Controls.Label {
        Layout.fillWidth: true
        visible: !page.manual
        wrapMode: Text.WordWrap
        text: i18n("Manual reordering is unavailable with this sort order.")
    }
    Loader {
        id: unpinnedSettings
        Layout.fillWidth: true
        active: dockSettings.values.enabledModules.includes("org.sarbalabs.unpinned")
        source: typeof unpinnedSettingsUrl === "undefined" ? "" : unpinnedSettingsUrl
        visible: status === Loader.Ready
        onLoaded: item.configuration = Qt.binding(() => dockSettings.values.moduleSettings["org.sarbalabs.unpinned"] || {})
        Connections {
            target: unpinnedSettings.item
            function onEdited(options) {
                const all = Object.assign({}, dockSettings.values.moduleSettings);
                all["org.sarbalabs.unpinned"] = options;
                dockSettings.apply({moduleSettings: all});
            }
        }
    }
    ListView {
        id: view
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: page.entries
        Controls.ScrollBar.vertical: Controls.ScrollBar { id: scroll }
        highlight: Rectangle { visible: page.draggedUrl.length > 0; color: Kirigami.Theme.highlightColor; opacity: 0.22 }
        currentIndex: page.draggedUrl.length ? page.dropIndex : -1
        highlightMoveDuration: 0
        highlightFollowsCurrentItem: true
        delegate: RowLayout {
            id: row
            required property var modelData
            required property int index
            width: view.width - (scroll.visible ? scroll.width : 0)
            height: Math.max(38, implicitHeight)
            Kirigami.Icon {
                id: handle
                visible: page.manual
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
                        if (page.draggedUrl === row.modelData.url) page.move(page.draggedUrl, page.dropIndex);
                        page.draggedUrl = "";
                    }
                    onCanceled: page.draggedUrl = ""
                }
            }
            Kirigami.Icon { source: row.modelData.icon || "application-x-executable"; implicitWidth: 26; implicitHeight: 26 }
            Controls.Label { Layout.fillWidth: true; text: row.modelData.name; elide: Text.ElideRight }
            IconButton { visible: page.manual; enabled: row.index > 0; icon.name: "go-up"; text: i18n("Up"); onClicked: page.move(row.modelData.url, row.index - 1) }
            IconButton { visible: page.manual; enabled: row.index + 1 < view.count; icon.name: "go-down"; text: i18n("Down"); onClicked: page.move(row.modelData.url, row.index + 1) }
            IconButton { icon.name: "edit-delete"; text: i18n("Remove"); onClicked: page.remove(row.modelData.url) }
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
    Controls.Label {
        Layout.fillWidth: true
        visible: text.length > 0
        text: dockSettings.error
        color: Kirigami.Theme.negativeTextColor
        wrapMode: Text.WordWrap
    }
}
