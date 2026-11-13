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
        ListElement { display: "One"; decoration: "folder" }
        ListElement { display: "Two"; decoration: "folder" }
        ListElement { display: "Three"; decoration: "folder" }
        ListElement { display: "Four"; decoration: "folder" }
        ListElement { display: "Five"; decoration: "folder" }
    }
}
