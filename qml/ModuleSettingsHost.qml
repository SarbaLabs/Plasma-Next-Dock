// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

Loader {
    id: host
    required property var profile
    property string moduleId: ""
    onProfileChanged: active = false
    active: false

    function open(info) {
        if (!info.settingsUrl) return;
        if (item && moduleId === info.id) {
            item.raise();
            item.requestActivate();
            return;
        }
        active = false;
        moduleId = info.id;
        source = info.settingsUrl;
        active = true;
    }
    onLoaded: {
        item.transientParent = null;
        item.configuration = Qt.binding(() => profile.values.moduleSettings[moduleId] || {});
        item.show();
        item.requestActivate();
    }
    Connections {
        target: host.item
        function onVisibleChanged() {
            if (host.item && !host.item.visible) host.active = false;
        }
        function onEdited(options) {
            const settings = Object.assign({}, host.profile.values.moduleSettings);
            settings[host.moduleId] = Object.assign({}, settings[host.moduleId], options);
            host.profile.apply({moduleSettings: settings});
        }
    }
}
