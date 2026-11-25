// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
Item {
    property alias tasks: entries
    property int activations: 0
    property int middleClicks: 0
    property bool replaceOnLaunch: false
    signal launchRequested(int row)
    function activate(index) {
        activations++;
        launchRequested(index);
        if (replaceOnLaunch) {
            const entry = {display: "Launched", decoration: "folder", LauncherUrl: "applications:One.desktop", IsWindow: true};
            entries.remove(index);
            entries.insert(index, entry);
        }
    }
    function middle(index) { middleClicks++; launchRequested(index); }
    ListModel {
        id: entries
        ListElement { display: "One"; decoration: "folder"; LauncherUrl: "applications:One.desktop"; IsWindow: false; IsLauncher: false }
        ListElement { display: "Two"; decoration: "folder"; LauncherUrl: "applications:Two.desktop"; IsWindow: false }
        ListElement { display: "Three"; decoration: "folder"; LauncherUrl: "applications:Three.desktop"; IsWindow: false }
    }
}
