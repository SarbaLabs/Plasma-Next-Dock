// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
Item {
    property alias tasks: entries
    property int moves: 0
    property int saves: 0
    property int activations: 0
    function activate(index) { activations++; }
    function moveTask(from, to) { entries.move(from, to, 1); moves++; return true; }
    function finishMove() { saves++; }
    ListModel {
        id: entries
        ListElement { IsLauncher: true; display: "One"; decoration: "folder" }
        ListElement { IsLauncher: true; display: "Two"; decoration: "folder" }
        ListElement { IsLauncher: true; display: "Three"; decoration: "folder" }
        ListElement { IsLauncher: true; display: "Four"; decoration: "folder" }
        ListElement { IsLauncher: true; display: "Five"; decoration: "folder" }
    }
}
