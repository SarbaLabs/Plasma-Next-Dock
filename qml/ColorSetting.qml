// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami

RowLayout {
    id: root
    required property DockPalette paletteSource
    property color fixedColor: "#808080"
    property color defaultColor: Kirigami.Theme.backgroundColor
    property string role: "automatic"
    Controls.ComboBox {
        model: root.paletteSource.labels
        currentIndex: Math.max(0, root.paletteSource.keys.indexOf(root.role))
        onActivated: index => root.role = root.paletteSource.keys[index]
    }
    Controls.Button {
        visible: root.role === "custom"
        text: root.fixedColor.toString()
        onClicked: { dialog.selectedColor = root.fixedColor; dialog.open(); }
    }
    Rectangle {
        implicitWidth: 20; implicitHeight: 20
        color: root.paletteSource.resolve(root.role, root.fixedColor, root.defaultColor)
        border.width: 1; border.color: Kirigami.Theme.disabledTextColor
    }
    Dialogs.ColorDialog { id: dialog; onAccepted: root.fixedColor = selectedColor }
}
