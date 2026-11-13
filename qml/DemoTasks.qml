// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
Item {
    property alias tasks: tasks
    function activate(index) {} // Deliberately inert: --demo never starts applications.
    ListModel {
        id: tasks
        ListElement { decoration: "system-file-manager"; display: "Files"; IsWindow: false; IsActive: false }
        ListElement { decoration: "internet-web-browser"; display: "Browser"; IsWindow: false; IsActive: false }
        ListElement { decoration: "utilities-terminal"; display: "Terminal"; IsWindow: false; IsActive: false }
        ListElement { decoration: "accessories-text-editor"; display: "Editor"; IsWindow: false; IsActive: false }
        ListElement { decoration: "systemsettings"; display: "Settings"; IsWindow: false; IsActive: false }
    }
}
