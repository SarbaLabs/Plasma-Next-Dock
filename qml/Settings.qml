// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Controls.ApplicationWindow {
    id: window
    objectName: "settingsWindow"
    title: qsTr("Configure Plasma Next Dock")
    width: 620; height: 720
    minimumWidth: 460; minimumHeight: 400
    visible: false
    property string launcherError: ""
    function openSettings() {
        const v = dockSettings.values;
        edge.currentIndex = v.edge;
        screen.currentIndex = Math.max(0, outputNames.indexOf(v.screen));
        iconSize.value = v.iconSize; zoom.value = Math.round(v.zoom * 100);
        spacing.value = v.spacing; radius.value = v.radius;
        glow.checked = v.glow; dodge.checked = v.dodge;
        visible = true;
    }
    function moveLauncher(index, delta) {
        const list = dockSettings.values.launchers.slice();
        const target = index + delta;
        if (target < 0 || target >= list.length) return;
        const entry = list.splice(index, 1)[0]; list.splice(target, 0, entry);
        dockSettings.saveLaunchers(list);
    }
    footer: Controls.DialogButtonBox {
        objectName: "settingsButtons"
        standardButtons: Controls.DialogButtonBox.Apply | Controls.DialogButtonBox.Close
        onApplied: dockSettings.apply({edge: edge.currentIndex, screen: outputNames[screen.currentIndex] || "",
            iconSize: iconSize.value, zoom: zoom.value / 100, spacing: spacing.value,
            radius: radius.value, glow: glow.checked, dodge: dodge.checked})
        onRejected: window.close()
    }
    Controls.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: 12
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                Controls.Label { text: qsTr("Position and appearance"); font.bold: true; Kirigami.FormData.isSection: true }
                Controls.ComboBox {
                    id: screen
                    objectName: "screenControl"
                    // Avoid style content-item/implicit-width feedback in Breeze.
                    implicitWidth: Kirigami.Units.gridUnit * 16
                    Kirigami.FormData.label: qsTr("Screen:")
                    model: outputNames.map(name => name || qsTr("Primary screen"))
                }
                Controls.ComboBox {
                    id: edge
                    objectName: "edgeControl"
                    implicitWidth: Kirigami.Units.gridUnit * 16
                    Kirigami.FormData.label: qsTr("Edge:")
                    model: [qsTr("Bottom"), qsTr("Top"), qsTr("Left"), qsTr("Right")]
                }
                Controls.SpinBox { id: spacing; objectName: "spacingControl"; Kirigami.FormData.label: qsTr("Distance from edge (px):"); from: 0; to: 128; editable: true }
                Controls.SpinBox { id: iconSize; objectName: "iconSizeControl"; Kirigami.FormData.label: qsTr("Icon size (px):"); from: 24; to: 96; editable: true }
                Controls.SpinBox { id: zoom; objectName: "zoomControl"; Kirigami.FormData.label: qsTr("Magnification (%):"); from: 100; to: 250; stepSize: 5; editable: true }
                Controls.SpinBox { id: radius; objectName: "radiusControl"; Kirigami.FormData.label: qsTr("Corner radius (px):"); from: 0; to: 96; editable: true }
                Controls.CheckBox { id: glow; text: qsTr("Enable hover glow") }
                Controls.CheckBox { id: dodge; text: qsTr("Hide when a window overlaps the capsule") }
                Controls.Label {
                    Layout.fillWidth: true
                    text: qsTr("Apply saves these settings. Changing the screen or edge briefly recreates the dock window.")
                    wrapMode: Text.WordWrap
                }
            }
            Controls.Label { Layout.leftMargin: 16; text: qsTr("Pinned applications"); font.bold: true }
            Controls.Label {
                Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
                text: qsTr("Pin running applications from the dock's right-click menu. Changes to this list are saved immediately.")
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: dockSettings.values.launchers
                delegate: RowLayout {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
                    Controls.Label { text: modelData; elide: Text.ElideMiddle; Layout.fillWidth: true }
                    Controls.ToolButton { text: qsTr("Up"); enabled: index > 0; onClicked: window.moveLauncher(index, -1) }
                    Controls.ToolButton { text: qsTr("Down"); enabled: index + 1 < dockSettings.values.launchers.length; onClicked: window.moveLauncher(index, 1) }
                    Controls.ToolButton {
                        text: qsTr("Remove")
                        onClicked: {
                            const list = dockSettings.values.launchers.slice(); list.splice(index, 1);
                            dockSettings.saveLaunchers(list);
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
                Controls.TextField {
                    id: launcher
                    Layout.fillWidth: true
                    placeholderText: qsTr("Desktop entry ID, e.g. org.kde.dolphin.desktop")
                    Accessible.name: qsTr("Application desktop entry")
                }
                Controls.Button {
                    text: qsTr("Add")
                    onClicked: {
                        const id = launcher.text.trim();
                        if (!/^[A-Za-z0-9_.-]+\.desktop$/.test(id)) {
                            window.launcherError = qsTr("Enter an installed application's desktop entry ID ending in .desktop."); return;
                        }
                        const list = dockSettings.values.launchers.slice();
                        const url = "applications:" + id;
                        if (list.indexOf(url) < 0) list.push(url);
                        if (dockSettings.saveLaunchers(list)) { launcher.clear(); window.launcherError = ""; }
                    }
                }
            }
            Controls.Label {
                Layout.fillWidth: true; Layout.margins: 16
                visible: text.length > 0
                text: dockSettings.error || window.launcherError
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.WordWrap
            }
        }
    }
}
