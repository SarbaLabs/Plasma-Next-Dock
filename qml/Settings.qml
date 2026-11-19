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
    readonly property var profiles: typeof dockProfiles === "undefined" ? null : dockProfiles
    property string profileError: ""
    property string draftScreen: ""
    readonly property var screenNames: outputNames.indexOf(draftScreen) < 0 ? outputNames.concat([draftScreen]) : outputNames
    Controls.Dialog {
        id: confirmRemoval
        parent: window.contentItem
        anchors.centerIn: parent
        modal: true
        title: i18n("Remove %1?", window.profiles ? window.profiles.labels[window.profiles.selectedIndex] || "" : "")
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        Controls.Label { text: i18n("Its settings and pinned applications will be removed.") }
        onAccepted: if (!window.profiles.removeSelected()) window.profileError = i18n("Could not remove the dock.")
    }
    DockPalette { id: dockPalette }
    ApplicationChooser {
        id: applicationChooser
        parent: window.contentItem
        onChosen: url => {
            const list = launcherResolver.insert(dockSettings.values.launchers, [url], "");
            if (dockSettings.saveLaunchers(list)) window.launcherError = "";
        }
    }
    property string launcherError: ""
    function openSettings() {
        login.checked = login.saved = dockSettings.startsAtLogin();
        loginError.visible = false;
        const v = dockSettings.values;
        edge.currentIndex = v.edge;
        window.draftScreen = v.screen;
        window.profileError = "";
        iconSize.value = v.iconSize; zoom.value = Math.round(v.zoom * 100);
        blastRadius.value = v.blastRadius; hoverLift.value = v.hoverLift;
        spacing.value = v.spacing;
        glow.checked = v.glow; dodge.checked = v.dodge;
        revealAnimation.checked = v.revealAnimation;
        backgroundType.currentIndex = backgroundType.modeIds.indexOf(v.backgroundType);
        systemBlur.checked = v.systemBlur;
        midpoint.value = v.gradientMidpoint;
        glassOpacity.value = Math.round(v.glassOpacity * 100);
        backgroundOpacity.value = Math.round(v.backgroundOpacity * 100);
        borderWidth.value = v.borderWidth;
        borderOpacity.value = Math.round(v.borderOpacity * 100);
        topOpacity.value = Math.round(v.gradientTopOpacity * 100);
        bottomOpacity.value = Math.round(v.gradientBottomOpacity * 100);
        fill.role = v.backgroundRole; fill.fixedColor = v.backgroundColor;
        upper.role = v.gradientTopRole; upper.fixedColor = v.gradientTopColor;
        lower.role = v.gradientBottomRole; lower.fixedColor = v.gradientBottomColor;
        outline.role = v.borderRole; outline.fixedColor = v.borderColor;
        topLeft.value = v.topLeftRadius;
        topRight.value = v.topRightRadius;
        bottomLeft.value = v.bottomLeftRadius;
        bottomRight.value = v.bottomRightRadius;
        iconSpacing.value = v.iconSpacing; horizontalPadding.value = v.horizontalPadding; verticalPadding.value = v.verticalPadding;
        highlightPreview.checked = v.highlightPreviewWindow;
        windowPreviews.checked = v.showWindowPreviews; audioIndicator.checked = v.showAudioIndicator;
        muteOnClick.checked = v.muteOnClick; mediaControls.checked = v.showMediaControls;
        badges.checked = v.showBadges; progress.checked = v.showProgress;
        indicators.load(v);
        behavior.load(v);
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
        onApplied: {
            if (window.profiles && !window.profiles.positionAvailable(window.draftScreen, edge.currentIndex)) {
                window.profileError = i18n("Another dock uses this screen edge. Choose a different edge or screen.");
                return;
            }
            window.profileError = "";
            if (!dockSettings.apply(Object.assign({}, behavior.values, indicators.previewConfiguration, {edge: edge.currentIndex, screen: window.draftScreen,
            iconSize: iconSize.value, zoom: zoom.value / 100, spacing: spacing.value,
            backgroundType: backgroundType.mode, systemBlur: systemBlur.checked, gradientMidpoint: midpoint.value, glassOpacity: glassOpacity.value / 100, backgroundOpacity: backgroundOpacity.value / 100,
            borderWidth: borderWidth.value, borderRole: outline.role, borderColor: outline.fixedColor.toString(), borderOpacity: borderOpacity.value / 100,
            backgroundRole: fill.role, backgroundColor: fill.fixedColor.toString(),
            gradientTopRole: upper.role, gradientTopColor: upper.fixedColor.toString(), gradientTopOpacity: topOpacity.value / 100,
            gradientBottomRole: lower.role, gradientBottomColor: lower.fixedColor.toString(), gradientBottomOpacity: bottomOpacity.value / 100,
            iconSpacing: iconSpacing.value, horizontalPadding: horizontalPadding.value, verticalPadding: verticalPadding.value,
            highlightPreviewWindow: highlightPreview.checked, showWindowPreviews: windowPreviews.checked, showAudioIndicator: audioIndicator.checked, muteOnClick: muteOnClick.checked,
            showMediaControls: mediaControls.checked, showBadges: badges.checked, showProgress: progress.checked,
            blastRadius: blastRadius.value, hoverLift: hoverLift.value,
            topLeftRadius: topLeft.value, topRightRadius: topRight.value, bottomLeftRadius: bottomLeft.value, bottomRightRadius: bottomRight.value, glow: glow.checked, dodge: dodge.checked, revealAnimation: revealAnimation.checked}))) return;
            if (login.checked !== login.saved) {
                loginError.visible = !dockSettings.setStartAtLogin(login.checked);
                login.checked = login.saved = dockSettings.startsAtLogin();
            }
        }
        onRejected: window.close()
    }
    header: ColumnLayout {
        spacing: 0
        RowLayout {
            visible: !!window.profiles
            Layout.fillWidth: true
            Layout.margins: 6
            Controls.Label { text: i18n("Dock:") }
            Controls.ComboBox {
                objectName: "dockSelector"
                Layout.fillWidth: true
                model: window.profiles ? window.profiles.labels : []
                currentIndex: window.profiles ? window.profiles.selectedIndex : -1
                onActivated: index => window.profiles.select(index)
            }
            Controls.Button {
                text: i18n("Add dock")
                onClicked: if (!window.profiles.add()) window.profileError = i18n("Could not add a dock. Check for a free screen edge and a writable configuration file.")
            }
            Controls.Button {
                text: i18n("Remove dock")
                enabled: !!window.profiles && window.profiles.labels.length > 1
                onClicked: confirmRemoval.open()
            }
        }
        Controls.Label {
            visible: text.length > 0
            text: window.profileError
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
        }
        Controls.TabBar {
            id: pages
            Layout.fillWidth: true
            Controls.TabButton { text: i18n("Appearance and launchers") }
            Controls.TabButton { text: i18n("Indicators") }
            Controls.TabButton { text: i18n("Application status") }
            Controls.TabButton { text: i18n("Behavior") }
        }
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
                Controls.CheckBox {
                    id: login
                    objectName: "startAtLoginControl"
                    property bool saved: false
                    Kirigami.FormData.label: i18n("All docks:")
                    enabled: dockSettings.loginAvailable
                    text: i18n("Start Plasma Next Dock at login")
                }
                Controls.Label {
                    id: loginError
                    visible: false
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Kirigami.Theme.negativeTextColor
                    text: i18n("Could not update the login entry. Check the dock installation and your autostart directory.")
                }
                Controls.Label { text: i18n("Position and appearance"); font.bold: true; Kirigami.FormData.isSection: true }
                Controls.ComboBox {
                    id: screen
                    objectName: "screenControl"
                    // Avoid style content-item/implicit-width feedback in Breeze.
                    implicitWidth: Kirigami.Units.gridUnit * 16
                    Kirigami.FormData.label: i18n("Screen:")
                    function fullLabel(name) {
                        if (!name) return i18n("Primary screen");
                        if (outputNames.indexOf(name) < 0) return i18n("%1 (disconnected)", name);
                        const description = outputDescriptions[name];
                        return description ? i18n("%1: %2", name, description) : name;
                    }
                    FontMetrics { id: screenMetrics; font: screen.font }
                    // Leave room for the native style's dropdown arrow and margins.
                    readonly property real labelWidth: Math.max(0, width - 2 * Kirigami.Units.gridUnit)
                    model: window.screenNames.map(name => screenMetrics.elidedText(
                        fullLabel(name), Qt.ElideRight, labelWidth))
                    Controls.ToolTip.text: fullLabel(window.draftScreen)
                    Controls.ToolTip.visible: hovered && displayText !== Controls.ToolTip.text && !popup.visible
                    currentIndex: window.screenNames.indexOf(window.draftScreen)
                    onActivated: index => window.draftScreen = window.screenNames[index]
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
                Controls.SpinBox { id: blastRadius; objectName: "blastRadiusControl"; Kirigami.FormData.label: i18n("Blast radius (neighbor icons):"); from: 0; to: 8; editable: true }
                Controls.SpinBox { id: hoverLift; objectName: "hoverLiftControl"; Kirigami.FormData.label: i18n("Hover lift (px):"); from: 0; to: 64; editable: true }
                Controls.Label { text: i18n("Capsule and style"); font.bold: true; Kirigami.FormData.isSection: true }
                Controls.ComboBox {
                    id: backgroundType; objectName: "backgroundTypeControl"
                    implicitWidth: Kirigami.Units.gridUnit * 16
                    Kirigami.FormData.label: i18n("Background:")
                    readonly property var modeIds: [0, 4, 5]
                    readonly property int mode: modeIds[currentIndex] ?? 0
                    model: [i18n("Solid"), i18n("Liquid Glass"), i18n("Gradient")]
                }
                Controls.SpinBox {
                    id: backgroundOpacity; objectName: "backgroundOpacityControl"
                    visible: backgroundType.mode === 0
                    Kirigami.FormData.label: i18n("Background tint opacity (%):")
                    from: 0; to: 100; editable: true
                }
                Controls.SpinBox {
                    id: glassOpacity; objectName: "glassOpacityControl"
                    visible: backgroundType.mode === 4
                    Kirigami.FormData.label: i18n("Background tint opacity (%):")
                    from: 0; to: 100; editable: true
                }
                Controls.CheckBox { id: systemBlur; objectName: "systemBlurControl"; text: i18n("Use system blur") }
                ColorSetting {
                    id: fill; objectName: "fillColorControl"; paletteSource: dockPalette
                    Kirigami.FormData.label: i18n("Background color:")
                    visible: backgroundType.mode !== 5
                    defaultColor: backgroundType.mode !== 4 ? Kirigami.Theme.backgroundColor : Kirigami.Theme.backgroundColor.hslLightness < 0.5 ? "#1f1f26" : "#f5f7ff"
                }
                ColorSetting {
                    id: upper; objectName: "upperColorControl"; paletteSource: dockPalette
                    Kirigami.FormData.label: i18n("Desktop-side color:")
                    visible: backgroundType.mode === 5
                    defaultColor: Kirigami.Theme.backgroundColor
                }
                Controls.SpinBox {
                    id: topOpacity; objectName: "topOpacityControl"; Kirigami.FormData.label: i18n("Desktop-side opacity (%):")
                    from: 0; to: 100; editable: true
                    visible: backgroundType.mode === 5
                }
                ColorSetting {
                    id: lower; objectName: "lowerColorControl"; paletteSource: dockPalette
                    Kirigami.FormData.label: i18n("Screen-edge color:")
                    visible: backgroundType.mode === 5
                    defaultColor: Kirigami.Theme.highlightColor
                }
                Controls.SpinBox {
                    id: bottomOpacity; objectName: "bottomOpacityControl"; Kirigami.FormData.label: i18n("Screen-edge opacity (%):")
                    from: 0; to: 100; editable: true
                    visible: backgroundType.mode === 5
                }
                Controls.SpinBox {
                    id: midpoint; objectName: "gradientMidpointControl"
                    visible: backgroundType.mode === 5
                    Kirigami.FormData.label: i18n("Gradient midpoint (% toward screen edge):")
                    from: 1; to: 99; editable: true
                }
                Controls.Label {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: i18n("Negative corner radii curve outward along the dock.")
                }
                Controls.SpinBox {
                    id: topLeft; objectName: "topLeftControl"; Kirigami.FormData.label: i18n("Top left radius (px):")
                    from: -96; to: 96; editable: true
                }
                Controls.SpinBox {
                    id: topRight; objectName: "topRightControl"; Kirigami.FormData.label: i18n("Top right radius (px):")
                    from: -96; to: 96; editable: true
                }
                Controls.SpinBox {
                    id: bottomLeft; objectName: "bottomLeftControl"; Kirigami.FormData.label: i18n("Bottom left radius (px):")
                    from: -96; to: 96; editable: true
                }
                Controls.SpinBox {
                    id: bottomRight; objectName: "bottomRightControl"; Kirigami.FormData.label: i18n("Bottom right radius (px):")
                    from: -96; to: 96; editable: true
                }
                Controls.SpinBox {
                    id: borderWidth; objectName: "borderWidthControl"; Kirigami.FormData.label: i18n("Border thickness (px):")
                    from: 0; to: 12; editable: true
                }
                ColorSetting {
                    id: outline; objectName: "outlineColorControl"; paletteSource: dockPalette
                    Kirigami.FormData.label: i18n("Border color:")
                    enabled: borderWidth.value > 0
                    defaultColor: Kirigami.Theme.disabledTextColor
                }
                Controls.SpinBox {
                    id: borderOpacity; objectName: "borderOpacityControl"; Kirigami.FormData.label: i18n("Border opacity (%):")
                    from: 0; to: 100; editable: true
                    enabled: borderWidth.value > 0
                }
                Controls.SpinBox { id: iconSpacing; objectName: "iconSpacingControl"; Kirigami.FormData.label: i18n("Space between icons (px):"); from: 0; to: 64; editable: true }
                Controls.SpinBox { id: horizontalPadding; objectName: "horizontalPaddingControl"; Kirigami.FormData.label: i18n("Padding at both ends (px):"); from: 0; to: 128; editable: true }
                Controls.SpinBox { id: verticalPadding; objectName: "verticalPaddingControl"; Kirigami.FormData.label: i18n("Padding across thickness (px):"); from: 0; to: 64; editable: true }
                Controls.Label {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: i18n("End padding follows the dock's length; thickness padding follows its short axis, on every screen edge. Spacing and padding scale down with icons when space is limited.")
                }
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
            Controls.Button {
                Layout.leftMargin: 16
                text: i18n("Add an application…")
                onClicked: applicationChooser.open()
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
      Controls.ScrollView {
        contentWidth: availableWidth
        Kirigami.FormLayout {
            width: parent.width
            Controls.CheckBox { id: windowPreviews; objectName: "windowPreviewsControl"; text: i18n("Show window previews on hover") }
            Controls.CheckBox {
                id: highlightPreview
                objectName: "highlightPreviewControl"
                text: i18n("Highlight the window on the desktop when hovering over its preview")
            }
            Controls.CheckBox { id: audioIndicator; objectName: "audioIndicatorControl"; text: i18n("Show application audio indicator") }
            Controls.CheckBox { id: muteOnClick; objectName: "muteOnClickControl"; text: i18n("Click audio indicator to mute"); enabled: audioIndicator.checked }
            Controls.CheckBox { id: mediaControls; objectName: "mediaControlsControl"; text: i18n("Show media and volume controls in previews") }
            Controls.CheckBox { id: badges; objectName: "badgesControl"; text: i18n("Show application counters") }
            Controls.CheckBox { id: progress; objectName: "progressControl"; text: i18n("Show application progress") }
            Controls.Label {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: i18n("Counters and progress depend on application support and KDE notification settings.")
            }
        }
      }
      BehaviorSettings { id: behavior }
    }
}
