// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Controls.ApplicationWindow {
    id: window
    objectName: "settingsWindow"
    title: i18n("Configure Plasma Next Dock")
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
        revealAnimation.checked = v.revealAnimation;
        backgroundType.currentIndex = v.backgroundType;
        backgroundOpacity.value = Math.round(v.backgroundOpacity * 100);
        blurSaturation.value = Math.round(v.blurSaturation * 100);
        blurContrast.value = Math.round(v.blurContrast * 100);
        blurBrightness.value = Math.round(v.blurBrightness * 100);
        indicators.load(v);
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
        onApplied: dockSettings.apply(Object.assign({}, indicators.previewConfiguration, {edge: edge.currentIndex, screen: outputNames[screen.currentIndex] || "",
            iconSize: iconSize.value, zoom: zoom.value / 100, spacing: spacing.value,
            backgroundType: backgroundType.currentIndex, backgroundOpacity: backgroundOpacity.value / 100,
            blurSaturation: blurSaturation.value / 100, blurContrast: blurContrast.value / 100, blurBrightness: blurBrightness.value / 100,
            radius: radius.value, glow: glow.checked, dodge: dodge.checked, revealAnimation: revealAnimation.checked}))
        onRejected: window.close()
    }
    header: Controls.TabBar {
        id: pages
        Controls.TabButton { text: i18n("Appearance and launchers") }
        Controls.TabButton { text: i18n("Indicators") }
    }
    StackLayout {
      anchors.fill: parent
      currentIndex: pages.currentIndex
      Controls.ScrollView {
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: 12
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                Controls.Label { text: i18n("Position and appearance"); font.bold: true; Kirigami.FormData.isSection: true }
                Controls.ComboBox {
                    id: screen
                    objectName: "screenControl"
                    // Avoid style content-item/implicit-width feedback in Breeze.
                    implicitWidth: Kirigami.Units.gridUnit * 16
                    Kirigami.FormData.label: i18n("Screen:")
                    model: outputNames.map(name => name || i18n("Primary screen"))
                }
                Controls.ComboBox {
                    id: edge
                    objectName: "edgeControl"
                    implicitWidth: Kirigami.Units.gridUnit * 16
                    Kirigami.FormData.label: i18n("Edge:")
                    model: [i18n("Bottom"), i18n("Top"), i18n("Left"), i18n("Right")]
                }
                Controls.SpinBox { id: spacing; objectName: "spacingControl"; Kirigami.FormData.label: i18n("Distance from edge (px):"); from: 0; to: 128; editable: true }
                Controls.SpinBox { id: iconSize; objectName: "iconSizeControl"; Kirigami.FormData.label: i18n("Icon size (px):"); from: 24; to: 96; editable: true }
                Controls.SpinBox { id: zoom; objectName: "zoomControl"; Kirigami.FormData.label: i18n("Magnification (%):"); from: 100; to: 250; stepSize: 5; editable: true }
                Controls.Label { text: i18n("Capsule and style"); font.bold: true; Kirigami.FormData.isSection: true }
                Controls.ComboBox {
                    id: backgroundType; objectName: "backgroundTypeControl"
                    implicitWidth: Kirigami.Units.gridUnit * 16
                    Kirigami.FormData.label: i18n("Background:")
                    model: [i18n("Solid"), i18n("Transparent"), i18n("Translucent"), i18n("System Blur"), i18n("Liquid Glass")]
                }
                Controls.SpinBox {
                    id: backgroundOpacity; objectName: "backgroundOpacityControl"
                    visible: backgroundType.currentIndex >= 2
                    Kirigami.FormData.label: i18n("Background tint opacity (%):")
                    from: 0; to: 100; editable: true
                }
                Controls.SpinBox {
                    id: blurSaturation; objectName: "blurSaturationControl"
                    visible: backgroundType.currentIndex >= 3
                    Kirigami.FormData.label: i18n("Blur saturation (%):")
                    from: 0; to: 300; stepSize: 5; editable: true
                }
                Controls.SpinBox {
                    id: blurContrast; objectName: "blurContrastControl"
                    visible: backgroundType.currentIndex >= 3
                    Kirigami.FormData.label: i18n("Blur contrast (%):")
                    from: 0; to: 200; stepSize: 5; editable: true
                }
                Controls.SpinBox {
                    id: blurBrightness; objectName: "blurBrightnessControl"
                    visible: backgroundType.currentIndex >= 3
                    Kirigami.FormData.label: i18n("Blur brightness (%):")
                    from: 0; to: 200; stepSize: 5; editable: true
                }
                Controls.Label {
                    visible: backgroundType.currentIndex >= 3
                    Layout.fillWidth: true
                    text: i18n("Requires an enabled KWin blur effect. Liquid Glass adds tint and gloss, not optical refraction.")
                    wrapMode: Text.WordWrap
                }
                Controls.SpinBox { id: radius; objectName: "radiusControl"; Kirigami.FormData.label: i18n("Corner radius (px):"); from: 0; to: 96; editable: true }
                Controls.CheckBox { id: glow; text: i18n("Enable hover glow") }
                Controls.CheckBox { id: revealAnimation; text: i18n("Animate dock appearance and disappearance") }
                Controls.Label {
                    Layout.fillWidth: true
                    text: i18n("Uses KWin's Sliding Popups effect and system animation speed. No system setting is changed.")
                    wrapMode: Text.WordWrap
                }
                Controls.CheckBox { id: dodge; text: i18n("Hide when a window overlaps the capsule") }
                Controls.Label {
                    Layout.fillWidth: true
                    text: i18n("Apply saves these settings. Changing the screen or edge briefly recreates the dock window.")
                    wrapMode: Text.WordWrap
                }
            }
            Controls.Label { Layout.leftMargin: 16; text: i18n("Pinned applications"); font.bold: true }
            Controls.Label {
                Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
                text: i18n("Pin running applications from the dock's right-click menu. Changes to this list are saved immediately.")
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: dockSettings.values.launchers
                delegate: RowLayout {
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
                    Controls.Label { text: modelData; elide: Text.ElideMiddle; Layout.fillWidth: true }
                    Controls.ToolButton { text: i18n("Up"); enabled: index > 0; onClicked: window.moveLauncher(index, -1) }
                    Controls.ToolButton { text: i18n("Down"); enabled: index + 1 < dockSettings.values.launchers.length; onClicked: window.moveLauncher(index, 1) }
                    Controls.ToolButton {
                        text: i18n("Remove")
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
                    placeholderText: i18n("Desktop entry ID, e.g. org.kde.dolphin.desktop")
                    Accessible.name: i18n("Application desktop entry")
                }
                Controls.Button {
                    text: i18n("Add")
                    onClicked: {
                        const id = launcher.text.trim();
                        if (!/^[A-Za-z0-9_.-]+\.desktop$/.test(id)) {
                            window.launcherError = i18n("Enter an installed application's desktop entry ID ending in .desktop."); return;
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
      IndicatorsSettings { id: indicators }
    }
}
