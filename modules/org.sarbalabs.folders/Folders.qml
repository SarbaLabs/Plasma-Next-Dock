// SPDX-License-Identifier: GPL-2.0-or-later
import QtQml
import "native" as Native

Native.FolderTools {
    id: folders
    required property var configuration
    signal edited(var options)
    readonly property bool manual: configuration.sort !== "name"
    readonly property var shortcuts: configuration.folders || []
    property int revision: 0
    readonly property var rows: {
        revision;
        const values = shortcuts.map(item => {
            const detail = describe(item.url);
            return {url: item.url, name: detail.name, path: detail.path, available: detail.available,
                    icon: item.icon || detail.icon, custom: !!item.icon};
        });
        if (!manual) values.sort((a, b) => a.name.localeCompare(b.name) || a.path.localeCompare(b.path));
        return values;
    }
    function updateWatch() { watch(shortcuts.map(item => item.url)); }
    onShortcutsChanged: updateWatch()
    onMetadataChanged: { updateWatch(); ++revision; }
    onIconChosen: (id, name) => setIcon(id, name)
    onFolderChosen: url => add([url])
    function add(urls, beforeId = "") {
        const list = shortcuts.slice();
        let position = beforeId && manual ? list.findIndex(item => item.url === beforeId) : list.length;
        if (position < 0) return false;
        for (const url of urls) {
            const id = directory(url);
            if (id && !list.some(item => item.url === id)) list.splice(position++, 0, {url: id});
        }
        if (list.length === shortcuts.length) return false;
        edited({folders: list});
        return true;
    }
    function setIcon(id, icon) {
        if (shortcuts.some(item => item.url === id))
            edited({folders: shortcuts.map(item => item.url === id ? {url: id, icon: icon} : item)});
    }
    function remove(id) { edited({folders: shortcuts.filter(item => item.url !== id)}); }
    function move(id, destination) {
        const list = shortcuts.slice();
        const from = list.findIndex(item => item.url === id);
        if (!manual || from < 0 || destination < 0 || destination >= list.length || destination === from) return;
        list.splice(destination, 0, list.splice(from, 1)[0]);
        edited({folders: list});
    }
}
